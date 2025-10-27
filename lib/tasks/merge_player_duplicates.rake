# frozen_string_literal: true

namespace :players do
  desc "Phase 2: Merge clean player duplicates (1 master, N duplicates with ba_id > 999000000)"
  task merge_clean_duplicates: :environment do
    puts "=" * 80
    puts "PHASE 2: MERGE CLEAN PLAYER DUPLICATES"
    puts "=" * 80
    puts ""
    puts "This will merge player duplicates where:"
    puts "  - 1 master record exists (with dbu_nr and ba_id < 999000000 or nil)"
    puts "  - 1+ duplicate records exist (with ba_id > 999000000)"
    puts ""
    puts "WARNING: This will permanently modify the database!"
    puts ""
    
    # Load analysis if available
    analysis_file = Rails.root.join('tmp', 'player_duplicates_analysis.json')
    unless File.exist?(analysis_file)
      puts "ERROR: Analysis file not found!"
      puts "Please run: rake players:analyze_duplicates first"
      exit 1
    end
    
    analysis = JSON.parse(File.read(analysis_file))
    mergeable_groups = analysis['mergeable_groups']
    
    puts "Found #{mergeable_groups.count} clean mergeable groups"
    puts ""
    
    # Safety check
    if Rails.env.production?
      puts "PRODUCTION MODE DETECTED!"
      print "Type 'YES' to continue: "
      response = STDIN.gets.chomp
      unless response == 'YES'
        puts "Aborted."
        exit 0
      end
    end
    
    # Perform merges
    merged_count = 0
    error_count = 0
    skipped_count = 0
    
    log_file = Rails.root.join('log', "player_merge_clean_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log")
    logger = Logger.new(log_file)
    
    puts "Starting merge process..."
    puts "Log file: #{log_file}"
    puts ""
    
    mergeable_groups.each_with_index do |group, idx|
      fl_name = group['fl_name']
      master_id = group['master_info']['id']
      duplicate_ids = group['duplicate_info'].map { |d| d['id'] }
      
      begin
        # Reload from database to ensure current state
        master = Player.find_by(id: master_id, type: nil)
        duplicates = Player.where(id: duplicate_ids, type: nil).to_a
        
        unless master.present?
          logger.warn "SKIPPED: #{fl_name} - Master record #{master_id} not found or has type"
          skipped_count += 1
          next
        end
        
        if duplicates.empty?
          logger.warn "SKIPPED: #{fl_name} - No duplicate records found"
          skipped_count += 1
          next
        end
        
        # Verify this is still a clean case
        unless master.dbu_nr.present? && (master.ba_id.nil? || master.ba_id < 999_000_000)
          logger.warn "SKIPPED: #{fl_name} - Master record no longer meets criteria"
          skipped_count += 1
          next
        end
        
        duplicates_with_wrong_ba_id = duplicates.select { |d| d.ba_id.nil? || d.ba_id < 999_000_000 }
        if duplicates_with_wrong_ba_id.any?
          logger.warn "SKIPPED: #{fl_name} - Some duplicates don't have ba_id > 999000000"
          skipped_count += 1
          next
        end
        
        # Log before state
        logger.info "=" * 80
        logger.info "MERGING: #{fl_name}"
        logger.info "  Master: ID=#{master.id}, BA_ID=#{master.ba_id}, DBU_NR=#{master.dbu_nr}, CC_ID=#{master.cc_id}"
        logger.info "  Duplicates (#{duplicates.count}):"
        duplicates.each do |dup|
          associations = {
            gp: dup.game_participations.count,
            sp: dup.season_participations.count,
            s: dup.seedings.count,
            pr: dup.player_rankings.count,
            pg: dup.party_a_games.count + dup.party_b_games.count
          }
          logger.info "    - ID=#{dup.id}, BA_ID=#{dup.ba_id}, CC_ID=#{dup.cc_id}, " \
                     "Assoc: GP=#{associations[:gp]}, SP=#{associations[:sp]}, S=#{associations[:s]}, " \
                     "PR=#{associations[:pr]}, PG=#{associations[:pg]}"
        end
        
        # Perform merge
        Player.merge_players(master, duplicates)
        
        logger.info "  ✓ MERGED successfully"
        logger.info ""
        
        merged_count += 1
        
        # Progress output
        if (idx + 1) % 10 == 0
          puts "Processed #{idx + 1}/#{mergeable_groups.count} groups (#{merged_count} merged, " \
               "#{skipped_count} skipped, #{error_count} errors)"
        end
        
      rescue StandardError => e
        logger.error "ERROR merging #{fl_name}: #{e.message}"
        logger.error e.backtrace.join("\n")
        error_count += 1
      end
    end
    
    puts ""
    puts "=" * 80
    puts "MERGE COMPLETE"
    puts "=" * 80
    puts "  Successfully merged: #{merged_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts ""
    puts "Log file: #{log_file}"
    puts ""
    
    # Re-run analysis to see new state
    puts "Tip: Run 'rake players:analyze_duplicates' to see updated duplicate count"
  end
  
  desc "Phase 3: Merge player duplicates with multiple master candidates"
  task merge_multiple_masters: :environment do
    puts "=" * 80
    puts "PHASE 3: MERGE DUPLICATES WITH MULTIPLE MASTER CANDIDATES"
    puts "=" * 80
    puts ""
    
    # Load analysis
    analysis_file = Rails.root.join('tmp', 'player_duplicates_analysis.json')
    unless File.exist?(analysis_file)
      puts "ERROR: Analysis file not found!"
      puts "Please run: rake players:analyze_duplicates first"
      exit 1
    end
    
    analysis = JSON.parse(File.read(analysis_file))
    problematic_groups = analysis['problematic_groups'].select { |g| g['issue'] == 'Multiple master candidates' }
    
    puts "Found #{problematic_groups.count} groups with multiple master candidates"
    puts ""
    puts "Strategy:"
    puts "  1. Select master with most associations"
    puts "  2. If tied, select master with lowest ID (oldest)"
    puts "  3. Merge other masters into selected master"
    puts ""
    
    # Safety check
    if Rails.env.production?
      puts "PRODUCTION MODE DETECTED!"
      print "Type 'YES' to continue: "
      response = STDIN.gets.chomp
      unless response == 'YES'
        puts "Aborted."
        exit 0
      end
    end
    
    merged_count = 0
    error_count = 0
    skipped_count = 0
    
    log_file = Rails.root.join('log', "player_merge_multiple_masters_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log")
    logger = Logger.new(log_file)
    
    puts "Starting merge process..."
    puts "Log file: #{log_file}"
    puts ""
    
    problematic_groups.each_with_index do |group, idx|
      fl_name = group['fl_name']
      master_ids = group['masters'].map { |m| m['id'] }
      duplicate_ids = (group['duplicates'] || []).map { |d| d['id'] }
      
      begin
        # Reload from database
        masters = Player.where(id: master_ids, type: nil).to_a
        duplicates = Player.where(id: duplicate_ids, type: nil).to_a
        
        if masters.count < 2
          logger.warn "SKIPPED: #{fl_name} - Less than 2 master candidates found"
          skipped_count += 1
          next
        end
        
        # Calculate associations for each master
        master_scores = masters.map do |m|
          score = m.game_participations.count * 10 +
                  m.season_participations.count * 5 +
                  m.seedings.count * 3 +
                  m.player_rankings.count * 2 +
                  (m.party_a_games.count + m.party_b_games.count) * 1
          { master: m, score: score }
        end
        
        # Sort by score (desc), then by ID (asc)
        master_scores.sort_by! { |ms| [-ms[:score], ms[:master].id] }
        
        selected_master = master_scores.first[:master]
        other_masters = master_scores[1..-1].map { |ms| ms[:master] }
        
        # Log
        logger.info "=" * 80
        logger.info "MERGING: #{fl_name}"
        logger.info "  Selected Master: ID=#{selected_master.id}, BA_ID=#{selected_master.ba_id}, " \
                   "DBU_NR=#{selected_master.dbu_nr}, Score=#{master_scores.first[:score]}"
        logger.info "  Other Masters to merge (#{other_masters.count}):"
        other_masters.each_with_index do |m, i|
          logger.info "    - ID=#{m.id}, BA_ID=#{m.ba_id}, DBU_NR=#{m.dbu_nr}, " \
                     "Score=#{master_scores[i + 1][:score]}"
        end
        if duplicates.any?
          logger.info "  Also merging #{duplicates.count} duplicate(s) with ba_id > 999000000"
        end
        
        # Merge other masters and duplicates into selected master
        all_to_merge = other_masters + duplicates
        Player.merge_players(selected_master, all_to_merge)
        
        logger.info "  ✓ MERGED successfully"
        logger.info ""
        
        merged_count += 1
        
        if (idx + 1) % 10 == 0
          puts "Processed #{idx + 1}/#{problematic_groups.count} groups (#{merged_count} merged, " \
               "#{skipped_count} skipped, #{error_count} errors)"
        end
        
      rescue StandardError => e
        logger.error "ERROR merging #{fl_name}: #{e.message}"
        logger.error e.backtrace.join("\n")
        error_count += 1
      end
    end
    
    puts ""
    puts "=" * 80
    puts "MERGE COMPLETE"
    puts "=" * 80
    puts "  Successfully merged: #{merged_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts ""
    puts "Log file: #{log_file}"
    puts ""
    puts "Tip: Run 'rake players:analyze_duplicates' to see updated duplicate count"
  end
  
  desc "Phase 4: Merge player duplicates without master candidate"
  task merge_without_master: :environment do
    puts "=" * 80
    puts "PHASE 4: MERGE DUPLICATES WITHOUT MASTER CANDIDATE"
    puts "=" * 80
    puts ""
    
    # Load analysis
    analysis_file = Rails.root.join('tmp', 'player_duplicates_analysis.json')
    unless File.exist?(analysis_file)
      puts "ERROR: Analysis file not found!"
      puts "Please run: rake players:analyze_duplicates first"
      exit 1
    end
    
    analysis = JSON.parse(File.read(analysis_file))
    problematic_groups = analysis['problematic_groups'].select { |g| g['issue'] == 'No master candidate found' }
    
    puts "Found #{problematic_groups.count} groups without master candidate"
    puts ""
    puts "Strategy:"
    puts "  1. Select player with dbu_nr (if any) as master"
    puts "  2. Else: Select player with most associations"
    puts "  3. Else: Select player with lowest ba_id (if < 999000000)"
    puts "  4. Else: Select player with lowest ID (oldest)"
    puts "  5. Designate as master and merge others"
    puts ""
    
    # Safety check
    if Rails.env.production?
      puts "PRODUCTION MODE DETECTED!"
      print "Type 'YES' to continue: "
      response = STDIN.gets.chomp
      unless response == 'YES'
        puts "Aborted."
        exit 0
      end
    end
    
    merged_count = 0
    error_count = 0
    skipped_count = 0
    
    log_file = Rails.root.join('log', "player_merge_without_master_#{Time.now.strftime('%Y%m%d_%H%M%S')}.log")
    logger = Logger.new(log_file)
    
    puts "Starting merge process..."
    puts "Log file: #{log_file}"
    puts ""
    
    problematic_groups.each_with_index do |group, idx|
      fl_name = group['fl_name']
      all_player_ids = group['all_players'].map { |p| p['id'] }
      
      begin
        # Reload from database
        players = Player.where(id: all_player_ids, type: nil).to_a
        
        if players.count < 2
          logger.warn "SKIPPED: #{fl_name} - Less than 2 players found"
          skipped_count += 1
          next
        end
        
        # Strategy 1: Player with dbu_nr
        master = players.find { |p| p.dbu_nr.present? && p.dbu_nr > 0 }
        strategy = "dbu_nr present"
        
        # Strategy 2: Most associations
        unless master
          player_scores = players.map do |p|
            score = p.game_participations.count * 10 +
                    p.season_participations.count * 5 +
                    p.seedings.count * 3 +
                    p.player_rankings.count * 2 +
                    (p.party_a_games.count + p.party_b_games.count) * 1
            { player: p, score: score }
          end
          player_scores.sort_by! { |ps| -ps[:score] }
          
          if player_scores.first[:score] > 0
            master = player_scores.first[:player]
            strategy = "most associations (score=#{player_scores.first[:score]})"
          end
        end
        
        # Strategy 3: Lowest ba_id < 999000000
        unless master
          candidates = players.select { |p| p.ba_id.present? && p.ba_id < 999_000_000 }
          if candidates.any?
            master = candidates.min_by(&:ba_id)
            strategy = "lowest ba_id < 999000000 (#{master.ba_id})"
          end
        end
        
        # Strategy 4: Lowest ID
        unless master
          master = players.min_by(&:id)
          strategy = "lowest ID (oldest)"
        end
        
        others = players - [master]
        
        # Log
        logger.info "=" * 80
        logger.info "MERGING: #{fl_name}"
        logger.info "  Selected Master (#{strategy}): ID=#{master.id}, BA_ID=#{master.ba_id}, " \
                   "DBU_NR=#{master.dbu_nr}, CC_ID=#{master.cc_id}"
        logger.info "  Players to merge (#{others.count}):"
        others.each do |p|
          logger.info "    - ID=#{p.id}, BA_ID=#{p.ba_id}, DBU_NR=#{p.dbu_nr}, CC_ID=#{p.cc_id}"
        end
        
        # Merge
        Player.merge_players(master, others)
        
        logger.info "  ✓ MERGED successfully"
        logger.info ""
        
        merged_count += 1
        
        if (idx + 1) % 10 == 0
          puts "Processed #{idx + 1}/#{problematic_groups.count} groups (#{merged_count} merged, " \
               "#{skipped_count} skipped, #{error_count} errors)"
        end
        
      rescue StandardError => e
        logger.error "ERROR merging #{fl_name}: #{e.message}"
        logger.error e.backtrace.join("\n")
        error_count += 1
      end
    end
    
    puts ""
    puts "=" * 80
    puts "MERGE COMPLETE"
    puts "=" * 80
    puts "  Successfully merged: #{merged_count}"
    puts "  Skipped: #{skipped_count}"
    puts "  Errors: #{error_count}"
    puts ""
    puts "Log file: #{log_file}"
    puts ""
    puts "Tip: Run 'rake players:analyze_duplicates' to see updated duplicate count"
  end
  
  desc "Verify player merges - check for orphaned associations and broken references"
  task verify_merges: :environment do
    puts "=" * 80
    puts "VERIFY PLAYER MERGES"
    puts "=" * 80
    puts ""
    
    errors = []
    
    # Check for orphaned GameParticipations
    puts "Checking GameParticipations..."
    orphaned_gp = GameParticipation.where.not(player_id: nil)
                                   .where.not(player_id: Player.where(type: nil).select(:id))
    if orphaned_gp.any?
      errors << "Found #{orphaned_gp.count} orphaned GameParticipations"
      puts "  ❌ #{orphaned_gp.count} orphaned records"
    else
      puts "  ✓ OK"
    end
    
    # Check for orphaned SeasonParticipations
    puts "Checking SeasonParticipations..."
    orphaned_sp = SeasonParticipation.where.not(player_id: Player.where(type: nil).select(:id))
    if orphaned_sp.any?
      errors << "Found #{orphaned_sp.count} orphaned SeasonParticipations"
      puts "  ❌ #{orphaned_sp.count} orphaned records"
    else
      puts "  ✓ OK"
    end
    
    # Check for orphaned Seedings
    puts "Checking Seedings..."
    orphaned_s = Seeding.where.not(player_id: nil)
                        .where.not(player_id: Player.where(type: nil).select(:id))
    if orphaned_s.any?
      errors << "Found #{orphaned_s.count} orphaned Seedings"
      puts "  ❌ #{orphaned_s.count} orphaned records"
    else
      puts "  ✓ OK"
    end
    
    # Check for orphaned PlayerRankings
    puts "Checking PlayerRankings..."
    orphaned_pr = PlayerRanking.where.not(player_id: Player.where(type: nil).select(:id))
    if orphaned_pr.any?
      errors << "Found #{orphaned_pr.count} orphaned PlayerRankings"
      puts "  ❌ #{orphaned_pr.count} orphaned records"
    else
      puts "  ✓ OK"
    end
    
    # Check for orphaned PartyGames
    puts "Checking PartyGames..."
    orphaned_pg_a = PartyGame.where.not(player_a_id: nil)
                             .where.not(player_a_id: Player.where(type: nil).select(:id))
    orphaned_pg_b = PartyGame.where.not(player_b_id: nil)
                             .where.not(player_b_id: Player.where(type: nil).select(:id))
    if orphaned_pg_a.any? || orphaned_pg_b.any?
      errors << "Found #{orphaned_pg_a.count} orphaned PartyGames (player_a)"
      errors << "Found #{orphaned_pg_b.count} orphaned PartyGames (player_b)"
      puts "  ❌ #{orphaned_pg_a.count} orphaned player_a_id"
      puts "  ❌ #{orphaned_pg_b.count} orphaned player_b_id"
    else
      puts "  ✓ OK"
    end
    
    # Check for duplicate fl_names that shouldn't exist
    puts "Checking for remaining duplicates..."
    duplicate_count = Player.where(type: nil)
                           .group(:fl_name)
                           .having('count(*) > 1')
                           .count
                           .count
    if duplicate_count > 0
      puts "  ⚠️  Still #{duplicate_count} fl_names with duplicates"
    else
      puts "  ✓ No duplicates found"
    end
    
    puts ""
    puts "=" * 80
    if errors.any?
      puts "VERIFICATION FAILED"
      puts "=" * 80
      errors.each { |e| puts "  ❌ #{e}" }
    else
      puts "VERIFICATION SUCCESSFUL"
      puts "=" * 80
      puts "  ✓ No orphaned associations found"
      puts "  ✓ All references are valid"
    end
    puts ""
  end
end

