# Seed script for pre-generating all KO and DKO tournament plans
# This eliminates the need for on-the-fly generation and prevents LocalProtector conflicts
#
# Run with: rails runner db/seeds/knockout_tournament_plans.rb
# Or include in db/seeds.rb

puts "=" * 80
puts "  Seeding KO and DKO Tournament Plans"
puts "=" * 80
puts ""

# Track statistics
created_count = 0
existing_count = 0
failed_count = 0

# Helper to create or verify a plan
def create_or_verify_plan(plan, type_name)
  if plan.nil?
    return { status: :invalid, plan: nil }
  end
  
  if plan.persisted?
    return { status: :existing, plan: plan }
  end
  
  if plan.save
    return { status: :created, plan: plan }
  else
    return { status: :failed, plan: plan }
  end
end

# ============================================================================
# KO Plans: 2-64 players
# ============================================================================
puts "Creating KO Tournament Plans (2-64 players)..."
puts "-" * 80

ko_results = []
(2..64).each do |nplayers|
  plan = TournamentPlan.ko_plan(nplayers)
  result = create_or_verify_plan(plan, "KO_#{nplayers}")
  ko_results << result
  
  case result[:status]
  when :created
    created_count += 1
    puts "  ✓ Created: KO_#{nplayers} [#{result[:plan].id}]"
  when :existing
    existing_count += 1
    print "  · Exists:  KO_#{nplayers} [#{result[:plan].id}]\r"
  when :failed
    failed_count += 1
    puts "  ✗ Failed:  KO_#{nplayers} - #{result[:plan].errors.full_messages.join(', ')}"
  when :invalid
    # Not a valid configuration, skip silently
  end
end

puts "" if existing_count > 0  # New line after progress indicators
puts ""

# ============================================================================
# DKO Plans: Common configurations
# ============================================================================
puts "Creating DKO Tournament Plans (common configurations)..."
puts "-" * 80

dko_configs = []

# Generate DKO plans for powers of 2 from 8-64 with common cut points
[8, 16, 32, 64].each do |nplayers|
  # Common cut_to_sko values (must be power of 2 and less than nplayers)
  cut_points = [4, 8, 16, 32].select { |cut| cut < nplayers && (cut & (cut - 1)) == 0 }
  
  cut_points.each do |cut|
    dko_configs << [nplayers, cut]
  end
end

dko_results = []
dko_configs.each do |nplayers, cut_to_sko|
  plan = TournamentPlan.dko_plan(nplayers, cut_to_sko: cut_to_sko)
  result = create_or_verify_plan(plan, "DKO_#{nplayers}_#{cut_to_sko}")
  dko_results << result
  
  case result[:status]
  when :created
    created_count += 1
    puts "  ✓ Created: DKO_#{nplayers}_#{cut_to_sko} [#{result[:plan].id}]"
  when :existing
    existing_count += 1
    print "  · Exists:  DKO_#{nplayers}_#{cut_to_sko} [#{result[:plan].id}]\r"
  when :failed
    failed_count += 1
    puts "  ✗ Failed:  DKO_#{nplayers}_#{cut_to_sko} - #{result[:plan].errors.full_messages.join(', ')}"
  when :invalid
    # Not a valid configuration, skip silently
  end
end

puts "" if existing_count > 0  # New line after progress indicators

# ============================================================================
# Summary
# ============================================================================
puts ""
puts "=" * 80
puts "  Summary"
puts "=" * 80
puts ""
puts "KO Plans:"
puts "  Total processed: #{ko_results.size}"
puts "  Created:  #{ko_results.count { |r| r[:status] == :created }}"
puts "  Existing: #{ko_results.count { |r| r[:status] == :existing }}"
puts "  Failed:   #{ko_results.count { |r| r[:status] == :failed }}"
puts ""
puts "DKO Plans:"
puts "  Total processed: #{dko_results.size}"
puts "  Created:  #{dko_results.count { |r| r[:status] == :created }}"
puts "  Existing: #{dko_results.count { |r| r[:status] == :existing }}"
puts "  Failed:   #{dko_results.count { |r| r[:status] == :failed }}"
puts ""
puts "TOTAL:"
puts "  Created:  #{created_count}"
puts "  Existing: #{existing_count}"
puts "  Failed:   #{failed_count}"
puts ""

if failed_count > 0
  puts "⚠ Some plans failed to create. Check errors above."
  exit 1
else
  puts "✅ All knockout tournament plans are ready!"
  puts ""
  puts "These plans will be synced to local servers and available for use."
  puts "The ko_plan/dko_plan methods will return existing plans (no generation needed)."
end

puts ""
puts "=" * 80
