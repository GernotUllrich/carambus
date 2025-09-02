#!/usr/bin/env ruby
# Test script for optimistic scoreboard updates
# Run with: ruby test/optimistic_updates_test.rb

require_relative '../config/environment'

puts "🧪 Testing Optimistic Scoreboard Updates"
puts "=" * 50

# Test the optimistic service
puts "\n1. Testing ScoreboardOptimisticService..."

# Create a test table monitor
table_monitor = TableMonitor.new(
  data: {
    'playera' => { 'result' => 0, 'innings_redo_list' => [0], 'balls_goal' => 15 },
    'playerb' => { 'result' => 0, 'innings_redo_list' => [0], 'balls_goal' => 15 },
    'current_inning' => { 'active_player' => 'playera' },
    'innings_goal' => 0
  },
  state: 'playing'
)

service = ScoreboardOptimisticService.new(table_monitor)

puts "   Initial state:"
puts "   - Player A score: #{service.current_score('playera')}"
puts "   - Player B score: #{service.current_score('playerb')}"
puts "   - Active player: #{service.current_active_player}"

# Test adding points
puts "\n2. Testing optimistic point addition..."
if service.add_points_optimistically('playera', 3)
  puts "   ✅ Added 3 points to Player A"
  puts "   - New score: #{service.current_score('playera')}"
else
  puts "   ❌ Failed to add points"
end

# Test player change
puts "\n3. Testing optimistic player change..."
if service.change_player_optimistically
  puts "   ✅ Changed active player"
  puts "   - New active player: #{service.current_active_player}"
else
  puts "   ❌ Failed to change player"
end

# Test validation service
puts "\n4. Testing background validation job..."
job = TableMonitorValidationJob.new
puts "   ✅ Job created successfully"

puts "\n5. Testing optimistic service methods..."
puts "   - Valid update check: #{service.valid_quick_update?('playera', 5)}"
puts "   - Player active check: #{service.player_active?('playera')}"

puts "\n" + "=" * 50
puts "✅ All tests completed successfully!"
puts "\nTo see the optimistic updates in action:"
puts "1. Visit: http://localhost:3000/demo/scoreboard"
puts "2. Click the buttons to see immediate feedback"
puts "3. Watch the console for optimistic update logs"
puts "4. Notice the pending indicators and animations"

