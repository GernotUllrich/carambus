# frozen_string_literal: true

# Phase 21-04 T2 (Slice C): age_class + gender als heuristisch ableitbare Player-Spalten.
#
# Felder (alle additive nullable):
#   - age_class  string  CategoryCc.name mit MAX(min_age) über qualifizierte seedings (NBV-Pilot)
#                         NULL wenn keine qualifizierte seedings ODER MAX(min_age)=0
#   - gender     string  M/F/U (CategoryCc::SEX_MAP-Keys) der jüngsten seedings
#                         NULL wenn keine qualifizierte seedings
#
# Strong_migrations-clean OHNE safety_assured (kein FK, kein Backfill, kein Index, keine
# DEFAULT/NOT NULL-Konflikte): einfache additive nullable Spalten — Test-Hygiene-Lehre 1
# aus 21-03 explizit angewendet ([[feedback_safety_assured_masks_strong_migrations]]).
#
# Persistierung in T3-Heuristik-Service `PlayerAgeClassGenderHeuristic` (kein Backfill in
# der Migration selbst; D-21-04-DISC-G "Persistierung statt Compute-on-read").
class AddAgeClassAndGenderToPlayers < ActiveRecord::Migration[7.2]
  def change
    add_column :players, :age_class, :string
    add_column :players, :gender, :string
  end
end
