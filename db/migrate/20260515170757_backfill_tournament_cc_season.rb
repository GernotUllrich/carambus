# frozen_string_literal: true

# Plan 14-G.7 / Task 3 / F11: TournamentCc.season-Backfill für stale Records.
# Bei manchen TournamentCc-Records ist `season` null — `cc_list_open_tournaments`
# mit Default-Season-Filter liefert dann fehlende oder stale Treffer.
#
# Pattern: D-13-06.4-A (update_columns für Backfill — skip Callbacks/Validations)
# und D-13-06.4-B (down ist NO-OP — Backfills sind nicht-rückwärts-rollbar).
# Idempotent: Re-Run hat keinen Effekt (WHERE season IS NULL bleibt leer nach erstem Lauf).
#
# Fallback-Quelle: tournament_start-Datum (Juli-Cutoff via Season.season_from_date).
# Records ohne tournament_start können nicht gefixt werden — bleiben mit season=null
# (Daten-Quality-Issue, separater v0.5-Backlog-Item).
class BackfillTournamentCcSeason < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    say_with_time "Backfilling TournamentCc.season from tournament_start" do
      scope = TournamentCc.where(season: nil).where.not(tournament_start: nil)
      total = scope.count
      filled = 0
      scope.find_each(batch_size: 500) do |tcc|
        season = Season.season_from_date(tcc.tournament_start.to_date)
        next unless season&.name
        tcc.update_columns(season: season.name)
        filled += 1
      end
      say "Filled #{filled}/#{total} TournamentCc records with derived season."

      remaining = TournamentCc.where(season: nil).count
      say "Remaining null-season records (without tournament_start): #{remaining}"
    end
  end

  def down
    # NO-OP — D-13-06.4-B-Pattern. Backfill ist nicht-rückwärts-rollbar:
    # ein Reset auf null würde die Read-Side-Tools mit Default-Season-Filter
    # für die fortan-gefixte Records sofort wieder blind machen.
  end
end
