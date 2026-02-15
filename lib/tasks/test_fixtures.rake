# frozen_string_literal: true

namespace :test do
  desc "Collect ClubCloud HTML fixtures for testing (interactive)"
  task collect_fixtures: :environment do
    require 'fileutils'
    require 'colorize'

    html_dir = Rails.root.join('test', 'fixtures', 'html')
    FileUtils.mkdir_p(html_dir)

    puts
    puts "🎯 " + "ClubCloud Fixture Sammler".bold
    puts "=" * 60
    puts

    # Get parameters
    region_shortname = ENV['REGION'] || 'NBV'
    season_name = ENV['SEASON'] || Season.current_season&.name || '2025/2026'
    fixture_type = ENV['TYPE'] # tournaments, leagues, clubs, all

    region = Region.find_by_shortname(region_shortname)
    season = Season.find_by_name(season_name)

    unless region
      puts "❌ Region '#{region_shortname}' nicht gefunden!".red
      puts "   Verfügbare Regions: #{Region.pluck(:shortname).join(', ')}"
      exit 1
    end

    unless season
      puts "❌ Season '#{season_name}' nicht gefunden!".red
      puts "   Verfügbare Seasons: #{Season.pluck(:name).join(', ')}"
      exit 1
    end

    puts "📌 Region: #{region.name} (#{region.shortname})"
    puts "📌 Season: #{season.name}"
    puts "📁 Output: #{html_dir.relative_path_from(Rails.root)}"
    puts

    # Determine which fixtures to collect
    collect_tournaments = fixture_type.nil? || fixture_type == 'tournaments' || fixture_type == 'all'
    collect_leagues = fixture_type == 'leagues' || fixture_type == 'all'
    collect_clubs = fixture_type == 'clubs' || fixture_type == 'all'

    fixtures_collected = []

    # === 1. TOURNAMENTS ===
    if collect_tournaments
      puts "🏆 " + "Tournament Fixtures sammeln...".bold
      puts "-" * 60

      # Get region's cc_id (needed for URLs)
      region_cc = region.region_cc
      unless region_cc
        puts "⚠️  Region hat keine RegionCc → Überspringe Tournaments".yellow
      else
        region_cc_id = region_cc.cc_id
        
        # Get base URL from region (e.g., https://ndbv.de/ for NBV)
        base_url = region.public_cc_url_base
        unless base_url
          puts "⚠️  Region hat keine public_cc_url_base → Überspringe Tournaments".yellow
          next
        end

        # 1a. Tournament List URL
        tournament_list_url = "#{base_url}sb_meisterschaft.php?p=#{region_cc_id}--#{season.name}--0--2-1-100000-"
        tournament_list_file = html_dir.join("tournament_list_#{region.shortname.downcase}_#{season.name.gsub('/', '_')}.html")

        puts
        puts "1️⃣  Tournament Liste"
        puts "   URL: #{tournament_list_url}"
        puts "   File: #{tournament_list_file.relative_path_from(Rails.root)}"
        puts
        puts "   📋 Schritte:"
        puts "      1. URL im Browser öffnen:"
        puts "         #{tournament_list_url}".light_blue
        puts "      2. DevTools → Network → Seite neu laden"
        puts "      3. Erste Zeile (Document) → Response Tab → Rechtsklick → 'Copy response'"
        puts "      4. Dann hier eingeben:"
        puts

        print "   Fixture speichern? (y/n) [y]: "
        response = STDIN.gets.chomp
        response = 'y' if response.blank?

        if response.downcase == 'y'
          puts
          puts "   📥 HTML aus Clipboard einfügen und mit Ctrl+D abschließen:"
          content = STDIN.read

          if content.present? && content.include?('<html')
            File.write(tournament_list_file, content)
            puts "   ✅ Gespeichert: #{tournament_list_file.relative_path_from(Rails.root)}".green
            fixtures_collected << tournament_list_file.relative_path_from(Rails.root).to_s
          else
            puts "   ⚠️  Keine gültige HTML gefunden (oder leer)".yellow
          end
        else
          puts "   ⏭️  Übersprungen"
        end

        # 1b. Tournament Details (sample)
        puts
        puts "2️⃣  Tournament Details (Beispiel)"
        puts "   Wähle ein Turnier aus der Liste und kopiere dessen cc_id"
        puts
        print "   cc_id (z.B. 2971) oder Enter zum Überspringen: "
        cc_id = STDIN.gets.chomp

        if cc_id.present?
          tournament_detail_url = "#{base_url}sb_meisterschaft.php?p=#{region_cc_id}--#{season.name}-#{cc_id}----1-100000-"
          tournament_detail_file = html_dir.join("tournament_details_#{region.shortname.downcase}_#{cc_id}.html")

          puts
          puts "   URL: #{tournament_detail_url}"
          puts "   File: #{tournament_detail_file.relative_path_from(Rails.root)}"
          puts
          puts "   📋 Schritte: (wie oben)"
          puts "      URL öffnen: #{tournament_detail_url}".light_blue
          puts

          print "   Fixture speichern? (y/n) [y]: "
          response = STDIN.gets.chomp
          response = 'y' if response.blank?

          if response.downcase == 'y'
            puts
            puts "   📥 HTML aus Clipboard einfügen und mit Ctrl+D abschließen:"
            content = STDIN.read

            if content.present? && content.include?('<html')
              File.write(tournament_detail_file, content)
              puts "   ✅ Gespeichert: #{tournament_detail_file.relative_path_from(Rails.root)}".green
              fixtures_collected << tournament_detail_file.relative_path_from(Rails.root).to_s

              # Offer to create a "modified" version
              puts
              print "   Geänderte Version für Change Detection erstellen? (y/n) [n]: "
              modified_response = STDIN.gets.chomp

              if modified_response.downcase == 'y'
                modified_file = html_dir.join("tournament_details_#{region.shortname.downcase}_#{cc_id}_modified.html")
                FileUtils.cp(tournament_detail_file, modified_file)
                puts "   ✅ Kopiert: #{modified_file.relative_path_from(Rails.root)}".green
                puts "      → Bitte manuell editieren um Änderungen zu simulieren"
                fixtures_collected << modified_file.relative_path_from(Rails.root).to_s
              end
            else
              puts "   ⚠️  Keine gültige HTML gefunden".yellow
            end
          else
            puts "   ⏭️  Übersprungen"
          end
        else
          puts "   ⏭️  Übersprungen"
        end
      end
    end

    # === 2. LEAGUES ===
    if collect_leagues
      puts
      puts "🏅 " + "League Fixtures sammeln...".bold
      puts "-" * 60
      puts "   (Implementierung analog zu Tournaments)"
      puts "   ⏭️  Für manuelle Sammlung siehe: test/FIXTURES_SAMMELN.md"
    end

    # === 3. CLUBS ===
    if collect_clubs
      puts
      puts "👥 " + "Club & Player Fixtures sammeln...".bold
      puts "-" * 60
      puts "   (Implementierung analog zu Tournaments)"
      puts "   ⏭️  Für manuelle Sammlung siehe: test/FIXTURES_SAMMELN.md"
    end

    # Summary
    puts
    puts "=" * 60
    puts "✅ " + "Fixture-Sammlung abgeschlossen!".bold.green
    puts

    if fixtures_collected.any?
      puts "📦 Gesammelte Fixtures (#{fixtures_collected.size}):"
      fixtures_collected.each do |fixture|
        puts "   • #{fixture}"
      end
      puts
      puts "🎯 Nächste Schritte:"
      puts "   1. Fixtures überprüfen:"
      puts "      head test/fixtures/html/*.html".light_blue
      puts
      puts "   2. Tests anpassen:"
      puts "      vim test/scraping/tournament_scraper_test.rb".light_blue
      puts "      → skip Zeilen entfernen"
      puts "      → Fixtures einbinden"
      puts
      puts "   3. Tests laufen lassen:"
      puts "      bin/rails test:scraping".light_blue
    else
      puts "⚠️  Keine Fixtures gesammelt"
    end

    puts
    puts "📚 Dokumentation: test/FIXTURES_SAMMELN.md"
    puts
  end

  desc "List available test fixtures"
  task list_fixtures: :environment do
    html_dir = Rails.root.join('test', 'fixtures', 'html')

    puts
    puts "📁 Test Fixtures"
    puts "=" * 60
    puts

    if Dir.exist?(html_dir)
      fixtures = Dir.glob(html_dir.join('**', '*')).select { |f| File.file?(f) }

      if fixtures.any?
        fixtures.each do |fixture_path|
          fixture = Pathname.new(fixture_path)
          size = File.size(fixture) / 1024.0 # KB
          mtime = File.mtime(fixture)

          puts "📄 #{fixture.relative_path_from(Rails.root)}"
          puts "   Größe: #{size.round(1)} KB"
          puts "   Geändert: #{mtime.strftime('%Y-%m-%d %H:%M:%S')}"
          puts
        end

        puts "Gesamt: #{fixtures.size} Fixtures"
      else
        puts "⚠️  Keine Fixtures gefunden"
        puts "   Verwende: bin/rails test:collect_fixtures"
      end
    else
      puts "⚠️  Fixture-Verzeichnis existiert nicht: #{html_dir.relative_path_from(Rails.root)}"
      puts "   Verwende: bin/rails test:collect_fixtures"
    end

    puts
  end

  desc "Validate test fixtures (check if HTML is valid)"
  task validate_fixtures: :environment do
    require 'nokogiri'

    html_dir = Rails.root.join('test', 'fixtures', 'html')
    fixtures = Dir.glob(html_dir.join('**', '*.html'))

    puts
    puts "🔍 Fixture Validierung"
    puts "=" * 60
    puts

    if fixtures.empty?
      puts "⚠️  Keine Fixtures gefunden"
      exit 0
    end

    valid_count = 0
    invalid_count = 0

    fixtures.each do |fixture_path|
      fixture = Pathname.new(fixture_path)
      print "📄 #{fixture.relative_path_from(Rails.root)}... "

      begin
        html = File.read(fixture_path)

        # Check if it's HTML
        unless html.include?('<html') || html.include?('<!DOCTYPE')
          puts "❌ Keine HTML".red
          invalid_count += 1
          next
        end

        # Parse with Nokogiri
        doc = Nokogiri::HTML(html)

        # Check if parsing succeeded
        if doc.errors.any?
          puts "⚠️  Parse-Warnungen: #{doc.errors.size}".yellow
          valid_count += 1
        else
          puts "✅".green
          valid_count += 1
        end
      rescue => e
        puts "❌ Fehler: #{e.message}".red
        invalid_count += 1
      end
    end

    puts
    puts "=" * 60
    puts "Valide:   #{valid_count}"
    puts "Invalide: #{invalid_count}"
    puts

    exit 1 if invalid_count > 0
  end

  desc "Show example URLs for collecting fixtures"
  task show_fixture_urls: :environment do
    region_shortname = ENV['REGION'] || 'NBV'
    season_name = ENV['SEASON'] || Season.current_season&.name || '2025/2026'

    region = Region.find_by_shortname(region_shortname)
    season = Season.find_by_name(season_name)

    unless region
      puts "❌ Region '#{region_shortname}' nicht gefunden!"
      exit 1
    end

    unless season
      puts "❌ Season '#{season_name}' nicht gefunden!"
      exit 1
    end

    region_cc = region.region_cc
    unless region_cc
      puts "❌ Region hat keine RegionCc!"
      exit 1
    end

    region_cc_id = region_cc.cc_id
    base_url = region.public_cc_url_base
    
    unless base_url
      puts "❌ Region hat keine public_cc_url_base!"
      exit 1
    end

    puts
    puts "🌐 ClubCloud URLs für #{region.name} (#{season.name})"
    puts "=" * 60
    puts

    puts "1️⃣  Tournament Liste:"
    puts "   #{base_url}sb_meisterschaft.php?p=#{region_cc_id}--#{season.name}--0--2-1-100000-"
    puts

    puts "2️⃣  Tournament Details (Beispiel cc_id=2971):"
    puts "   #{base_url}sb_meisterschaft.php?p=#{region_cc_id}--#{season.name}-2971----1-100000-"
    puts

    puts "3️⃣  Region Homepage:"
    puts "   #{base_url}"
    puts

    puts "💡 Tipp: Diese URLs im Browser öffnen und HTML aus DevTools kopieren"
    puts
  end
end
