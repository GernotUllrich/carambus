# frozen_string_literal: true

# Phase 21-03 T2: 4 Admin-Parameter aus showMeisterschaft.php nach TournamentCc.
#
# Felder (alle additive nullable):
#   - shot_clock_minutes   integer  "$INT Minuten" Wert aus Shot-Clock-Schwellenwert-Zeile
#                                    (NULL wenn ClubCloud "0 Minuten" = nicht konfiguriert liefert)
#   - points_to_win        integer  Ausspielziel-Zeile; NULL wenn ClubCloud "0" = "keine Begrenzung"
#                                    (Sentinel-Konvention dokumentiert in 21-03-SNIFF-FINDINGS.md)
#   - best_of_sets         integer  Sätze (Best-of-#)-Zeile; meist 1 (best-of-1 default)
#   - tournament_plan_cc_id  FK     auf neue tournament_plan_ccs-Tabelle (CC-Schicht, NICHT FK auf
#                                    globales TournamentPlan-Modell — D-21-03-DISC-B)
#
# strong_migrations: `add_reference foreign_key:` blockt Writes auf beiden Tabellen kurzzeitig.
# Hier per `safety_assured do` legitimiert (Plan-14-G-Pattern, AuthorityReArchitectureUserTournament:5):
#   tournament_plan_cc_id ist frisch nullable hinzugefügt → 100% NULL-Werte → FK-Validate ist
#   nahezu instant; tournament_plan_ccs ist gerade erst angelegt (leer). Praktisch < 100ms-Lock,
#   konsistent mit der "kleine DB / kein Live-Datensatz"-Begründung der 14-G-Migration.
class AddAdminParamsToTournamentCcs < ActiveRecord::Migration[7.2]
  def change
    add_column :tournament_ccs, :shot_clock_minutes, :integer
    add_column :tournament_ccs, :points_to_win, :integer
    add_column :tournament_ccs, :best_of_sets, :integer
    safety_assured do
      add_reference :tournament_ccs, :tournament_plan_cc,
        foreign_key: {to_table: :tournament_plan_ccs},
        null: true,
        index: true
    end
  end
end
