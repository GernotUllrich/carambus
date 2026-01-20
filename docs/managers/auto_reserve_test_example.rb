# Testskript für automatische Tischreservierung
# 
# Dieses Skript demonstriert, wie die automatische Tischreservierung funktioniert
# WICHTIG: NUR IN ENTWICKLUNGSUMGEBUNG AUSFÜHREN!
#
# Verwendung:
#   rails console
#   load 'docs/managers/auto_reserve_test_example.rb'

puts "=" * 80
puts "Automatische Tischreservierung - Test-Beispiel"
puts "=" * 80
puts ""
puts "⚠️  WARNUNG: Dies ist ein Test-Skript für Entwicklungsumgebung!"
puts "⚠️  Führen Sie dies NICHT in Production aus, ohne die Auswirkungen zu verstehen!"
puts ""

# Beispiel 1: Turnier mit Tournament Plan
puts "\n" + "-" * 80
puts "Beispiel 1: Turnier mit zugeordnetem Tournament Plan"
puts "-" * 80

tournament = Tournament.where(single_or_league: 'single')
                      .where.not(location_id: nil)
                      .where.not(discipline_id: nil)
                      .where.not(tournament_plan_id: nil)
                      .first

if tournament
  puts "Turnier gefunden: #{tournament.title}"
  puts "  Location: #{tournament.location.name}"
  puts "  Disziplin: #{tournament.discipline.name}"
  puts "  Tournament Plan: #{tournament.tournament_plan.name}" if tournament.tournament_plan
  puts "  Teilnehmer: #{tournament.seedings.where.not(state: 'no_show').count}"
  
  puts "\nBerechnung der benötigten Tische..."
  tables_needed = tournament.required_tables_count
  puts "  → Benötigte Tische: #{tables_needed}"
  
  if tournament.discipline.table_kind
    available_tables = tournament.location.tables
                                 .joins(:table_kind)
                                 .where(table_kinds: { id: tournament.discipline.table_kind_id })
                                 .where.not(tpl_ip_address: nil)
                                 .order(:id)
    
    puts "\nVerfügbare Tische mit Heizung:"
    available_tables.each do |table|
      puts "  - #{table.name} (ID: #{table.id}, TableKind: #{table.table_kind.name})"
    end
    
    selected_tables = available_tables.limit(tables_needed)
    puts "\nAusgewählte Tische (#{selected_tables.count}):"
    selected_tables.each do |table|
      puts "  - #{table.name}"
    end
  end
  
  puts "\n⚠️  Um eine Reservierung zu erstellen (NUR in Development!):"
  puts "    tournament = Tournament.find(#{tournament.id})"
  puts "    response = tournament.create_table_reservation"
  puts "    puts response.inspect"
else
  puts "⚠️  Kein geeignetes Turnier gefunden."
  puts "Kriterien: single_or_league='single', location_id vorhanden, discipline_id vorhanden, tournament_plan_id vorhanden"
end

# Beispiel 2: Turnier ohne Tournament Plan (Fallback)
puts "\n" + "-" * 80
puts "Beispiel 2: Turnier ohne Tournament Plan (Fallback-Berechnung)"
puts "-" * 80

tournament2 = Tournament.where(single_or_league: 'single')
                       .where.not(location_id: nil)
                       .where.not(discipline_id: nil)
                       .where(tournament_plan_id: nil)
                       .joins(:seedings)
                       .group('tournaments.id')
                       .having('COUNT(seedings.id) > 0')
                       .first

if tournament2
  puts "Turnier gefunden: #{tournament2.title}"
  puts "  Location: #{tournament2.location.name}"
  puts "  Disziplin: #{tournament2.discipline.name}"
  puts "  Tournament Plan: (nicht zugeordnet)"
  puts "  Teilnehmer: #{tournament2.seedings.where.not(state: 'no_show').count}"
  
  puts "\nBerechnung der benötigten Tische (Fallback)..."
  tables_needed = tournament2.required_tables_count
  participant_count = tournament2.seedings.where.not(state: 'no_show').count
  puts "  Teilnehmer: #{participant_count}"
  puts "  → Benötigte Tische (Fallback): #{tables_needed}"
  puts "  (Formel: (#{participant_count} / 2).ceil = #{tables_needed})"
else
  puts "⚠️  Kein geeignetes Turnier ohne Tournament Plan gefunden."
end

# Beispiel 3: Rake Task Simulation
puts "\n" + "-" * 80
puts "Beispiel 3: Simulation des Rake Tasks"
puts "-" * 80

cutoff_date = 7.days.ago
now = Time.current

tournaments = Tournament
  .where(single_or_league: 'single')
  .where.not(location_id: nil)
  .where.not(discipline_id: nil)
  .where('date >= ?', now)
  .where('accredation_end IS NOT NULL')
  .where('accredation_end >= ? AND accredation_end <= ?', cutoff_date, now)
  .includes(:location, :discipline, :tournament_cc, :seedings, :tournament_plan)

puts "Gefundene Turniere (Meldeschluss in letzten 7 Tagen):"
puts "  Anzahl: #{tournaments.count}"

if tournaments.any?
  puts "\nDetails:"
  tournaments.each_with_index do |t, idx|
    puts "\n  #{idx + 1}. #{t.title || t.shortname}"
    puts "     ID: #{t.id}"
    puts "     Datum: #{t.date}"
    puts "     Meldeschluss: #{t.accredation_end}"
    puts "     Teilnehmer: #{t.seedings.where.not(state: 'no_show').count}"
    puts "     Benötigte Tische: #{t.required_tables_count}"
  end
  
  puts "\n⚠️  Um den Rake Task manuell auszuführen:"
  puts "    bundle exec rake carambus:auto_reserve_tables"
else
  puts "\n  Keine Turniere gefunden, die die Kriterien erfüllen."
  puts "\n  Kriterien:"
  puts "    - single_or_league = 'single'"
  puts "    - location_id vorhanden"
  puts "    - discipline_id vorhanden"
  puts "    - date >= heute"
  puts "    - accredation_end zwischen #{cutoff_date.strftime('%Y-%m-%d')} und #{now.strftime('%Y-%m-%d')}"
end

# Hilfreiche Abfragen
puts "\n" + "=" * 80
puts "Hilfreiche Abfragen für die Console"
puts "=" * 80
puts ""
puts "# Alle Einzelturniere mit Location und Disziplin:"
puts "Tournament.where(single_or_league: 'single').where.not(location_id: nil).where.not(discipline_id: nil).count"
puts ""
puts "# Turniere mit Meldeschluss in den letzten 7 Tagen:"
puts "Tournament.where('accredation_end >= ? AND accredation_end <= ?', 7.days.ago, Time.current).count"
puts ""
puts "# Tische mit Heizung an einer Location:"
puts "location = Location.first"
puts "location.tables.where.not(tpl_ip_address: nil).count"
puts ""
puts "# Manuell eine Reservierung erstellen:"
puts "tournament = Tournament.find(ID)"
puts "response = tournament.create_table_reservation"
puts "puts response.summary"
puts ""
puts "=" * 80
