# frozen_string_literal: true

require "nokogiri"
require "open-uri"

# Scrapes UMB/Cuesco (Five&Six) to retrieve live tournament matches and results
class CuescoScraper
  BASE_URL = "http://umb.cuesco.net"

  # Scrapes the index and returns an array of hashes with title, start_date, end_date, idx
  def self.scrape_index
    doc = Nokogiri::HTML(URI.parse("#{BASE_URL}/main/competition").open)
    tournaments = []

    doc.css('a[href*="idx="]').each do |a|
      href = a["href"].to_s
      next unless href.include?("/competition/info?idx=")

      idx = href.split("idx=").last
      text = a.text.strip
      lines = text.split("\n").map(&:strip).reject(&:empty?)

      # typically lines look like:
      # [0] "2026-02-26 ~ 2026-03-01"
      # [1] "38th World Championship Nat. Teams 3-Cushion"
      # [2] "3-Cushion World Championship Nat. Teams 3-Cushion"

      next unless lines.size >= 2
      next unless lines[0].include?("~")

      dates = lines[0].split("~").map(&:strip)
      title = lines[1]

      # We only keep unique idxs
      next if tournaments.any? { |t| t[:idx] == idx }

      tournaments << {
        idx: idx,
        title: title,
        start_date: dates[0],
        end_date: dates[1]
      }
    end
    tournaments
  end

  def self.sync_active_tournaments
    # Find Cuesco "active/recent" tournaments from the index
    # We'll just look at the top 10 from the index to not overload the servers
    list = scrape_index.first(10)

    count_games = 0
    list.each do |t_info|
      start_parsed = begin
        Date.parse(t_info[:start_date])
      rescue StandardError
        nil
      end
      next unless start_parsed

      # Match tournament by date and limit to InternationalTournament
      # Find tournaments starting around that date (within +- 2 days)
      tournament = Tournament.international.where(date: (start_parsed - 2.days)..(start_parsed + 2.days)).first
      next unless tournament

      puts "✓ Found matching DB Tournament: '#{tournament.name}' (ID: #{tournament.id}) for Cuesco IDX: #{t_info[:idx]}"
      imported = scrape_tournament(tournament, t_info[:idx])
      puts "  -> Imported #{imported} new games."
      count_games += imported
    end
    count_games
  end

  # rubocop:disable Metrics/AbcSize
  def self.scrape_tournament(tournament, cuesco_idx)
    url = "#{BASE_URL}/competition/result?idx=#{cuesco_idx}#content"
    doc = Nokogiri::HTML(URI.parse(url).open)

    group_name = "Unknown Group"
    games_created = 0

    doc.css("h4, table.table-advance").each do |node|
      if node.name == "h4"
        group_name = node.text.strip
      elsif node.name == "table" && !node.classes.include?("team-summary")
        rows = node.css("tbody tr")
        rows.each_slice(2) do |row1, row2|
          next unless row2

          p1_tds = row1.css("td")
          p2_tds = row2.css("td")

          next if p1_tds.size < 6 || p2_tds.size < 6

          p1_name_raw = p1_tds[0].text
          p2_name_raw = p2_tds[0].text

          pts1 = p1_tds[3].text.to_i
          pts2 = p2_tds[3].text.to_i
          inn1 = p1_tds[4].text.to_i
          inn2 = p2_tds[4].text.to_i

          date_str = p1_tds[1]&.text&.strip

          p1 = find_or_create_player(p1_name_raw)
          p2 = find_or_create_player(p2_name_raw)

          next unless p1 && p2

          # Avoid duplicates completely by checking if this game already exists exactly for these players
          existing_game = tournament.games.joins(:game_participations).where(
            game_participations: { player_id: p1.id }
          ).distinct.find do |g|
            g.game_participations.exists?(player_id: p2.id) &&
              g.game_participations.find_by(player_id: p1.id).result == pts1 &&
              g.game_participations.find_by(player_id: p2.id).result == pts2 &&
              g.game_participations.find_by(player_id: p1.id).innings == inn1
          end

          next if existing_game

          game = tournament.games.create!(
            gname: "Match - #{group_name}",
            data: { "group" => group_name, "date" => date_str, "cuesco_idx" => cuesco_idx }
          )

          GameParticipation.create!(game: game, player: p1, result: pts1, innings: inn1, role: "home")
          GameParticipation.create!(game: game, player: p2, result: pts2, innings: inn2, role: "away")

          games_created += 1
        end
      end
    end
    games_created
  end
  # rubocop:enable Metrics/AbcSize

  def self.find_or_create_player(name_str)
    name_part = name_str.split("[").first.to_s.strip
    parts = name_part.split(".")
    if parts.size > 1
      firstname = "#{parts[0].strip}."
      lastname = parts.drop(1).join(".").strip
    else
      firstname = ""
      lastname = name_part
    end

    lastname = lastname.titleize

    player = Player.where("lastname ILIKE ?", "%#{lastname}%").first
    if player.nil?
      player = Player.create!(
        firstname: firstname,
        lastname: lastname,
        international_player: true
      )
    end
    player
  end
end
