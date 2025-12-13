#!/usr/bin/env ruby
# Korrigiert innings_goal für das laufende Turnier 17388
# Verwendung: RAILS_ENV=production bundle exec rails runner scripts/fix_tournament_17388_innings_goal.rb

puts "=" * 80
puts "Korrigiere innings_goal für Turnier 17388"
puts "=" * 80
puts ""

begin
  t = Tournament.find(17388)
  tm = t.tournament_monitor

  puts "VORHER:"
  puts "  Tournament.innings_goal: #{t.innings_goal.inspect}"
  puts "  Tournament.balls_goal: #{t.balls_goal.inspect}"
  puts "  TournamentMonitor.innings_goal: #{tm.innings_goal.inspect}"
  puts "  TournamentMonitor.balls_goal: #{tm.balls_goal.inspect}"
  puts ""

  # Korrigiere Tournament
  if t.innings_goal.nil? || t.innings_goal == 0
    t.update_columns(innings_goal: 25)
    puts "✓ Tournament.innings_goal korrigiert: nil/0 → 25"
  else
    puts "✓ Tournament.innings_goal ist bereits korrekt: #{t.innings_goal}"
  end

  # Korrigiere TournamentMonitor
  needs_update = false
  updates = {}
  
  if tm.innings_goal.nil? || tm.innings_goal == 0
    updates[:innings_goal] = 25
    needs_update = true
  end
  
  if tm.balls_goal.nil? || tm.balls_goal == 0
    updates[:balls_goal] = 30
    needs_update = true
  end
  
  if needs_update
    tm.update_columns(updates)
    puts "✓ TournamentMonitor korrigiert: #{updates.inspect}"
  else
    puts "✓ TournamentMonitor ist bereits korrekt"
  end
  
  puts ""
  puts "Korrigiere TableMonitors..."
  
  # Korrigiere alle TableMonitors
  tm.table_monitors.each do |tbl_mon|
    if tbl_mon.data['innings_goal'].nil? || tbl_mon.data['innings_goal'] == 0
      new_data = tbl_mon.data.dup
      new_data['innings_goal'] = 25
      tbl_mon.update_column(:data, new_data)
      puts "  ✓ TableMonitor[#{tbl_mon.id}] korrigiert: innings_goal = 25"
    else
      puts "  ✓ TableMonitor[#{tbl_mon.id}] bereits korrekt: #{tbl_mon.data['innings_goal']}"
    end
  end

  puts ""
  puts "NACHHER:"
  t.reload
  tm.reload
  puts "  Tournament.innings_goal: #{t.innings_goal.inspect}"
  puts "  Tournament.balls_goal: #{t.balls_goal.inspect}"
  puts "  TournamentMonitor.innings_goal: #{tm.innings_goal.inspect}"
  puts "  TournamentMonitor.balls_goal: #{tm.balls_goal.inspect}"
  
  if tm.table_monitors.any?
    sample = tm.table_monitors.first
    sample.reload
    puts "  TableMonitor[#{sample.id}].data['innings_goal']: #{sample.data['innings_goal'].inspect}"
  end
  
  puts ""
  puts "=" * 80
  puts "✓ ERFOLGREICH ABGESCHLOSSEN"
  puts "=" * 80

rescue ActiveRecord::RecordNotFound
  puts "✗ FEHLER: Turnier 17388 nicht gefunden!"
  exit 1
rescue => e
  puts "✗ FEHLER: #{e.message}"
  puts e.backtrace.first(5).join("\n")
  exit 1
end

