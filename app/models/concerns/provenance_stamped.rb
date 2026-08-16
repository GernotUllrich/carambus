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

  # DER CC-los-Indikator (Plan 34-02, Ziel G2). Vorher beantworteten zwei Codestellen dieselbe Frage
  # verschieden: der Wizard fragte DIE REGION (`Region::SHORTNAMES_CC` — hartkodiert und saison-blind),
  # der Ergebnisweg den CC-ZWILLING (`tournament_cc` — ein Migrationsartefakt BillardArea→ClubCloud).
  # Ein Turnier konnte bei der einen Stelle CC-los sein und bei der anderen nicht.
  #
  # ÜBERGANGS-FALLBACK (Betreiber 2026-08-16), **entfernbar**: `source_kind` ist auf der Authority
  # gefüllt, erreicht die Region- und Location-Server aber erst mit dem nächsten Version-Sync. In
  # diesem Fenster ist die Spalte dort `nil` — ohne Fallback sähe jeder Server jedes Turnier als
  # CC-los und NBV verlöre schlagartig seine CC-Schritte. Der Fallback antwortet wie das bisherige
  # Record-Signal und kippt von selbst um, sobald der Wert eintrifft. Kein Deploy-Reihenfolge-Zwang.
  # Wenn `Tournament.where(source_kind: nil).count == 0` überall gilt, kann er weg.
  def cc_sourced?
    return source_club_cloud? if source_kind.present?

    legacy_cc_signal?
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
