#!/usr/bin/env ruby
#
# Cleanup script for KO/DKO TournamentPlan versions after .delete was incorrectly used
#
# PROBLEM:
# - Old KO/DKO plans were deleted with .delete (bypassing PaperTrail)
# - PaperTrail has CREATE versions but no DELETE versions
# - This breaks synchronization to local servers
#
# SOLUTION:
# 1. Clean up orphaned PaperTrail versions on API server
# 2. Manually delete old plans on local servers (where already synced)
# 3. Then regenerate with correct .destroy method
#
# Run this BEFORE running regenerate_ko_plans_production.rb
#

puts "=" * 80
puts "  Cleanup: PaperTrail Versions for Deleted KO/DKO Plans"
puts "=" * 80
puts ""
puts "This script will:"
puts "  1. Find PaperTrail versions for KO/DKO plans that no longer exist"
puts "  2. Delete those orphaned versions"
puts "  3. Report what was cleaned up"
puts ""
puts "⚠️  WARNING: This modifies PaperTrail version history!"
puts ""
puts "Press ENTER to continue or Ctrl-C to abort..."
STDIN.gets

puts ""
puts "Step 1: Finding orphaned PaperTrail versions..."
puts "-" * 80

# Find all PaperTrail versions for TournamentPlans with KO/DKO names
orphaned_versions = PaperTrail::Version.where(
  item_type: 'TournamentPlan'
).where(
  "object_changes LIKE '%name:%' AND (object_changes LIKE '%KO\\_%' OR object_changes LIKE '%DKO\\_%')"
)

# Filter to only versions where the plan no longer exists
versions_to_delete = []
orphaned_versions.each do |version|
  # Check if the plan still exists
  plan_exists = TournamentPlan.exists?(version.item_id)
  
  unless plan_exists
    versions_to_delete << version
  end
end

puts "Found #{versions_to_delete.count} orphaned versions for deleted KO/DKO plans"
puts ""

if versions_to_delete.empty?
  puts "✓ No orphaned versions found - nothing to clean up!"
  puts ""
  exit 0
end

# Show sample of what will be deleted
puts "Sample of versions to be deleted:"
versions_to_delete.first(10).each do |version|
  puts "  Version #{version.id}: TournamentPlan[#{version.item_id}] - #{version.event} at #{version.created_at}"
end

if versions_to_delete.count > 10
  puts "  ... and #{versions_to_delete.count - 10} more"
end

puts ""
puts "Press ENTER to delete these versions, or Ctrl-C to abort..."
STDIN.gets

puts ""
puts "Step 2: Deleting orphaned versions..."
puts "-" * 80

deleted_count = 0
versions_to_delete.each do |version|
  # Here we CAN use .delete because PaperTrail::Version entries
  # don't need their own versioning and don't sync between servers
  version.delete
  deleted_count += 1
  print "." if deleted_count % 10 == 0
  STDOUT.flush
end

puts ""
puts ""
puts "✓ Deleted #{deleted_count} orphaned PaperTrail versions"
puts ""

puts "=" * 80
puts "Step 3: Checking for remaining KO/DKO plans..."
puts "-" * 80

remaining_plans = TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%")
puts "Found #{remaining_plans.count} KO/DKO plans still in database"

if remaining_plans.any?
  puts ""
  puts "Sample of remaining plans:"
  remaining_plans.first(10).each do |plan|
    puts "  #{plan.name} (ID #{plan.id}) - created #{plan.created_at}"
  end
  
  puts ""
  puts "⚠️  These plans should be removed with .destroy before regenerating!"
  puts ""
  puts "Next steps:"
  puts "  1. Run: bin/rails runner db/seeds/regenerate_ko_plans_production.rb"
  puts "     (This will use .destroy to properly remove and recreate plans)"
else
  puts "✓ No KO/DKO plans remain in database"
  puts ""
  puts "Next steps:"
  puts "  1. Run: bin/rails runner db/seeds/regenerate_ko_plans_production.rb"
  puts "     (This will create new plans with correct round numbers)"
end

puts ""
puts "=" * 80
puts "CLEANUP COMPLETE!"
puts ""
puts "For local servers that have already synced the old plans:"
puts "  You may need to manually delete them using .delete since they"
puts "  won't receive delete versions from the API server."
puts ""
puts "Example cleanup script for local servers:"
puts '  TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%")'
puts '                .where("id < 50000000")  # Only local copies'
puts '                .each { |p| p.delete }   # OK on local since already out of sync'
puts ""
