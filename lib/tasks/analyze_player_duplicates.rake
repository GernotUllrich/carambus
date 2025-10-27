# frozen_string_literal: true

namespace :players do
  desc "Analyze player duplicates in detail"
  task analyze_duplicates: :environment do
    puts "=" * 80
    puts "PLAYER DUPLICATES ANALYSIS"
    puts "=" * 80
    puts ""
    
    # 1. Find all duplicates by fl_name where type is nil
    duplicate_fl_names = Player.where(type: nil)
                               .group(:fl_name)
                               .having('count(*) > 1')
                               .count
                               
    puts "Total unique fl_names with duplicates: #{duplicate_fl_names.count}"
    puts "Total duplicate records: #{duplicate_fl_names.values.sum}"
    puts ""
    
    # 2. Analyze duplicates in detail
    master_records = []
    duplicate_records = []
    mergeable_groups = []
    problematic_groups = []
    
    duplicate_fl_names.keys.each do |fl_name|
      players = Player.where(type: nil, fl_name: fl_name).to_a
      
      # Find master candidates (with dbu_nr and ba_id < 999000000)
      masters = players.select do |p|
        p.dbu_nr.present? && 
        (p.ba_id.nil? || p.ba_id < 999_000_000)
      end
      
      # Find duplicates (with ba_id > 999000000)
      dups = players.select do |p|
        p.ba_id.present? && p.ba_id > 999_000_000
      end
      
      # Categorize
      if masters.count == 1 && dups.count > 0
        # Clean case: one master, multiple duplicates
        master = masters.first
        mergeable_groups << {
          fl_name: fl_name,
          master: master,
          duplicates: dups,
          master_info: {
            id: master.id,
            ba_id: master.ba_id,
            dbu_nr: master.dbu_nr,
            cc_id: master.cc_id,
            clubs: master.season_participations.map { |sp| sp.club&.shortname }.uniq.compact
          },
          duplicate_info: dups.map do |d|
            {
              id: d.id,
              ba_id: d.ba_id,
              dbu_nr: d.dbu_nr,
              cc_id: d.cc_id,
              clubs: d.season_participations.map { |sp| sp.club&.shortname }.uniq.compact,
              associations: {
                game_participations: d.game_participations.count,
                season_participations: d.season_participations.count,
                seedings: d.seedings.count,
                player_rankings: d.player_rankings.count,
                party_a_games: d.party_a_games.count,
                party_b_games: d.party_b_games.count
              }
            }
          end
        }
        master_records << master
        duplicate_records.concat(dups)
      elsif masters.count > 1
        # Problematic: multiple masters
        problematic_groups << {
          fl_name: fl_name,
          issue: "Multiple master candidates",
          masters: masters.map do |m|
            {
              id: m.id,
              ba_id: m.ba_id,
              dbu_nr: m.dbu_nr,
              cc_id: m.cc_id,
              clubs: m.season_participations.map { |sp| sp.club&.shortname }.uniq.compact
            }
          end,
          duplicates: dups.map do |d|
            {
              id: d.id,
              ba_id: d.ba_id,
              dbu_nr: d.dbu_nr,
              cc_id: d.cc_id,
              clubs: d.season_participations.map { |sp| sp.club&.shortname }.uniq.compact
            }
          end
        }
      elsif masters.count == 0 && dups.count > 0
        # Problematic: no master found
        problematic_groups << {
          fl_name: fl_name,
          issue: "No master candidate found",
          all_players: players.map do |p|
            {
              id: p.id,
              ba_id: p.ba_id,
              dbu_nr: p.dbu_nr,
              cc_id: p.cc_id,
              clubs: p.season_participations.map { |sp| sp.club&.shortname }.uniq.compact
            }
          end
        }
      else
        # Other cases
        problematic_groups << {
          fl_name: fl_name,
          issue: "Other case",
          all_players: players.map do |p|
            {
              id: p.id,
              ba_id: p.ba_id,
              dbu_nr: p.dbu_nr,
              cc_id: p.cc_id,
              clubs: p.season_participations.map { |sp| sp.club&.shortname }.uniq.compact
            }
          end
        }
      end
    end
    
    puts "=" * 80
    puts "SUMMARY"
    puts "=" * 80
    puts ""
    puts "Clean mergeable groups (1 master, N duplicates): #{mergeable_groups.count}"
    puts "  Total master records: #{master_records.uniq.count}"
    puts "  Total duplicate records: #{duplicate_records.uniq.count}"
    puts ""
    puts "Problematic groups: #{problematic_groups.count}"
    puts ""
    
    # Association statistics for duplicates
    if duplicate_records.any?
      total_game_participations = duplicate_records.sum { |d| d.game_participations.count }
      total_season_participations = duplicate_records.sum { |d| d.season_participations.count }
      total_seedings = duplicate_records.sum { |d| d.seedings.count }
      total_player_rankings = duplicate_records.sum { |d| d.player_rankings.count }
      total_party_games = duplicate_records.sum { |d| d.party_a_games.count + d.party_b_games.count }
      
      puts "Associations attached to duplicate records:"
      puts "  Game participations: #{total_game_participations}"
      puts "  Season participations: #{total_season_participations}"
      puts "  Seedings: #{total_seedings}"
      puts "  Player rankings: #{total_player_rankings}"
      puts "  Party games: #{total_party_games}"
      puts ""
    end
    
    # Save detailed report
    report_file = Rails.root.join('tmp', 'player_duplicates_analysis.json')
    File.write(report_file, JSON.pretty_generate({
      summary: {
        total_duplicate_fl_names: duplicate_fl_names.count,
        total_duplicate_records: duplicate_fl_names.values.sum,
        mergeable_groups: mergeable_groups.count,
        problematic_groups: problematic_groups.count
      },
      mergeable_groups: mergeable_groups,
      problematic_groups: problematic_groups
    }))
    
    puts "Detailed report saved to: #{report_file}"
    puts ""
    
    # Show sample mergeable groups
    if mergeable_groups.any?
      puts "=" * 80
      puts "SAMPLE MERGEABLE GROUPS (first 5)"
      puts "=" * 80
      puts ""
      mergeable_groups.first(5).each_with_index do |group, idx|
        puts "#{idx + 1}. #{group[:fl_name]}"
        puts "   Master: ID=#{group[:master_info][:id]}, BA_ID=#{group[:master_info][:ba_id]}, " \
             "DBU_NR=#{group[:master_info][:dbu_nr]}, CC_ID=#{group[:master_info][:cc_id]}"
        puts "   Clubs: #{group[:master_info][:clubs].join(', ')}"
        puts "   Duplicates (#{group[:duplicates].count}):"
        group[:duplicate_info].each do |dup|
          puts "     - ID=#{dup[:id]}, BA_ID=#{dup[:ba_id]}, CC_ID=#{dup[:cc_id]}"
          puts "       Clubs: #{dup[:clubs].join(', ')}"
          puts "       Associations: GP=#{dup[:associations][:game_participations]}, " \
               "SP=#{dup[:associations][:season_participations]}, " \
               "S=#{dup[:associations][:seedings]}, " \
               "PR=#{dup[:associations][:player_rankings]}, " \
               "PG=#{dup[:associations][:party_a_games] + dup[:associations][:party_b_games]}"
        end
        puts ""
      end
    end
    
    # Show sample problematic groups
    if problematic_groups.any?
      puts "=" * 80
      puts "SAMPLE PROBLEMATIC GROUPS (first 5)"
      puts "=" * 80
      puts ""
      problematic_groups.first(5).each_with_index do |group, idx|
        puts "#{idx + 1}. #{group[:fl_name]}"
        puts "   Issue: #{group[:issue]}"
        if group[:masters]
          puts "   Masters (#{group[:masters].count}):"
          group[:masters].each do |m|
            puts "     - ID=#{m[:id]}, BA_ID=#{m[:ba_id]}, DBU_NR=#{m[:dbu_nr]}, CC_ID=#{m[:cc_id]}"
            puts "       Clubs: #{m[:clubs].join(', ')}"
          end
        end
        if group[:duplicates]
          puts "   Duplicates (#{group[:duplicates].count}):"
          group[:duplicates].each do |d|
            puts "     - ID=#{d[:id]}, BA_ID=#{d[:ba_id]}, DBU_NR=#{d[:dbu_nr]}, CC_ID=#{d[:cc_id]}"
            puts "       Clubs: #{d[:clubs].join(', ')}"
          end
        end
        if group[:all_players]
          puts "   All players (#{group[:all_players].count}):"
          group[:all_players].each do |p|
            puts "     - ID=#{p[:id]}, BA_ID=#{p[:ba_id]}, DBU_NR=#{p[:dbu_nr]}, CC_ID=#{p[:cc_id]}"
            puts "       Clubs: #{p[:clubs].join(', ')}"
          end
        end
        puts ""
      end
    end
    
    puts "=" * 80
    puts "Analysis complete!"
    puts "=" * 80
  end
end

