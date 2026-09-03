# frozen_string_literal: true

# Skip-Hygiene: verhindert, dass Tests unbemerkt verstummen.
#
# Hintergrund (2026-08-09): 31 der 57 Skips waren Tests, die ihre Testdaten per
# Query aus der DB holten (`Player.joins(:player_rankings)...first`) und ohne
# passende Fixture stillschweigend absprangen — teils jahrelang. Die Suite sah
# gruen aus, waehrend ganze Tool-Happy-Paths ungeprueft blieben. Als sie wieder
# liefen, kamen sofort echte Defekte hoch.
#
# Dieser Ledger protokolliert JEDEN skip (auch rohe `skip "..."`-Aufrufe, nicht
# nur die ueber Helper) und prueft am Ende des Laufs:
#
#   * DATENBEDINGTE Skips ("keine Fixture X") sind gedeckelt. Kommt einer dazu,
#     schlaegt der Lauf fehl — mit dem Hinweis, welcher Test betroffen ist.
#   * STRUKTURELLE Skips (Scenario-Gates, fehlende VCR-Kassette, nicht per HTTP
#     testbar, dokumentierte offene Befunde) sind legitim und zaehlen nicht mit.
#
# Der Guard schlaegt nur bei ÜBERSCHREITUNG an, nie bei Unterschreitung —
# Teillaeufe (`bin/rails test test/models/foo_test.rb`) loesen also keinen
# Fehlalarm aus.
#
# ENV-Schalter:
#   STRICT_FIXTURES=1  — jeder datenbedingte Skip wird sofort zum Failure.
#                        Zum gezielten Aufraeumen: zeigt alle auf einmal.
#   SKIP_LEDGER=0      — Guard komplett aus (z. B. fuer Bisect-Laeufe).
module SkipLedger
  # Aktueller Stand (Vollauf 2026-08-09, nach den Fixture-Ergaenzungen
  # tournament_ccs/player_rankings/branches und den UMB-VCR-Kassetten:
  # 57 → 19 Skips, davon 12 datenbedingt). Beim Schliessen einer Luecke MIT
  # herunterzaehlen — der Guard soll die Zahl nach unten druecken, nicht
  # konservieren.
  #
  # `STRICT_FIXTURES=1 bin/rails test` listet sie auf einen Schlag als Failures —
  # praktisch beim Abarbeiten.
  #
  # 2026-09-04: Der Guard stand auf 12, real waren es aber 16 — er schlug also laengst an,
  # ohne dass es jemand aufloeste. Beim Gruenziehen der Suite fielen vier stumme Tests weg
  # (CR-02-Regression, accumulate_results, update_game_participations, terminate-Keep): sie
  # holten ihre Spiele per `where("id >= MIN_ID")` und sprangen ab, weil das KO-Setup keine
  # lokalen Spiele erzeugt — genau der Fall, vor dem dieser Ledger warnt. Sie legen ihre
  # Spiele jetzt selbst an. Ist-Stand danach: 12.
  #
  # Die verbleibenden 12 brauchen fehlende Testdaten (RegionCc/NBV-Turniere fuer die
  # MCP-Tools, Shot-/TrainingConcept-/TrainingExample-Fixtures fuer die Admin-Smoke-Shows).
  # `STRICT_FIXTURES=1 bin/rails test` listet sie auf einen Schlag.
  MAX_DATA_SKIPS = 12

  # Skips, die NICHT an fehlenden Testdaten liegen und deshalb nicht zaehlen.
  # Bewusst als Positivliste: alles Unbekannte gilt als datenbedingt, damit ein
  # neuer stummer Skip auffaellt statt durchzurutschen.
  STRUCTURAL_PATTERNS = [
    /VCR-Kassette/i,                    # Kassette fehlt — Aufnahme-Hinweis steht im Skip-Text
    /StimulusReflex/i,                  # ueber HTTP nicht testbar (Werkzeuggrenze)
    /Nur auf (Local Server|API-Server)/, # Scenario-Gate, korrekt so
    /not fully implemented/i,           # Feature existiert noch nicht
    /pre-existing/i,                    # dokumentierter offener Befund
    /known characterization finding/i
  ].freeze

  class << self
    def entries
      @entries ||= []
    end

    def record(test_class, test_name, message)
      entries << {class: test_class, test: test_name, message: message.to_s}
    end

    def enabled?
      ENV["SKIP_LEDGER"] != "0"
    end

    def strict?
      ENV["STRICT_FIXTURES"].present? && ENV["STRICT_FIXTURES"] != "0"
    end

    def structural?(message)
      STRUCTURAL_PATTERNS.any? { |re| re.match?(message.to_s) }
    end

    def data_skips
      entries.reject { |e| structural?(e[:message]) }
    end

    # Wird via Minitest.after_run aufgerufen. Gibt true zurueck, wenn alles ok ist.
    def report!
      return true unless enabled?

      data = data_skips
      return true if data.size <= MAX_DATA_SKIPS

      warn ""
      warn "=" * 72
      warn "Skip-Guard: #{data.size} datenbedingte Skips, erlaubt sind #{MAX_DATA_SKIPS}."
      warn "Ein Test ist stumm geworden — er springt mangels Testdaten ab, statt zu pruefen."
      warn ""
      data.sort_by { |e| [e[:class].to_s, e[:test].to_s] }.each do |e|
        warn "  #{e[:class]}##{e[:test]}"
        warn "      #{e[:message]}"
      end
      warn ""
      warn "Entweder die fehlenden Fixtures ergaenzen (bevorzugt) oder — wenn der Skip"
      warn "wirklich strukturell ist — SkipLedger::STRUCTURAL_PATTERNS erweitern."
      warn "=" * 72
      false
    end
  end
end

module SkipLedgerHook
  # Faengt jeden skip ab, egal ob roh oder ueber einen Helper.
  def skip(message = nil, backtrace = caller)
    SkipLedger.record(self.class.name, name, message)
    if SkipLedger.strict? && !SkipLedger.structural?(message)
      flunk "STRICT_FIXTURES: datenbedingter Skip nicht erlaubt — #{message}"
    end
    super
  end
end

Minitest::Test.prepend(SkipLedgerHook)

Minitest.after_run do
  # Ein bereits roter Lauf bleibt rot — exit(1) ueberschreibt hoechstens einen
  # anderen Fehlercode, verdeckt aber nie ein Failure (der Report kommt zusaetzlich).
  exit(1) unless SkipLedger.report!
end
