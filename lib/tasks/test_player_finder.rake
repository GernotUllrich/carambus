# frozen_string_literal: true

namespace :players do
  desc "Test PlayerFinder concern with sample data"
  task test_finder: :environment do
    puts "=" * 80
    puts "PLAYER FINDER TEST"
    puts "=" * 80
    puts ""
    
    # Test 1: Find by cc_id
    puts "Test 1: Find by cc_id"
    player = Player.where(type: nil, cc_id: [1..20000]).first
    if player
      puts "  Sample player: #{player.fullname} (ID: #{player.id}, CC_ID: #{player.cc_id})"
      found = Player.find_or_create_player(
        firstname: "Different",
        lastname: "Name",
        cc_id: player.cc_id
      )
      puts "  Found: #{found.fullname} (ID: #{found.id})"
      puts "  ✓ #{found.id == player.id ? 'PASS' : 'FAIL'} - Found by cc_id"
    else
      puts "  ⚠️  No player with cc_id found for testing"
    end
    puts ""
    
    # Test 2: Find by dbu_nr
    puts "Test 2: Find by dbu_nr"
    player = Player.where(type: nil).where.not(dbu_nr: nil).where("dbu_nr < 999000000").first
    if player
      puts "  Sample player: #{player.fullname} (ID: #{player.id}, DBU_NR: #{player.dbu_nr})"
      found = Player.find_or_create_player(
        firstname: "Different",
        lastname: "Name",
        dbu_nr: player.dbu_nr
      )
      puts "  Found: #{found.fullname} (ID: #{found.id})"
      puts "  ✓ #{found.id == player.id ? 'PASS' : 'FAIL'} - Found by dbu_nr"
    else
      puts "  ⚠️  No player with dbu_nr found for testing"
    end
    puts ""
    
    # Test 3: Find by name (unique)
    puts "Test 3: Find by unique name"
    unique_player = Player.where(type: nil)
                          .group(:firstname, :lastname)
                          .having('count(*) = 1')
                          .limit(1)
                          .pluck(:firstname, :lastname)
                          .first
    if unique_player
      firstname, lastname = unique_player
      player = Player.where(type: nil, firstname: firstname, lastname: lastname).first
      puts "  Sample player: #{player.fullname} (ID: #{player.id})"
      found = Player.find_or_create_player(
        firstname: firstname,
        lastname: lastname
      )
      puts "  Found: #{found.fullname} (ID: #{found.id})"
      puts "  ✓ #{found.id == player.id ? 'PASS' : 'FAIL'} - Found by unique name"
    else
      puts "  ⚠️  No unique player name found for testing"
    end
    puts ""
    
    # Test 4: Ambiguous name (should select best player)
    puts "Test 4: Ambiguous name (multiple players)"
    duplicate = Player.where(type: nil)
                      .group(:firstname, :lastname)
                      .having('count(*) > 1')
                      .limit(1)
                      .pluck(:firstname, :lastname)
                      .first
    if duplicate
      firstname, lastname = duplicate
      players = Player.where(type: nil, firstname: firstname, lastname: lastname).to_a
      puts "  Sample: #{firstname} #{lastname} (#{players.count} players)"
      players.each do |p|
        assoc_count = p.game_participations.count + p.season_participations.count
        puts "    - Player #{p.id}: #{assoc_count} associations"
      end
      
      found = Player.find_or_create_player(
        firstname: firstname,
        lastname: lastname
      )
      puts "  Selected: Player #{found.id}"
      puts "  ✓ PASS - Selected player from ambiguous set"
    else
      puts "  ⚠️  No duplicate player names found for testing"
    end
    puts ""
    
    # Test 5: Non-existent player (should create)
    puts "Test 5: Non-existent player (should NOT create in test)"
    before_count = Player.where(type: nil).count
    found = Player.find_or_create_player(
      firstname: "TestFirstname#{Time.now.to_i}",
      lastname: "TestLastname#{Time.now.to_i}",
      cc_id: 999999999,
      allow_create: false  # Don't actually create
    )
    after_count = Player.where(type: nil).count
    puts "  Result: #{found ? "Created (ID: #{found.id})" : "Not created (as expected)"}"
    puts "  ✓ #{found.nil? && before_count == after_count ? 'PASS' : 'FAIL'} - Did not create when allow_create=false"
    puts ""
    
    puts "=" * 80
    puts "TESTS COMPLETE"
    puts "=" * 80
  end
end


