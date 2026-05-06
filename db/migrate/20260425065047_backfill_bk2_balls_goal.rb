# frozen_string_literal: true

class BackfillBk2BallsGoal < ActiveRecord::Migration[7.2]
  # Phase 38.4 Plan 04 (D-06) — idempotent backfill:
  # For in-flight BK2-Kombi TableMonitors on BCW where bk2_options["set_target_points"]
  # was written by the now-retired code path, copy that value into
  # tournament_monitor.balls_goal so the new scoring logic reads a valid target.

  disable_ddl_transaction! # safety; no DDL

  def up
    say_with_time "Backfilling tournament_monitor.balls_goal from bk2_options['set_target_points']" do
      count = 0
      TableMonitor.find_each do |tm|
        options = tm.data.is_a?(Hash) ? tm.data["bk2_options"] : nil
        next unless options.is_a?(Hash)

        legacy_stp = options["set_target_points"].to_i
        next if legacy_stp.zero?

        tournament_monitor = tm.tournament_monitor
        next if tournament_monitor.blank?

        # Only backfill if current balls_goal is absent or zero
        if tournament_monitor.balls_goal.to_i.zero?
          tournament_monitor.update_columns(balls_goal: legacy_stp, updated_at: Time.current)
          count += 1
        end
      end
      say "Backfilled #{count} tournament_monitors."
    end
  end

  def down
    # No-op: we never want to revert a balls_goal backfill destructively.
    say "No-op: BackfillBk2BallsGoal is not reversible."
  end
end
