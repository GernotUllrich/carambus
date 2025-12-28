#!/usr/bin/env ruby
# Test-Script für ClubCloud Name-Mapping

require_relative '../config/environment'

# Test-Cases: Carambus gname => Erwarteter ClubCloud-Name
test_cases = {
  # Gruppen
  "group1:1-2" => "Gruppe A",
  "group1:3-4" => "Gruppe A",
  "group1:1-2/2" => "Gruppe A",
  "Gruppe 1" => "Gruppe A",
  "group2:1-2" => "Gruppe B",
  "Gruppe 2" => "Gruppe B",
  "group3:5-6" => "Gruppe C",
  "Gruppe 3" => "Gruppe C",
  "group4:1-2" => "Gruppe D",
  
  # Platzierungsspiele
  "Platz 3-4" => "Spiel um Platz 3",
  "Platz 5-6" => "Spiel um Platz 5",
  "Platz 7-8" => "Spiel um Platz 7",
  "Platz 9-10" => "Spiel um Platz 9",
  "p<3-4>" => "Spiel um Platz 3",
  "p<5-6>" => "Spiel um Platz 5",
  "p<9-10>" => "Spiel um Platz 9",
  
  # Halbfinale & Finale
  "hf1" => "Halbfinale",
  "hf2" => "Halbfinale",
  "Halbfinale 1" => "Halbfinale",
  "Halbfinale" => "Halbfinale",
  "fin" => "Finale",
  "Finale" => "Finale"
}

puts "Testing ClubCloud Name Mapping"
puts "=" * 80
puts ""

passed = 0
failed = 0
errors = []

test_cases.each do |carambus_name, expected_cc_name|
  result = Setting.map_game_gname_to_cc_group_name(carambus_name)
  
  if result == expected_cc_name
    puts "✓ '#{carambus_name}' => '#{result}'"
    passed += 1
  else
    puts "✗ '#{carambus_name}' => '#{result}' (expected: '#{expected_cc_name}')"
    failed += 1
    errors << { input: carambus_name, got: result, expected: expected_cc_name }
  end
end

puts ""
puts "=" * 80
puts "Results: #{passed} passed, #{failed} failed"

if failed > 0
  puts ""
  puts "Failed mappings:"
  errors.each do |err|
    puts "  Input: #{err[:input]}"
    puts "    Expected: #{err[:expected]}"
    puts "    Got:      #{err[:got] || '(nil)'}"
    puts ""
  end
  exit 1
else
  puts "✓ All tests passed!"
  exit 0
end





