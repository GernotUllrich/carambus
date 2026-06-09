# frozen_string_literal: true

# Phase 21-03 T2: TournamentPlanCc — CC-Schicht für ClubCloud-Turnierpläne.
#
# Analog ChampionshipTypeCc/CategoryCc/GroupCc: flaches Modell mit (cc_id, name, context).
# Context = Region-Shortname downcased (z.B. "nbv"). cc_id ist nullable, da `showMeisterschaft.php`
# nur den Plan-Namen liefert, nicht zwingend eine numerische cc_id — Lookup-Key in T3 ist
# (context, name) wenn cc_id fehlt; (context, cc_id) wenn vorhanden.
#
# Strong-migrations: neue Tabelle, keine Constraints auf Bestand → unkritisch.
class CreateTournamentPlanCcs < ActiveRecord::Migration[7.2]
  def change
    create_table :tournament_plan_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.string :context
      t.timestamps
    end
    add_index :tournament_plan_ccs, [:context, :cc_id], name: "index_tournament_plan_ccs_on_context_and_cc_id"
    add_index :tournament_plan_ccs, [:context, :name], name: "index_tournament_plan_ccs_on_context_and_name"
  end
end
