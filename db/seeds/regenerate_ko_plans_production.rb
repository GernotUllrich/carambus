#!/usr/bin/env ruby
#
# Script to regenerate all KO/DKO TournamentPlans with corrected round numbers
# Run this on PRODUCTION API server after deploying the code fix
#
# Usage: bin/rails runner regenerate_ko_plans_production.rb
#

puts "=" * 80
puts "  PRODUCTION: Regenerating KO/DKO Tournament Plans"
puts "=" * 80
puts ""
puts "⚠️  WARNING: This will DELETE and RECREATE all KO/DKO plans!"
puts ""
puts "Press ENTER to continue or Ctrl-C to abort..."
STDIN.gets

puts ""
puts "Starting regeneration..."
puts ""

# Delete all existing KO/DKO plans
# IMPORTANT: Use .destroy (not .delete) to trigger callbacks and PaperTrail versioning
deleted_count = 0
TournamentPlan.where("name LIKE ? OR name LIKE ?", "KO_%", "DKO_%").each do |plan|
  puts "Destroying: #{plan.name} (ID #{plan.id})"
  plan.destroy  # Use .destroy to trigger callbacks and PaperTrail
  deleted_count += 1
end

puts ""
puts "✓ Deleted #{deleted_count} old plans"
puts ""
puts "=" * 80
puts "Generating new plans..."
puts ""

# KO plans for 2-64 players
ko_count = 0
(2..64).each do |n|
  plan = TournamentPlan.ko_plan(n)
  if plan
    ko_count += 1
    print "."
    STDOUT.flush
  end
end

puts ""
puts "✓ Created #{ko_count} KO plans"
puts ""

# DKO plans
dko_configs = [
  [8, 4], [16, 8], [32, 8], [64, 8],
  [16, 4], [32, 4], [64, 4],
  [32, 16], [64, 16], [64, 32]
]

dko_count = 0
dko_configs.each do |players, cut|
  plan = TournamentPlan.dko_plan(players, cut_to_sko: cut)
  if plan
    dko_count += 1
    puts "✓ Created DKO_#{players}_#{cut}"
  end
end

puts ""
puts "=" * 80
puts "SUMMARY:"
puts "  #{ko_count} KO plans created"
puts "  #{dko_count} DKO plans created"
puts "  Total: #{ko_count + dko_count} plans"
puts ""
puts "=" * 80
puts "Verifying one plan (KO_31)..."
puts ""

plan = TournamentPlan.find_by(name: "KO_31")
if plan
  params = JSON.parse(plan.executor_params)
  
  # Check round distribution
  round_nos = {}
  params.keys.select { |k| k =~ /^(16f|8f|qf|hf|fin)/ }.each do |gname|
    r_key = params[gname].keys.find { |k| k =~ /r[*\d+]/ }
    if r_key
      r_no = r_key.match(/r([*\d+])/)[1]
      round_nos[r_no] ||= []
      round_nos[r_no] << gname
    end
  end
  
  puts "KO_31 Round distribution:"
  round_nos.sort.each do |r_no, games|
    puts "  Round #{r_no}: #{games.length} games"
  end
  
  if round_nos.keys.length > 1
    puts ""
    puts "✅ VERIFICATION PASSED!"
    puts "   All tournament plans regenerated successfully with correct round numbers!"
  else
    puts ""
    puts "❌ VERIFICATION FAILED!"
    puts "   Plans still have incorrect round numbers!"
  end
else
  puts "❌ KO_31 plan not found!"
end

puts ""
puts "=" * 80
puts "DONE!"
puts ""
puts "Next steps:"
puts "  1. Any active KO tournaments need to be re-initialized"
puts "  2. Players will need to be re-added"
puts "  3. Tournament flow should now work correctly!"
puts ""
