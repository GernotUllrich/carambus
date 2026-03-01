require "nokogiri"

tournament_id = 18_167
tournament = Tournament.find(tournament_id)

puts "Tournament: #{tournament.name}"

doc = Nokogiri::HTML(File.read("cuesco_202.html"))

# Delete existing games to avoid duplicates
tournament.games.destroy_all

# Helper to find or create player
def find_or_create_player(name_str)
  # name_str looks like: "B. KARAKURT\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[TÜRKIYE 2026]"
  # or "A. AL GHABABS.\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t[JORDAN 2026]"
  name_part = name_str.split("[").first.to_s.strip
  # extract firstname initial and lastname. "B. KARAKURT" -> Firstname: "B.", Lastname: "KARAKURT", or just Lastname "KARAKURT"
  parts = name_part.split(".")
  if parts.size > 1
    firstname = parts[0].strip + "."
    lastname = parts[1..-1].join(".").strip
  else
    firstname = ""
    lastname = name_part
  end

  lastname = lastname.titleize

  # Try to find existing player
  player = Player.where("lastname ILIKE ?", "%#{lastname}%").first
  if player.nil?
    player = Player.create!(
      firstname: firstname,
      lastname: lastname,
      international_player: true
    )
    puts "  Created New Player: #{firstname} #{lastname}"
  end
  player
end

group_name = "Unknown Group"

doc.css("h4, table.table-advance").each do |node|
  if node.name == "h4"
    group_name = node.text.strip
    puts "Found Section: #{group_name}"
  elsif node.name == "table" && !node.classes.include?("team-summary")
    # This is a match table
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

      # Date can be in td 1
      date_str = p1_tds[1]&.text&.strip

      p1 = find_or_create_player(p1_name_raw)
      p2 = find_or_create_player(p2_name_raw)

      next unless p1 && p2

      game = tournament.games.create!(
        gname: "Match - #{group_name}",
        data: { "group" => group_name, "date" => date_str }
      )

      GameParticipation.create!(
        game: game,
        player: p1,
        result: pts1,
        innings: inn1,
        role: "home"
      )

      GameParticipation.create!(
        game: game,
        player: p2,
        result: pts2,
        innings: inn2,
        role: "away"
      )

      puts "  Created Game: #{p1.fl_name} (#{pts1}) vs #{p2.fl_name} (#{pts2}) in #{inn1} inn"
    end
  end
end

puts "Imported #{tournament.games.count} games into Tournament #{tournament.id}."
