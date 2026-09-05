# frozen_string_literal: true

# Prueft einen TournamentPlan gegen SEINE EIGENE Definition und meldet Defekte, bevor ein
# Turnier daran scheitert. Kein Regelwerk-Abgleich — ob eine Gruppenbildung der NBV-Ordnung
# folgt, steht hier nicht zur Debatte; geprueft wird nur die innere Stimmigkeit der Daten.
#
# Anlass (2026-09-04): Vier Turnierplaene fielen an einem Tag aus, jeder mit einem STILLEN
# Abbruch — der Operator sah nur, dass "nichts passiert":
#
#   T16      (id 9)   `rules` als String statt Hash        -> Halbfinals ohne Spieler
#   T17      (id 21)  g2 (4 Spieler) referenziert Spieler 5 -> 1 statt 6 Gruppenspiele
#   T10      (id 28)  g1 (3 Spieler) referenziert Spieler 4 -> Paarung 1-3 fehlt
#   T16neu   (id 340) RK vergibt einen Platz doppelt        -> ein Spieler ohne Rang
#   T06I15.. (id 41)  executor_params kein gueltiges JSON   -> Plan wirft beim Laden
#
# Turnierplaene sind GLOBALE Records (id < MIN_ID). Diese Klasse meldet nur, sie repariert
# nichts — Korrekturen gehoeren auf die Authority.
#
# Verwendung:
#   TournamentPlanValidator.new(plan).findings  # => [Finding, ...]
class TournamentPlanValidator
  # severity: :error (Turnier scheitert daran) — bewusst nur eine Stufe, solange es keine
  # Befunde gibt, die blosse Empfehlungen sind.
  Finding = Struct.new(:severity, :check, :location, :message, keyword_init: true) do
    def to_s
      "[#{check}] #{location}: #{message}"
    end
  end

  # Schluessel in executor_params, die keine Spiel-Buckets sind.
  NON_BUCKET_KEYS = %w[GK RK rules].freeze

  def initialize(plan)
    @plan = plan
  end

  def findings
    @findings ||= begin
      return [] if @plan.executor_params.blank?

      params = parse_params
      # Ohne gueltiges JSON gibt es nichts weiter zu pruefen — nur diesen einen Befund
      # melden, statt jede Folgepruefung an nil scheitern zu lassen.
      return [json_finding] if params.nil?

      @params = params
      [
        check_rules_form,
        check_player_numbers,
        check_round_robin_complete,
        check_rk,
        check_table_conflicts
      ].flatten.compact
    end
  end

  private

  def parse_params
    JSON.parse(@plan.executor_params)
  rescue JSON::ParserError => e
    @json_error = e.message
    nil
  end

  def json_finding
    error(:json, "executor_params", "kein gueltiges JSON: #{@json_error}")
  end

  def error(check, location, message)
    Finding.new(severity: :error, check: check, location: location, message: message)
  end

  # --- Pruefung 1: rules-Form -------------------------------------------------------
  #
  # `rules` liegt in zwei Formen vor, beide gueltig:
  #   Hash   {"rule1" => "(g1.rk2+g2.rk2+g3.rk2).rk1"}   z.B. "T16|15B12-150"
  #   String "(g1.rk2+g2.rk2+g3.rk2).rk1"                z.B. TournamentPlan 9
  # RankingResolver#named_rule versteht seit 4242f1bf beide. Gemeldet wird alles andere —
  # ein Array oder eine Zahl loest sich nirgends auf.
  def check_rules_form
    rules = @params["rules"]
    return nil if rules.nil? || rules.is_a?(Hash) || rules.is_a?(String)

    error(:rules_form, "rules",
      "unerwarteter Typ #{rules.class} — erwartet wird ein Hash mit benannten Regeln " \
      "oder ein String (= genau eine Regel, ansprechbar als 'rule1')")
  end

  # --- Pruefung 2: Spielernummern ---------------------------------------------------
  #
  # Jede Zahl einer sq-Paarung muss <= pl sein. T17 und T10 scheiterten genau hier.
  def check_player_numbers
    group_buckets.filter_map do |key, bucket|
      pl = bucket["pl"].to_i
      next if pl <= 0

      sq_pairings(bucket).filter_map do |round_key, table_key, pairing|
        over = pairing_numbers(pairing).select { |n| n > pl }
        next if over.empty?

        error(:player_numbers, "#{key}.#{round_key}.#{table_key}",
          "Paarung #{pairing.inspect} nennt Spieler #{over.join(", ")}, " \
          "die Gruppe hat aber nur #{pl}")
      end
    end.flatten
  end

  # --- Pruefung 3: Vollstaendigkeit der Jeder-gegen-jeden-Runde ----------------------
  #
  # NUR bei rs == "eae" (starr). Bei "eae_pg" fuellt der Populator fehlende Paarungen
  # bewusst auf (table_populator.rb:700) — dort waere eine Meldung falsch. "T16|15B60"
  # definiert fuer g2 absichtlich nur r1 und ist trotzdem korrekt.
  def check_round_robin_complete
    group_buckets.filter_map do |key, bucket|
      next unless bucket["rs"].to_s == "eae"

      pl = bucket["pl"].to_i
      next if pl <= 1

      # Ein "/N"-Suffix ist die Durchgangsnummer (nrepeats). "1-2/1" und "1-2/2" sind
      # ZWEI Durchgaenge derselben Paarung, keine Dublette — T01 (nrepeats=3) und
      # T29 (nrepeats=2) sind so aufgebaut und voellig korrekt.
      # Vollstaendigkeit prueft deshalb die MENGE der Paarungen; doppelt ist nur, was
      # mit derselben Durchgangsnummer zweimal angesetzt ist.
      slots = sq_pairings(bucket).filter_map do |_r, _t, pairing|
        pair = normalized_pair(pairing)
        [pair, repeat_index(pairing)] if pair
      end

      out = []
      missing = (1..pl).to_a.combination(2).to_a - slots.map(&:first).uniq
      if missing.any?
        out << error(:round_robin, "#{key} (rs=eae, pl=#{pl})",
          "fehlende Paarung(en): #{missing.map { |a, b| "#{a}-#{b}" }.join(", ")}")
      end
      duplicates = slots.tally.select { |_slot, count| count > 1 }.keys
      if duplicates.any?
        out << error(:round_robin, "#{key} (rs=eae, pl=#{pl})",
          "mehrfach angesetzt: " +
            duplicates.map { |(a, b), rp| "#{a}-#{b}#{"/#{rp}" if rp}" }.join(", "))
      end
      out.presence
    end.flatten
  end

  # --- Pruefung 4: RK-Array ---------------------------------------------------------
  #
  # Der T16neu-Fehler (2026-09-04) steckte hier: `RK` vergab Platz 8 an "p<8-9>.rk1",
  # obwohl der Sieger von p<8-9> in p<7-8> AUFSTEIGT und dort Platz 7 holt. Er belegte
  # zwei Plaetze, der Verlierer von p<7-8> fiel aus der Rangliste.
  #
  # Statisch fassbar: Wird ein Rang als TEILNEHMER eines spaeteren Spiels referenziert,
  # darf derselbe Rang nicht zusaetzlich im RK stehen — der Spieler ist weitergezogen.
  def check_rk
    rk = @params["RK"]
    return nil if rk.nil?
    return error(:rk, "RK", "erwartet wird ein Array, gefunden #{rk.class}") unless rk.is_a?(Array)

    out = []

    # Ein RK-Element darf ein Array sein — dann teilen sich mehrere Spieler einen Platz
    # (so bei allen KO_*-Plaenen), oder es ist leer (kein Platz vergeben). Fuer alle
    # Pruefungen zaehlt die flache Liste der tatsaechlichen Referenzen.
    refs = rk.flatten.compact.map(&:to_s).reject(&:blank?)

    # NUR mehr Plaetze als Spieler ist ein Fehler. WENIGER ist bei KO-Plaenen die Regel:
    # DKO_8_4 vergibt mit ["fin.rk1", "fin.rk2"] bewusst nur die Finalplaetze, alle
    # uebrigen Raenge ergeben sich aus der Runde des Ausscheidens. Eine Gleichheits-
    # pruefung meldete hier 21 voellig korrekte Plaene (2026-09-04 am Bestand geprueft).
    if @plan.players.to_i.positive? && refs.size > @plan.players.to_i
      out << error(:rk, "RK",
        "vergibt #{refs.size} Plaetze, der Plan hat aber nur #{@plan.players} Spieler")
    end

    duplicates = refs.tally.select { |_ref, count| count > 1 }.keys
    if duplicates.any?
      out << error(:rk, "RK", "Referenz(en) doppelt vergeben: #{duplicates.join(", ")}")
    end

    known = bucket_names
    refs.each do |ref|
      unknown = referenced_buckets(ref).reject { |b| known.include?(b) }
      next if unknown.empty?

      out << error(:rk, "RK", "#{ref.inspect} zeigt auf #{unknown.map(&:inspect).join(", ")}, " \
        "was es im Plan nicht gibt")
    end

    advanced = advancing_references
    (refs & advanced.keys).each do |ref|
      out << error(:rk, "RK",
        "#{ref.inspect} steht im RK, wird aber zugleich als Teilnehmer in " \
        "#{advanced[ref].join(", ")} gefuehrt — dieser Spieler zieht weiter und kann " \
        "seinen alten Rang nicht auch als Endplatzierung behalten")
    end

    out.presence
  end

  # --- Pruefung 5: Tisch-Mehrfachverwendung -----------------------------------------
  #
  # Uebernommen aus lib/tasks/analyze_tournament_plans.rake (validate_executor_params_for_plan).
  # Verhalten unveraendert — sie wurde nur hierher verschoben, damit es einen Ort gibt
  # statt zwei, und damit sie testbar ist.
  def check_table_conflicts
    usage = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }

    group_buckets.each do |key, bucket|
      sequence = bucket["sq"]
      next unless sequence.is_a?(Hash)

      sequence.each do |round_key, round_data|
        next unless round_key.to_s.match?(/\Ar\d+/) && round_data.is_a?(Hash)

        round_data.each_key do |table_key|
          next unless table_key.to_s.match?(/\At\d+/)

          usage[round_key][table_key] << key
        end
      end
    end

    usage.flat_map do |round_key, tables|
      tables.filter_map do |table_key, groups|
        next if groups.size <= 1

        error(:table_conflicts, "#{round_key}.#{table_key}",
          "Tisch wird mehrfach belegt (Gruppen: #{groups.join(", ")})")
      end
    end
  end

  # --- Helfer -----------------------------------------------------------------------

  def bucket_names
    @bucket_names ||= @params.keys.reject { |k| NON_BUCKET_KEYS.include?(k) }
  end

  def group_buckets
    @group_buckets ||= @params.select { |k, v| k.match?(/\Ag\d+\z/) && v.is_a?(Hash) }
  end

  # Liefert [round_key, table_key, pairing] fuer jede Paarung einer Gruppe.
  def sq_pairings(bucket)
    sequence = bucket["sq"]
    return [] unless sequence.is_a?(Hash)

    sequence.flat_map do |round_key, round_data|
      next [] unless round_data.is_a?(Hash)

      round_data.filter_map do |table_key, pairing|
        [round_key, table_key, pairing] if pairing.is_a?(String)
      end
    end
  end

  # Die Zahlen einer Paarung — OHNE das Wiederholungs-Suffix.
  # "1-2/3" sind die Spieler 1 und 2, dreimal gespielt; die 3 ist ein Zaehler.
  # Der Ad-hoc-Sweep vom 2026-09-04 hat TournamentPlan 2 (T01) genau deshalb falsch
  # gemeldet — ein Pruefer, dem man nicht glaubt, wird ignoriert.
  def pairing_numbers(pairing)
    pairing.to_s.split("/").first.to_s.scan(/\d+/).map(&:to_i)
  end

  # Die Durchgangsnummer hinter dem "/" — nil, wenn die Paarung keine traegt.
  def repeat_index(pairing)
    pairing.to_s.split("/")[1]
  end

  # Die Buckets, auf die eine RK-Referenz zeigt. Deckt beide Formen ab:
  #   "fin.rk1"                    -> ["fin"]
  #   "8f1.rk2"                    -> ["8f1"]   (KO-Buckets beginnen mit einer Ziffer)
  #   "(g2.rk4 + g3.rk4).rk2"      -> ["g2", "g3"]   (zusammengesetzter Ausdruck,
  #                                    aufgeloest von RankingResolver#rank_from_group_ranks)
  def referenced_buckets(ref)
    ref.scan(/([\w<>-]+)\.rk\d+/).flatten.uniq
  end

  def normalized_pair(pairing)
    nums = pairing_numbers(pairing)
    return nil unless nums.size == 2

    nums.sort
  end

  # Alle Referenzen, die in einem Spiel-Bucket als TEILNEHMER stehen — also Spieler,
  # die von dort aus weiterziehen. Ergebnis: {"p<8-9>.rk1" => ["p<7-8>"], ...}
  def advancing_references
    @advancing_references ||= begin
      map = Hash.new { |h, k| h[k] = [] }
      @params.each do |key, bucket|
        next if NON_BUCKET_KEYS.include?(key) || !bucket.is_a?(Hash)

        bucket.each do |round_key, round_data|
          next unless round_key.to_s.match?(/\Ar\d+/) && round_data.is_a?(Hash)

          round_data.each_value do |participants|
            next unless participants.is_a?(Array)

            participants.each { |ref| map[ref] << key if ref.is_a?(String) }
          end
        end
      end
      map
    end
  end
end
