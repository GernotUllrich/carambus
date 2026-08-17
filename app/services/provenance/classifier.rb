# frozen_string_literal: true

module Provenance
  # Woher stammen die Daten eines Turniers oder einer Liga? Eine Stelle, zwei Abnehmer:
  # der Abdeckungsreport (`Reports::CoverageData`) und die persistierte Spalte `source_kind`.
  #
  # WARUM AM MUSTER, NICHT AN DER DOMAIN: Jeder Landesverband betreibt seine ClubCloud unter
  # eigenem Namen (ndbv.de, westfalenbillard.net, blv-sa.de …), aber alle liefern dieselben
  # Skripte aus. Eine Domain-Liste wäre schon beim nächsten Umzug falsch — und die gab es
  # mehrfach (BLMR, Saar, BVW, siehe `adhoc.rake:fix_source_urls`). Das Muster hält.
  #
  # KASKADE `source_url` > `ba_id` > `*_cc` (Betreiber 2026-08-16): Wo eine Quell-URL steht,
  # gewinnt sie — ein Datensatz, der später aus einer CC nachgescrapt wurde, trägt beides und
  # gehört dann zur CC. Ohne URL ist die `ba_id` die einzige Spur (die BillardArea ist offline,
  # deshalb gibt es dafür keine URL). Ein `tournament_cc`/`league_cc` zählt erst danach: es ist
  # ein Migrationsartefakt BillardArea→ClubCloud und für sich genommen kein Herkunftsbeleg.
  #
  # ZWEI EINSTIEGSPUNKTE, mit Absicht:
  # - `call` liefert die Provenienz, wie sie belegt ist — inklusive `:none` für „keine Spur"
  #   und `nil` für „URL da, Muster unbekannt". Der Report zeigt beides getrennt an.
  # - `source_kind_for` liefert den Enum-Wert für die Spalte, muss sich also festlegen:
  #   keine Spur = in Carambus selbst angelegt (`:carambus`).
  class Classifier
    SOURCE_PATTERNS = {
      club_cloud: ["sb_meisterschaft.php", "sb_spielplan.php"],
      liga_manager: ["billard.center"],
      nu_liga: ["liga.nu", "nuLigaBILLARD"],
      umb: ["umb-carom.org"],
      carambus: ["carambus.de"]
    }.freeze

    class << self
      # => :club_cloud | :liga_manager | :nu_liga | :umb | :carambus | :ba | :none | nil
      #    (nil = source_url vorhanden, Muster unbekannt — bewusst nicht geraten)
      def call(source_url:, ba_id: nil, cc_present: false)
        if source_url.blank?
          return :ba if ba_id.present?
          return :club_cloud if cc_present

          return :none
        end

        SOURCE_PATTERNS.each do |kind, needles|
          return kind if needles.any? { |needle| source_url.include?(needle) }
        end
        nil
      end

      # Enum-Wert für `tournaments.source_kind` / `leagues.source_kind`.
      # `nil` bleibt `nil`: ein unbekanntes Muster ist eine Anomalie, die sichtbar bleiben soll,
      # statt sie in einen falschen Wert zu pressen.
      def source_kind_for(source_url:, ba_id: nil, cc_present: false)
        kind = call(source_url: source_url, ba_id: ba_id, cc_present: cc_present)
        (kind == :none) ? :carambus : kind
      end
    end
  end
end
