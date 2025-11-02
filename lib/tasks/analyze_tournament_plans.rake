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
  
  desc "Validate executor_params consistency across all tournament plans"
  task validate_executor_params: :environment do
    puts "=" * 80
    puts "EXECUTOR_PARAMS CONSISTENCY VALIDATION"
    puts "Prüft alle TournamentPlans auf Tisch-Mehrfachverwendung in Runden"
    puts "=" * 80
    puts ""
    
    all_plans = TournamentPlan.all.order(:players, :name)
    total_errors = 0
    plans_with_errors = []
    plans_without_params = []
    plans_ok = []
    
    puts "Prüfe #{all_plans.count} TournamentPlan(s)..."
    puts ""
    
    all_plans.each do |plan|
      unless plan.executor_params.present?
        plans_without_params << plan
        next
      end
      
      errors = validate_executor_params_for_plan(plan)
      if errors.any?
        total_errors += errors.length
        plans_with_errors << plan
      else
        plans_ok << plan
      end
    end
    
    if plans_with_errors.any?
      puts ""
      puts "❌ FEHLER GEFUNDEN (#{plans_with_errors.length} Plan(s)):"
    end
    
    if plans_ok.any?
      puts ""
      puts "✅ OK (#{plans_ok.length} Plan(s)):"
      plans_ok.each do |plan|
        puts "   #{plan.name}"
      end
    end
    
    if plans_without_params.any?
      puts ""
      puts "⚠️  OHNE EXECUTOR_PARAMS (#{plans_without_params.length} Plan(s)):"
      plans_without_params.each do |plan|
        puts "   #{plan.name}"
      end
    end
    
    puts ""
    puts "=" * 80
    puts "VALIDIERUNG ABGESCHLOSSEN"
    puts "=" * 80
    puts ""
    
    if total_errors == 0
      puts "✅ Alle TournamentPlans sind konsistent!"
      puts "   Keine Tisch-Mehrfachverwendung gefunden."
    else
      puts "❌ #{total_errors} Inkonsistenz(en) gefunden in #{plans_with_errors.length} Plan(s):"
      plans_with_errors.each do |plan|
        puts "   - #{plan.name} (#{plan.players} Spieler)"
      end
      puts ""
      puts "💡 Diese Plans müssen korrigiert werden, bevor Turniere gestartet werden können."
    end
    puts ""
  end
  
  private
  
  def validate_executor_params_for_plan(plan)
    errors = []
    
    unless plan.executor_params.present?
      return errors # Keine executor_params = kein Problem
    end
    
    begin
      executor_params = JSON.parse(plan.executor_params)
    rescue JSON::ParserError => e
      puts "  ❌ #{plan.name}: JSON Parse Error: #{e.message}"
      return ["JSON Parse Error: #{e.message}"]
    end
    
    # Sammle alle Tisch-Zuweisungen pro Runde
    table_usage = {} # { "r1" => { "t1" => ["g1", "g2"], ... }, ... }
    
    executor_params.each_key do |k|
      next unless (m = k.match(/g(\d+)/))
      group_no = m[1].to_i
      sequence = executor_params[k]["sq"]
      next unless sequence.present? && sequence.is_a?(Hash)
      
      sequence.each do |round_key, round_data|
        next unless round_key.is_a?(String) && round_key.match?(/^r\d+/)
        next unless round_data.is_a?(Hash)
        
        table_usage[round_key] ||= {}
        round_data.each do |tno_str, game_pair|
          next unless tno_str.is_a?(String) && tno_str.match?(/^t\d+/)
          table_usage[round_key][tno_str] ||= []
          table_usage[round_key][tno_str] << "g#{group_no}"
        end
      end
    end
    
    # Prüfe auf mehrfache Verwendung
    table_usage.each do |round_key, tables|
      tables.each do |tno_str, groups|
        if groups.length > 1
          error_msg = "#{round_key}: #{tno_str} wird mehrfach verwendet (Gruppen: #{groups.join(', ')})"
          errors << error_msg
        end
      end
    end
    
    if errors.any?
      puts ""
      puts "  ❌ #{plan.name} (#{plan.players} Spieler, #{plan.ngroups} Gruppen)"
      puts "     " + "─" * 76
      errors.each do |error|
        puts "     • #{error}"
      end
    end
    
    errors
  end
  
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

