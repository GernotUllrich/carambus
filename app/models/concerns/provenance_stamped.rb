# frozen_string_literal: true

# Saison-abhängige Quellen-Kennung für `Tournament` und `League` (Phase 34-01).
#
# WARUM AM OBJEKT UND NICHT AN DER REGION: Dieselbe Region wechselt die Quelle über die Zeit —
# TBV lief bis ~2024 über die ClubCloud, danach über den LigaManager bzw. CC-los; die Ligen der
# Saison 2025/2026 wurden nach dem CC-Tod aus dem LigaManager NEU gescrapt, mit geänderter
# `source_url`. `Tournament` und `League` sind saison-spezifische Records (`season_id`), also ist
# eine Kennung an ihnen von Natur aus saison-abhängig. `region_cc` ist die falsche Ebene und
# trägt bei migrierten Regionen noch einen Alt-Datensatz.
#
# STEMPEL-REGEL: `source_kind` folgt der `source_url` — gesetzt beim Anlegen und beim Wechsel der
# URL, damit die Kennung mitwandert, wenn ein Record die Quelle wechselt. Ein bereits gesetzter
# Wert bleibt bei unveränderter URL stehen; das schützt bewusst gesetzte Werte (Backfill,
# Nachstempeln durch `TournamentCc`/`LeagueCc`) vor dem Überschreiben bei jedem Speichern.
#
# KEIN DB-ZUGRIFF IM SAVE-PFAD: Das `*_cc`-Signal der Kaskade wird hier NICHT abgefragt. Es ist
# Sache des Backfills (Altbestand) und des `after_create` in `TournamentCc`/`LeagueCc` (Neuanlage).
module ProvenanceStamped
  extend ActiveSupport::Concern

  # String-Enum, nicht Integer: der Wert wandert per PaperTrail-Version in die Regional-Server und
  # muss dort ohne den passenden Code deutbar bleiben. `prefix: :source` verhindert zu generische
  # Methodennamen (`Tournament.ba`, `#umb?`).
  SOURCE_KINDS = {
    club_cloud: "club_cloud",
    liga_manager: "liga_manager",
    nu_liga: "nu_liga",
    umb: "umb",
    carambus: "carambus",
    ba: "ba"
  }.freeze

  included do
    enum :source_kind, SOURCE_KINDS, prefix: :source

    before_save :stamp_source_kind
  end

  # DER CC-los-Indikator — eine Stelle, ein Feld (Plan 34-02 Ziel G2, vollendet in 34-03).
  # Vorher beantworteten zwei Codestellen dieselbe Frage verschieden: der Wizard fragte DIE REGION
  # (`Region::SHORTNAMES_CC` — hartkodiert und saison-blind), der Ergebnisweg den CC-ZWILLING
  # (`tournament_cc` — ein Migrationsartefakt BillardArea→ClubCloud). Ein Turnier konnte bei der einen
  # Stelle CC-los sein und bei der anderen nicht. Beide Altsignale sind als Indikator abgelöst; die
  # Assoziationen selbst bleiben, sie tragen weiterhin die CC-Anbindung (Upload/Scrape).
  #
  # WARUM DER nil-FALL GEMELDET UND NICHT KOMPENSIERT WIRD (34-03): Bis 37-03 fing hier ein
  # Übergangs-Fallback ab, dass `source_kind` einen Server noch nicht per Sync erreicht hatte — still.
  # Genau diese Bauart war der Fehler von Phase 37: was lautlos kompensiert wird, faellt nie auf, und
  # das Uebergangsfenster schloss sich deshalb nie (der Sync setzte ungueltige Records still zurueck).
  # Heute traegt jeder Record auf jeder gemessenen Instanz einen Wert, und neue bekommen ihn beim
  # Anlegen (`:none → :carambus` im Klassifikator). Bleibt trotzdem einer leer — etwa eine neue Quelle
  # mit unbekanntem URL-Muster —, dann ist er CC-los UND sichtbar, statt sich als CC-los zu tarnen.
  def cc_sourced?
    if source_kind.blank?
      Rails.logger.warn "[provenance] #{self.class.name}[#{id}] ohne source_kind — als CC-los " \
        "behandelt. Herkunft klaeren (unbekanntes source_url-Muster? Sync-Rueckstand?)."
      return false
    end

    source_club_cloud?
  end

  private

  def stamp_source_kind
    return unless source_url_changed? || source_kind.blank?

    kind = Provenance::Classifier.source_kind_for(source_url: source_url, ba_id: ba_id)
    # nil = URL vorhanden, Muster unbekannt. Dann lieber den alten Wert stehen lassen als raten —
    # die Anomalie soll im Backfill-Bericht auffallen, nicht in einem falschen Enum-Wert verschwinden.
    self.source_kind = kind.to_s if kind.present?
  end
end
