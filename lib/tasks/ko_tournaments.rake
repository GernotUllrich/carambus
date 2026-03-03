# frozen_string_literal: true

namespace :test do
  desc "Run KO tournament tests"
  task ko_tournaments: :environment do
    puts "\n" + "=" * 80
    puts "  KO TOURNAMENT REGRESSION TESTS"
    puts "=" * 80 + "\n"
    
    # Run specific test files
    test_files = [
      "test/models/tournament_plan_ko_test.rb",
      "test/models/tournament_ko_integration_test.rb",
      "test/models/tournament_monitor_ko_test.rb"
    ]
    
    test_files.each do |file|
      if File.exist?(Rails.root.join(file))
        puts "\n▶ Running #{file}..."
        system("ruby -I test #{Rails.root.join(file)}")
      else
        puts "⚠ Warning: #{file} not found"
      end
    end
    
    puts "\n" + "=" * 80
    puts "  TESTS COMPLETE"
    puts "=" * 80 + "\n"
  end

  desc "Run KO tournament tests with coverage"
  task :ko_tournaments_coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test:ko_tournaments'].invoke
  end
end

namespace :ko do
  desc "Generate a KO tournament plan for N players"
  task :generate_plan, [:nplayers] => :environment do |_t, args|
    nplayers = args[:nplayers].to_i
    
    if nplayers < 2 || nplayers > 64
      puts "Error: Number of players must be between 2 and 64"
      exit 1
    end
    
    puts "Generating KO tournament plan for #{nplayers} players..."
    plan = TournamentPlan.ko_plan(nplayers)
    
    if plan.save
      puts "✓ Plan created: #{plan.name}"
      puts "  ID: #{plan.id}"
      puts "  Total games: #{JSON.parse(plan.executor_params)['GK']}"
      puts "  Groups: #{plan.ngroups}"
      puts "  Tables: #{plan.tables}"
    else
      puts "✗ Failed to create plan"
      puts plan.errors.full_messages
    end
  end

  desc "Inspect KO tournament structure"
  task :inspect, [:tournament_id] => :environment do |_t, args|
    tournament_id = args[:tournament_id].to_i
    tournament = Tournament.find(tournament_id)
    
    puts "\n" + "=" * 80
    puts "  KO TOURNAMENT INSPECTION"
    puts "=" * 80
    puts "\nTournament: #{tournament.title} [#{tournament.id}]"
    puts "State: #{tournament.state}"
    puts "Date: #{tournament.date}"
    puts "Seedings: #{tournament.seedings.count}"
    
    if tournament.tournament_plan
      puts "\nTournament Plan: #{tournament.tournament_plan.name}"
      params = JSON.parse(tournament.tournament_plan.executor_params)
      puts "  Expected Games: #{params['GK']}"
      puts "  Actual Games: #{tournament.games.count}"
      
      # Group games by round
      games_by_prefix = tournament.games.group_by { |g| g.gname.match(/^[a-z0-9]+/)[0] }
      games_by_prefix.each do |prefix, games|
        puts "\n  #{prefix} (#{games.count} games):"
        games.sort_by(&:gname).each do |game|
          player_names = game.game_participations.includes(:player).map do |gp|
            gp.player&.display_name || "TBD"
          end
          puts "    #{game.gname}: #{player_names.join(' vs ')}"
        end
      end
    else
      puts "\n⚠ No tournament plan assigned!"
    end
    
    if tournament.tournament_monitor
      puts "\nTournament Monitor:"
      puts "  State: #{tournament.tournament_monitor.state}"
      puts "  Current Round: #{tournament.tournament_monitor.current_round}"
    else
      puts "\n⚠ No tournament monitor initialized!"
    end
    
    puts "\n" + "=" * 80 + "\n"
  end

  desc "Test KO tournament with your Tournament[17405]"
  task :test_tournament_17405 => :environment do
    tournament = Tournament.find(17405)
    
    puts "\n" + "=" * 80
    puts "  TESTING TOURNAMENT[17405]"
    puts "=" * 80
    puts "\nTournament: #{tournament.title}"
    puts "Seedings: #{tournament.seedings.count}"
    puts "Current State: #{tournament.state}"
    
    # Check tournament plan
    if tournament.tournament_plan.nil?
      puts "\n⚠ No tournament plan assigned!"
      puts "Creating KO_#{tournament.seedings.count} plan..."
      
      plan = TournamentPlan.ko_plan(tournament.seedings.count)
      plan.save!
      tournament.update!(tournament_plan: plan)
      puts "✓ Plan assigned: #{plan.name}"
    else
      puts "\nTournament Plan: #{tournament.tournament_plan.name}"
    end
    
    # Initialize if needed
    unless tournament.tournament_monitor
      puts "\nInitializing tournament monitor..."
      tournament.initialize_tournament_monitor
      puts "✓ Tournament monitor created"
    end
    
    # Run reset
    puts "\nResetting tournament monitor..."
    tm = tournament.tournament_monitor
    tm.do_reset_tournament_monitor
    
    puts "\nGames created: #{tournament.games.count}"
    
    # Show first round
    first_round_prefix = if tournament.seedings.count == 24
                          "32f"
                        elsif tournament.seedings.count == 16
                          "16f"
                        elsif tournament.seedings.count == 32
                          "16f"
                        else
                          "qf"
                        end
    
    first_games = tournament.games.where("gname LIKE '#{first_round_prefix}%'").order(:gname).limit(5)
    puts "\nFirst 5 games (#{first_round_prefix}):"
    first_games.each do |game|
      players = game.game_participations.includes(:player).map do |gp|
        gp.player&.display_name || "TBD"
      end
      puts "  #{game.gname}: #{players.join(' vs ')}"
    end
    
    puts "\n" + "=" * 80 + "\n"
  end
end
