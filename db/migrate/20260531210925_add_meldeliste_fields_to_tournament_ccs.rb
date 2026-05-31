# frozen_string_literal: true

# Plan 23-01 T1a (Seeding-Unification): TCc übernimmt die CC-System-IDs +
# Meldetermin-Felder, die heute in RegistrationListCc leben. T1b dropped danach
# die RL/RC-Tabellen.
#
# Felder (alle additive nullable):
#   - meldeliste_cc_id           integer   CC-System-ID der Meldeliste (war RL.cc_id)
#   - meldeliste_deadline        datetime  Meldeschluss (war RL.deadline)
#   - meldeliste_qualifying_date datetime  Stichtag      (war RL.qualifying_date)
#
# Backfill aus RegistrationListCc via tournament_ccs.registration_list_cc_id
# (der interne FK wird in T1b entfernt).
#
# D-23-01-B (revidiert während T1a-Apply): Ursprünglich Unique-Index auf
# seedings(tournament_id, player_id, global_context) geplant. T1a-Probe enthüllte
# 15535 Bestands-Duplikat-Gruppen — keine echten Duplikate, sondern andere
# Datenmodelle (Round-Snapshots, Liga-Aufstellungen, tournament_id=NULL bei Ligen).
# Idempotenz wird stattdessen in T2-Code durchgesetzt (find_or_initialize_by im
# RegistrationSyncer); Bestandsdaten bleiben unangetastet.
#
# Strong_migrations-konform:
#   - add_column nullable, kein DEFAULT, kein NOT NULL → safe
#   - Backfill via find_each(batch_size: 500) + update_columns → safe
#   - disable_ddl_transaction! weil Backfill außerhalb DDL-Transaction laufen soll
class AddMeldelisteFieldsToTournamentCcs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    add_column :tournament_ccs, :meldeliste_cc_id, :integer unless column_exists?(:tournament_ccs, :meldeliste_cc_id)
    add_column :tournament_ccs, :meldeliste_deadline, :datetime unless column_exists?(:tournament_ccs, :meldeliste_deadline)
    add_column :tournament_ccs, :meldeliste_qualifying_date, :datetime unless column_exists?(:tournament_ccs, :meldeliste_qualifying_date)

    say_with_time "Backfilling meldeliste_* on tournament_ccs from RegistrationListCc" do
      scope = TournamentCc.where.not(registration_list_cc_id: nil)
      total = scope.count
      filled = 0
      missing = 0
      scope.find_each(batch_size: 500) do |tcc|
        rl = RegistrationListCc.find_by(id: tcc.registration_list_cc_id)
        unless rl
          missing += 1
          next
        end
        tcc.update_columns(
          meldeliste_cc_id: rl.cc_id,
          meldeliste_deadline: rl.deadline,
          meldeliste_qualifying_date: rl.qualifying_date
        )
        filled += 1
      end
      say "Backfilled #{filled}/#{total} TournamentCc records (#{missing} with stale registration_list_cc_id)."
    end
  end

  def down
    remove_column :tournament_ccs, :meldeliste_qualifying_date if column_exists?(:tournament_ccs, :meldeliste_qualifying_date)
    remove_column :tournament_ccs, :meldeliste_deadline if column_exists?(:tournament_ccs, :meldeliste_deadline)
    remove_column :tournament_ccs, :meldeliste_cc_id if column_exists?(:tournament_ccs, :meldeliste_cc_id)
  end
end
