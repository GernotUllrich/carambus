# frozen_string_literal: true

module RegionServer
  # Plan 36-01: Welche Spalten die GESAMTRANGLISTE eines CC-los gespielten Turniers traegt —
  # je Disziplin, als Code-Konstante (Muster RegionServer::AcceptancePlan, keine Migration).
  #
  # WOFUER: Auf dem Region Server erfasst der Landessportwart die Abschlusswerte von Hand — so, wie
  # er es auch in der ClubCloud taete (Betreiber-Klarstellung 2026-07-29: bei Direkteingabe der
  # Ergebniszeilen wird die Ranking-Table dort ebenfalls manuell eingetragen, weil Serienturniere je
  # Position eigene Punkte vergeben). Diese Klasse sagt, WELCHE Felder dabei erscheinen und in
  # welcher Form sie gespeichert werden. Sie entscheidet NICHTS ueber Platzierungen: Rang und Punkte
  # sind reine Handeingabe.
  #
  # DIE SAETZE SIND GEMESSEN, NICHT ERFUNDEN (2026-07-29, read-only ueber 131.557 Seedings mit
  # Gesamtrangliste). Je Disziplin ist der dominante ClubCloud-Satz uebernommen — das ist der Satz,
  # den `tournaments/show.html.erb` rendert und den `carambus:update_ranking_tables` liest.
  # Damit war der ausdrueckliche Vorbehalt aus Tournament::FinalRankingWriter ("fuer Pool/Snooker
  # einen Zielsatz zu erfinden, den niemand liest, waere Rateleistung") zu entkraeften: hier wird
  # nichts erfunden, sondern der real vorherrschende Satz gespiegelt.
  #
  # ⚠️ WAS DIE MESSUNG SONST ZEIGT — hier festgehalten, damit es niemand neu herleiten muss:
  # Die Schluesselsaetze sind QUELLEN-, nicht rein disziplinabhaengig. Zwei Familien laufen quer
  # durch alle Disziplinen — die CC-Familie ("#", "Rank", "Verein", "Aufn") und eine zweite
  # ("Club", "Rang", "RP", "Aufn." MIT PUNKT, weshalb carambus.rake:737 eigens
  # `gl["Aufn"] = gl.delete("Aufn.")` macht). Haertester Beleg: 14.363 Pool-Seedings tragen einen
  # KARAMBOL-Satz (Baelle/Aufn/GD/HGD/HS). Die Disziplin allein sagt den Satz also NICHT voraus.
  #
  # Diese Tabelle gilt deshalb ausschliesslich fuer NEU ERFASSTE CC-lose Turniere, wo es keinen
  # Altbestand gibt und wir den Satz festlegen. Sie ist KEINE Aussage ueber Bestandsdaten und darf
  # nicht zu deren Deutung benutzt werden.
  #
  # TYPEN SIND NICHT KOSMETIK:
  #   - GD/BED/HGD als FLOAT. carambus.rake:765 macht `v.is_a?(Float) ? v : v.to_i` — ein Integer
  #     oder ein String ohne Komma schneidet 1.132 auf 1 ab. Dieselbe Festlegung trifft
  #     FinalRankingWriter#gesamtrangliste_for bereits.
  #   - Zaehlwerte als INTEGER (sum_keys/max_keys, carambus.rake:729-730).
  #   - Quoten als STRING in CC-Form ("50,00 %"). carambus.rake:757 hat dafuer einen eigenen
  #     `when /%/`-Zweig, und die Turnierseite rendert den Wert roh.
  #
  # SCHLUESSELNAME "Rang", nicht "Rank" oder "#": der CC-Satz fuehrt beide ("#" als String, "Rank"
  # als Integer), die zweite Bestandsfamilie fuehrt "Rang" — und "Rang" ist die einzige Schreibung,
  # die Carambus selbst erzeugt (FinalRankingWriter#gesamtrangliste_for). Fuer die Aggregation ist
  # der Schluessel ohne Belang (weder sum_keys noch max_keys), fuer die Konsistenz zur eigenen
  # Schreib-API nicht.
  class RankingSchema
    # key      Schluessel in data["result"]["Gesamtrangliste"]
    # type     :integer | :float | :percent
    # input    true = Formularfeld, false = aus anderen Feldern berechnet
    # prefill  Quelle fuer den Vorschlag aus den erfassten Spielen (nil = kein Vorschlag)
    # numerator/denominators  nur fuer berechnete Felder
    Field = Struct.new(:key, :type, :input, :prefill, :numerator, :denominators, keyword_init: true)

    RANK = Field.new(key: "Rang", type: :integer, input: true)

    # Rang und Punkte tragen die Turnier- bzw. Serienlogik und werden deshalb NIE vorbelegt
    # (Betreiber 2026-07-29). Alles andere ist aus den erfassten Spielen ableitbar.
    SETS = {
      "Karambol" => [
        RANK,
        Field.new(key: "Bälle", type: :integer, input: true, prefill: :balls),
        Field.new(key: "Aufn", type: :integer, input: true, prefill: :innings),
        Field.new(key: "GD", type: :float, input: false, numerator: "Bälle", denominators: ["Aufn"]),
        Field.new(key: "HS", type: :integer, input: true, prefill: :high_run),
        Field.new(key: "BED", type: :float, input: true),
        Field.new(key: "Punkte", type: :integer, input: true)
      ].freeze,
      "Pool" => [
        RANK,
        Field.new(key: "G", type: :integer, input: true, prefill: :wins),
        Field.new(key: "V", type: :integer, input: true, prefill: :losses),
        Field.new(key: "Quote", type: :percent, input: false, numerator: "G", denominators: %w[G V]),
        Field.new(key: "Sp.G", type: :integer, input: true),
        Field.new(key: "Sp.V", type: :integer, input: true),
        Field.new(key: "Sp.Quote", type: :percent, input: false, numerator: "Sp.G", denominators: %w[Sp.G Sp.V])
      ].freeze,
      "Snooker" => [
        RANK,
        Field.new(key: "G", type: :integer, input: true, prefill: :wins),
        Field.new(key: "V", type: :integer, input: true, prefill: :losses),
        Field.new(key: "Quote", type: :percent, input: false, numerator: "G", denominators: %w[G V]),
        Field.new(key: "Frames", type: :integer, input: true),
        Field.new(key: "HB", type: :integer, input: true),
        Field.new(key: "Punkte", type: :integer, input: true)
      ].freeze,
      "Kegel" => [
        RANK,
        Field.new(key: "Kegel", type: :integer, input: true),
        # Bei Kegel fuehrt der CC-Satz einen GD ohne Baelle/Aufnahmen — er ist hier also nicht
        # berechenbar und damit Eingabefeld.
        Field.new(key: "GD", type: :float, input: true),
        Field.new(key: "Partiepunkte", type: :integer, input: true),
        Field.new(key: "Satzpunkte", type: :integer, input: true)
      ].freeze
    }.freeze

    # Ohne erkennbaren Disziplin-Root der Karambol-Satz. Die Alternative — gar keine Seite — waere
    # fuer den Sportwart eine Sackgasse ohne Hinweis; `fallback?` macht es der Oberflaeche moeglich,
    # den Umstand zu benennen.
    FALLBACK_ROOT = "Karambol"

    attr_reader :root

    def self.for(tournament)
      new(tournament&.discipline&.root&.name)
    end

    def initialize(root)
      @requested = root
      @root = SETS.key?(root) ? root : FALLBACK_ROOT
    end

    def fallback?
      @requested != @root
    end

    def fields
      SETS.fetch(@root)
    end

    # Die Felder, die im Formular erscheinen — in Satzreihenfolge.
    def input_fields
      fields.select(&:input)
    end

    def prefillable_fields
      fields.select(&:prefill)
    end

    def computed_fields
      fields.reject(&:input)
    end

    # Ein einzelner Wert in seiner Zielform. Leer bleibt leer: eine "0" statt eines fehlenden Werts
    # waere eine Behauptung ueber das Turnier, die niemand aufgestellt hat.
    def cast(key, value)
      field = fields.find { |f| f.key == key }
      return nil if field.nil? || value.nil? || value.to_s.strip.blank?

      case field.type
      when :integer then value.to_i
      # tr(",", ".") weil ein Sportwart "1,132" tippt — `to_f` laese daraus sonst 1.0.
      when :float then value.to_s.tr(",", ".").to_f
      else value.to_s
      end
    end

    # Ergaenzt die berechneten Felder. `entry` traegt bereits die gecasteten Eingabewerte.
    # Fehlt ein Operand oder ist der Nenner null, entsteht KEIN Schluessel — ein "0,00 %" bei
    # null Spielen waere eine erfundene Quote.
    def apply_computed(entry)
      computed_fields.each_with_object(entry.dup) do |field, acc|
        numerator = acc[field.numerator]
        denominator = field.denominators.sum { |k| acc[k].to_i }
        next if numerator.blank? || denominator.zero?

        acc[field.key] = case field.type
        when :percent then format_percent(100.0 * numerator.to_f / denominator)
        else (numerator.to_f / denominator).round(3)
        end
      end
    end

    private

    # CC-Form: Komma als Dezimaltrenner, Leerzeichen vor dem Prozentzeichen.
    def format_percent(value)
      "#{format("%.2f", value).tr(".", ",")} %"
    end
  end
end
