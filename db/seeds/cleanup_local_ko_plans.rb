#!/usr/bin/env ruby
#
# Cleanup script for LOCAL servers (BCW, PHAT, etc.)
#
# PROBLEM:
# Local servers may have old KO/DKO plans that were synced from API
# before we fixed the .delete issue. These need to be manually removed.
#
# Run this on LOCAL servers (NOT on API server)
#

puts "=" * 80
puts "  LOCAL SERVER: Cleanup Old KO/DKO Plans"
puts "=" * 80
puts ""

# Check if this looks like a local server
local_plans = TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%")
                            .where("id < 50000000")  # Local IDs

api_plans = TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%")
                          .where("id >= 50000000")  # Global/API IDs

puts "Found on this server:"
puts "  Local KO/DKO plans (ID < 50M): #{local_plans.count}"
puts "  Global KO/DKO plans (ID >= 50M): #{api_plans.count}"
puts ""

if api_plans.any?
  puts "⚠️  WARNING: This server appears to have global IDs!"
  puts "   This script should only run on LOCAL servers (BCW, PHAT, etc.)"
  puts "   NOT on the API server!"
  puts ""
  puts "Are you sure this is a local server? (yes/no)"
  response = STDIN.gets.chomp.downcase
  
  unless response == 'yes'
    puts "Aborted."
    exit 1
  end
end

if local_plans.empty?
  puts "✓ No local KO/DKO plans found - nothing to clean up!"
  exit 0
end

puts "Plans to be deleted:"
local_plans.each do |plan|
  puts "  #{plan.name} (ID #{plan.id})"
end

puts ""
puts "⚠️  This will use .delete (bypassing sync) because these plans"
puts "   are already out of sync due to the earlier .delete on API server."
puts ""
puts "Press ENTER to delete, or Ctrl-C to abort..."
STDIN.gets

deleted_count = 0
local_plans.each do |plan|
  puts "Deleting: #{plan.name} (ID #{plan.id})"
  # Use .delete here because:
  # 1. These are local copies, not authoritative
  # 2. They're already out of sync (no delete version from API)
  # 3. We don't want to create local versions that conflict with API
  plan.delete
  deleted_count += 1
end

puts ""
puts "✓ Deleted #{deleted_count} local KO/DKO plans"
puts ""
puts "=" * 80
puts "Next steps:"
puts "  1. Verify API server has correct plans (with proper round numbers)"
puts "  2. These new plans will sync from API server automatically"
puts "  3. Or regenerate locally: bin/rails runner db/seeds/regenerate_ko_plans_production.rb"
puts ""
