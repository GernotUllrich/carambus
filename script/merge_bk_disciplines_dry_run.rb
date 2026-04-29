# frozen_string_literal: true

#
# DRY-RUN WRAPPER for script/merge_bk_disciplines.rb
#
# Wraps the full merge script execution in a transaction that is rolled back
# after the script completes. The Markdown protocol file is written during
# execution (to tmp/merge-bk-disciplines-*.md) and remains on disk as
# evidence of what the production run WOULD do — but NO database changes
# are committed.
#
# Usage:
#   RAILS_ENV=development bin/rails runner script/merge_bk_disciplines_dry_run.rb
#
# After the run, the dev DB is byte-identical to its pre-run state.
# The protocol file in tmp/ is the only artifact.
#

puts "=" * 70
puts "DRY-RUN MODE — All DB changes will be rolled back after script completes"
puts "Protocol file will be written to tmp/ and retained on disk."
puts "=" * 70
puts ""

# Capture baseline for post-rollback verification
discipline_count_before = Discipline.count
loser_count_before = Discipline.where(id: [57, 59, 60, 61, 62, 95]).count
winner_107_name_before = Discipline.find_by(id: 107)&.name

puts "Baseline (pre-run):"
puts "  Discipline.count = #{discipline_count_before}"
puts "  Losers present = #{loser_count_before}"
puts "  Winner 107 name = #{winner_107_name_before.inspect}"
puts ""

ActiveRecord::Base.transaction do
  # Load and execute the merge script inline
  load Rails.root.join("script", "merge_bk_disciplines.rb")

  # Capture the protocol path before rollback
  protocol_file = PROTOCOL_PATH.to_s
  puts ""
  puts "=" * 70
  puts "DRY-RUN: Rolling back all DB changes now..."
  puts "Protocol retained at: #{protocol_file}"
  puts "=" * 70

  raise ActiveRecord::Rollback
end

# Verify rollback
discipline_count_after = Discipline.count
loser_count_after = Discipline.where(id: [57, 59, 60, 61, 62, 95]).count
winner_107_name_after = Discipline.find_by(id: 107)&.name

puts ""
puts "Post-rollback verification:"
puts "  Discipline.count = #{discipline_count_after} (expected #{discipline_count_before})"
puts "  Losers present = #{loser_count_after} (expected #{loser_count_before})"
puts "  Winner 107 name = #{winner_107_name_after.inspect} (expected #{winner_107_name_before.inspect})"

if discipline_count_after == discipline_count_before &&
    loser_count_after == loser_count_before &&
    winner_107_name_after == winner_107_name_before
  puts ""
  puts "ROLLBACK VERIFIED: Dev DB is unchanged."
else
  puts ""
  puts "WARNING: Rollback verification FAILED — counts or names differ!"
  puts "  Inspect the dev DB manually before proceeding."
end
