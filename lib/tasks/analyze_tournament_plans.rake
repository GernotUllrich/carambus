# frozen_string_literal: true

namespace :tournament_plans do
  desc "Analyze all tournament plans and their grouping algorithms"
  task analyze: :environment do
    puts "=" * 80
    puts "TOURNAMENT PLAN ANALYSIS"
    puts "Systematische Analyse aller NBV-Turnierpläne"
    puts "=" * 80
    puts ""
    
    # Gruppiere nach Spielerzahl
    plans_by_player_count = TournamentPlan.all.group_by(&:players).sort_by { |k, v| k }
    
    plans_by_player_count.each do |player_count, plans|
      puts ""
      puts "━" * 80
      puts "#{player_count} SPIELER"
      puts "━" * 80
      
      plans.each do |plan|
        analyze_plan(plan)
      end
    end
    
    puts ""
    puts "=" * 80
    puts "ANALYSE ABGESCHLOSSEN"
    puts "=" * 80
  end
  
  desc "Test grouping algorithm for a specific plan"
  task :test_grouping, [:plan_name] => :environment do |t, args|
    plan_name = args[:plan_name] || 'T21'
    plan = TournamentPlan.find_by(name: plan_name)
    
    unless plan
      puts "❌ Plan '#{plan_name}' nicht gefunden!"
      exit 1
    end
    
    puts "=" * 80
    puts "GROUPING ALGORITHM TEST: #{plan.name}"
    puts "=" * 80
    puts ""
    
    test_grouping_algorithm(plan)
  end
  
  private
  
  def analyze_plan(plan)
    puts ""
    puts "  📊 #{plan.name}"
    puts "  " + "─" * 76
    puts "     Spieler: #{plan.players}"
    puts "     Gruppen: #{plan.ngroups}"
    puts "     Beschreibung: #{plan.rulesystem}"
    
    # Berechne Gruppengröße
    if plan.ngroups > 0
      avg = plan.players.to_f / plan.ngroups
      min_size = avg.floor
      max_size = avg.ceil
      
      if min_size == max_size
        puts "     Gruppengröße: #{min_size} (gleichmäßig)"
      else
        # Berechne wie viele Gruppen welche Größe haben
        remainder = plan.players % plan.ngroups
        small_groups = plan.ngroups - remainder
        large_groups = remainder
        
        puts "     Gruppengröße: UNGLEICH"
        puts "       → #{small_groups} Gruppe(n) mit #{min_size} Spielern"
        puts "       → #{large_groups} Gruppe(n) mit #{max_size} Spielern"
      end
      
      # Zeige aktuelle Algorithmus-Berechnung
      puts ""
      puts "     Aktueller Algorithmus (Round-Robin/Zig-Zag):"
      test_players = (1..plan.players).to_a
      calculated_groups = TournamentMonitor.distribute_to_group(test_players, plan.ngroups)
      
      calculated_groups.each do |group_key, player_ids|
        group_no = group_key.gsub('group', '').to_i
        puts "       Gruppe #{group_no}: #{player_ids.inspect} (#{player_ids.count} Spieler)"
      end
      
      # Prüfe ob executor_params vorhanden
      if plan.executor_params.present?
        puts ""
        puts "     ✅ executor_params vorhanden"
        
        # Analysiere welche Gruppen-Referenzen verwendet werden
        params_str = plan.executor_params.to_s
        group_refs = params_str.scan(/g(\d+)s(\d+)/).uniq
        
        if group_refs.any?
          puts "     Gruppen-Referenzen in executor_params:"
          group_refs.group_by { |g, s| g }.each do |group_no, refs|
            max_seeding = refs.map { |g, s| s.to_i }.max
            puts "       g#{group_no}: bis zu #{max_seeding} Spieler referenziert"
          end
        end
      else
        puts ""
        puts "     ❌ KEINE executor_params!"
      end
    end
  end
  
  def test_grouping_algorithm(plan)
    puts "Plan: #{plan.name}"
    puts "Spieler: #{plan.players}, Gruppen: #{plan.ngroups}"
    puts ""
    
    # Teste mit Mock-Daten
    test_players = (1..plan.players).map { |i| OpenStruct.new(id: i * 100, fullname: "Spieler #{i}") }
    
    puts "Test-Spieler:"
    test_players.each { |p| puts "  #{p.id}: #{p.fullname}" }
    puts ""
    
    # Berechne Gruppen
    calculated = TournamentMonitor.distribute_to_group(test_players, plan.ngroups)
    
    puts "Berechnete Gruppenbildung:"
    calculated.each do |group_key, player_ids|
      group_no = group_key.gsub('group', '').to_i
      players_str = player_ids.map { |pid| test_players.find { |p| p.id == pid }&.fullname || "?" }.join(", ")
      puts "  Gruppe #{group_no} (#{player_ids.count} Spieler): #{players_str}"
    end
    
    puts ""
    puts "Position-Mapping:"
    calculated.each do |group_key, player_ids|
      group_no = group_key.gsub('group', '').to_i
      positions = player_ids.map { |pid| (pid / 100) }
      puts "  Gruppe #{group_no}: Positionen #{positions.inspect}"
    end
  end
end

