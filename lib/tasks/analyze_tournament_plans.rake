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
  
  desc "Auto-fix executor_params table conflicts"
  task :fix_executor_params, [:plan_names] => :environment do |t, args|
    plan_names = args[:plan_names]&.split(',') || []
    
    puts "=" * 80
    puts "AUTO-FIX EXECUTOR_PARAMS TABLE CONFLICTS"
    puts "Korrigiert automatisch Tisch-Mehrfachverwendung in Runden"
    puts "=" * 80
    puts ""
    
    if plan_names.empty?
      puts "❌ Bitte Plan-Namen angeben:"
      puts "   rake tournament_plans:fix_executor_params[T21,T23]"
      puts ""
      puts "Oder alle Plans mit Fehlern korrigieren:"
      puts "   rake tournament_plans:fix_executor_params[auto]"
      exit 1
    end
    
    if plan_names == ['auto']
      # Finde alle Plans mit Fehlern
      all_plans = TournamentPlan.all.order(:players, :name)
      plan_names = []
      all_plans.each do |plan|
        next unless plan.executor_params.present?
        errors = validate_executor_params_for_plan(plan, silent: true)
        plan_names << plan.name if errors.any?
      end
      puts "Auto-Modus: Gefundene Plans mit Fehlern: #{plan_names.join(', ')}"
      puts ""
    end
    
    fixed_count = 0
    plan_names.each do |plan_name|
      plan_name = plan_name.strip
      plan = TournamentPlan.find_by(name: plan_name)
      unless plan
        puts "❌ Plan '#{plan_name}' nicht gefunden!"
        next
      end
      
      unless plan.executor_params.present?
        puts "⚠️  Plan '#{plan_name}' hat keine executor_params"
        next
      end
      
      begin
        if fix_executor_params_for_plan(plan)
          fixed_count += 1
        end
      rescue StandardError => e
        puts "❌ Fehler beim Korrigieren von '#{plan_name}': #{e.message}"
        puts "   #{e.backtrace.first}"
        next
      end
    end
    
    puts ""
    puts "=" * 80
    puts "KORREKTUR ABGESCHLOSSEN"
    puts "=" * 80
    puts ""
    puts "✅ #{fixed_count} Plan(s) korrigiert"
    puts ""
    puts "💡 Prüfe jetzt mit: rake tournament_plans:validate_executor_params"
    puts ""
  end
  
  desc "Prueft alle Turnierplaene gegen ihre eigene Definition (JSON, rules-Form, Spielernummern, Rundenvollstaendigkeit, RK, Tischbelegung)"
  task validate: :environment do
    plans = TournamentPlan.order(:id)
    defect_plans = 0
    total_findings = 0

    plans.find_each do |plan|
      findings = TournamentPlanValidator.new(plan).findings
      next if findings.empty?

      defect_plans += 1
      total_findings += findings.size
      puts ""
      puts "#{plan.id}  #{plan.name} (#{plan.players} Spieler, #{plan.ngroups} Gruppen)"
      findings.each { |f| puts "    #{f}" }
    end

    puts ""
    puts "-" * 78
    puts "#{plans.count} Plaene geprueft, #{defect_plans} mit Befunden, #{total_findings} Befund(e) gesamt."
    puts ""

    if total_findings.positive?
      puts "Turnierplaene sind globale Records — Korrekturen gehoeren auf die Authority."
      puts ""
      # Exit-Code fuer CI, analog der UI-Wache in lib/tasks/ui.rake
      abort("Turnierplan-Validierung: #{total_findings} Befund(e) in #{defect_plans} Plan/Plaenen.")
    end

    puts "Keine Befunde."
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
  
  # Delegiert an TournamentPlanValidator (app/services/tournament_plan_validator.rb).
  # Die Pruef-Logik lag frueher hier; sie ist im Validator testbar und wird von der
  # umfassenderen Task `tournament_plans:validate` mitgenutzt. Diese Methode behaelt ihre
  # Signatur und Ausgabeform, weil `fix_executor_params` sie weiterhin ruft.
  # Rueckgabe wie bisher: Array von Fehler-Strings (nur Tisch-Konflikte und JSON-Fehler).
  def validate_executor_params_for_plan(plan, silent: false)
    findings = TournamentPlanValidator.new(plan).findings
      .select { |f| %i[table_conflicts json].include?(f.check) }
    # Beim JSON-Fehler traegt die Validator-Message den Anlass bereits ("kein gueltiges
    # JSON: ..."); ein zusaetzliches Praefix wuerde ihn doppeln.
    errors = findings.map { |f| (f.check == :json) ? f.message : "#{f.location}: #{f.message}" }

    if errors.any? && !silent
      puts ""
      puts "  ❌ #{plan.name} (#{plan.players} Spieler, #{plan.ngroups} Gruppen)"
      puts "     " + "─" * 76
      errors.each { |error| puts "     • #{error}" }
    end

    errors
  end

  def fix_executor_params_for_plan(plan)
    puts ""
    puts "  🔧 Korrigiere #{plan.name} (#{plan.players} Spieler, #{plan.ngroups} Gruppen)"
    puts "     " + "─" * 76
    
    begin
      executor_params = JSON.parse(plan.executor_params)
    rescue JSON::ParserError => e
      puts "     ❌ JSON Parse Error: #{e.message}"
      return false
    end
    
    # Sammle alle Tisch-Zuweisungen pro Runde (wie in validate)
    table_usage = {} # { "r1" => { "t1" => [{group: "g1", key: "g1"}], ... }, ... }
    
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
          table_usage[round_key][tno_str] << {group: "g#{group_no}", group_key: k, tno_str: tno_str}
        end
      end
    end
    
    # Finde Konflikte und korrigiere sie
    fixes_applied = []
    conflicts_found = []
    
    table_usage.each do |round_key, tables|
      tables.each do |tno_str, assignments|
        if assignments.length > 1
          conflicts_found << {round: round_key, table: tno_str, assignments: assignments}
        end
      end
    end
    
    if conflicts_found.empty?
      puts "     ✅ Keine Konflikte gefunden"
      return false
    end
    
    puts "     Gefundene Konflikte: #{conflicts_found.length}"
    
    # Bestimme maximale Anzahl Tische aus allen Runden
    max_tables = 0
    table_usage.each do |round_key, tables|
      tables.each do |tno_str, _|
        t_no = tno_str.match(/t(\d+)/)[1].to_i
        max_tables = [max_tables, t_no].max
      end
    end
    
    # Für jeden Konflikt: Finde freien Tisch
    conflicts_found.each do |conflict|
      round_key = conflict[:round]
      conflicting_table = conflict[:table]
      assignments = conflict[:assignments]
      
      # Finde alle bereits verwendeten Tische in dieser Runde (inkl. bereits korrigierte)
      used_tables = []
      table_usage[round_key].each do |tno_str, t_assignments|
        # Wenn Tisch nur einmal verwendet wird (kein Konflikt), ist er belegt
        if t_assignments.length == 1
          t_no = tno_str.match(/t(\d+)/)[1].to_i
          used_tables << t_no
        end
      end
      
      # Nimm alle Konflikte außer dem ersten (der behält seinen Tisch)
      assignments_to_fix = assignments[1..-1]
      
      assignments_to_fix.each do |assignment|
        # Finde ersten freien Tisch
        free_table = nil
        (1..max_tables + 10).each do |check_t_no|
          unless used_tables.include?(check_t_no)
            free_table = check_t_no
            used_tables << check_t_no
            break
          end
        end
        
        if free_table
          group_key = assignment[:group_key]
          old_tno_str = assignment[:tno_str]
          new_tno_str = "t#{free_table}"
          
          # Korrigiere in executor_params
          if executor_params[group_key]["sq"][round_key][old_tno_str]
            game_pair = executor_params[group_key]["sq"][round_key][old_tno_str]
            executor_params[group_key]["sq"][round_key][new_tno_str] = game_pair
            executor_params[group_key]["sq"][round_key].delete(old_tno_str)
            
            # Aktualisiere table_usage für nächste Iterationen
            table_usage[round_key][old_tno_str].delete(assignment)
            table_usage[round_key][new_tno_str] = [assignment]
            
            fixes_applied << "#{round_key}: #{assignment[:group]} #{old_tno_str} → #{new_tno_str}"
          end
        else
          puts "     ❌ Kein freier Tisch gefunden für #{round_key}: #{assignment[:group]}"
        end
      end
    end
    
    if fixes_applied.any?
      # Backup erstellen
      backup = plan.executor_params
      
      # Speichere korrigierte executor_params
      plan.executor_params = executor_params.to_json
      plan.save!
      
      puts "     ✅ Korrekturen angewendet:"
      fixes_applied.each do |fix|
        puts "        • #{fix}"
      end
      
      # Validiere nochmal
      remaining_errors = validate_executor_params_for_plan(plan, silent: true)
      if remaining_errors.empty?
        puts "     ✅ Validierung erfolgreich - keine weiteren Konflikte"
      else
        puts "     ⚠️  Validierung: #{remaining_errors.length} Konflikt(e) verbleiben"
        remaining_errors.each do |error|
          puts "        • #{error}"
        end
      end
      
      return true
    else
      puts "     ⚠️  Keine Korrekturen möglich"
      return false
    end
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

