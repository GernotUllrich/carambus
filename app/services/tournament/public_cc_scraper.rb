# frozen_string_literal: true

# Kapselt die gesamte scrape_single_tournament_public-Pipeline aus Tournament in einen eigenstaendigen Service.
# Verantwortlichkeiten:
#   - Turnierdaten von ClubCloud (public CC-URL) scrapen und in der DB speichern
#   - Meldesliste, Teilnehmerliste, Einzelergebnisse und Rangliste verarbeiten
#   - Seedings, Games und GameParticipations anlegen/aktualisieren
#   - Hilfsmethoden: parse_table_tr, handle_game, variant0-8, Variant4, result_with_*, parse_table_td,
#     fix_location_from_location_text
#
# Verwendung:
#   Tournament::PublicCcScraper.call(tournament: tournament, opts: {})
class Tournament::PublicCcScraper < ApplicationService
  def initialize(kwargs = {})
    @tournament = kwargs[:tournament]
    @opts = kwargs[:opts] || {}
  end

  def call
    nbsp = ["c2a0"].pack("H*").force_encoding("UTF-8")
    return if @tournament.organizer_type != "Region"
    return if Carambus.config.carambus_api_url.present?

    region = @tournament.organizer if @tournament.organizer_type == "Region"
    url = @tournament.organizer.public_cc_url_base
    region_cc = region.region_cc
    tournament_doc = @opts[:tournament_doc]
    region_cc_cc_id = region_cc.cc_id
    tc = @tournament.tournament_cc
    tournament_cc_id = tc.andand.cc_id
    tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{@tournament.season.name}-#{tournament_cc_id}-0--2-1-100000-"
    unless tournament_doc.present?
      if tournament_cc_id.blank?
        tournament_link_ = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{@tournament.season.name}--0--2-1-100000-"
        Rails.logger.info "reading #{url + tournament_link_}"
        uri = URI(url + tournament_link_)
        tournament_html_ = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
        tournament_doc_ = Nokogiri::HTML(tournament_html_)
        tournament_cc_id = nil
        tournament_doc_.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
          next unless tr.css("a")[0].text.gsub(nbsp, " ").strip == @tournament.title

          tournament_link_ = tr.css("a")[0].attributes["href"].value
          params = tournament_link_.split("p=")[1].split("-")
          tournament_cc_id = params[3].to_i
          break
        end
        tc = TournamentCc.find_by_cc_id_and_context(tournament_cc_id, region_cc.context)
        tc ||= @tournament.create_tournament_cc!
        tc.assign_attributes(name: @tournament.title, season: @tournament.season.name, context: region_cc.context,
                             cc_id: tournament_cc_id,
                             tournament_id: @tournament.id)

        tc.save! if tc.changed?
        @tournament.reload
      else
        unless @tournament.tournament_cc.andand.name == @tournament.title
          raise StandardError,
                "Fatal mismatch Tournament#title: #{@tournament.title} and TournamenCc#name: #{@tournament.tournament_cc.andand.name}"
        end
      end
      tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{@tournament.season.name}-#{tournament_cc_id}----1-100000-"
      Rails.logger.info "reading #{url + tournament_link}"
      uri = URI(url + tournament_link)
      tournament_html = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
      Rails.logger.info "===== scrape =========================== SCRAPING TOURNAMENT '#{url + tournament_link}'"
      tournament_doc = Nokogiri::HTML(tournament_html)
    end
    @tournament.source_url = url + tournament_link
    # details
    detail_table = tournament_doc.css("aside table.silver")[0]
    branch_cc = nil
    discipline = nil
    detail_table.css("tr").each do |detail_tr|
      next unless detail_tr.css("td")[0].present?

      case detail_tr.css("td")[0].text.gsub(nbsp, " ").strip
      when "Kürzel"
        @tournament.shortname = tc.shortname = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
      when "Datum"
        ht = detail_tr.css("td")[1].inner_html
        date_time = DateTime.parse(ht.match(/.*Spielbeginn am (.*) Uhr.*/)[1].andand.gsub("um ", ""))
        tc.tournament_start = date_time
        @tournament.date = date_time
      when "Location"
        ht = detail_tr.css("td")[1].inner_html
        location = nil
        location_name, location_address = ht.match(%r{<strong>(.*)</strong><br>(.*)})[1..2]
        street = location_address.split("<br>").first&.split(",")&.first&.strip
        location = Location.where("address ilike ?", "#{street}%").first if street.present?
        if !location.present? && location_name.present?
          location = Location.new(name: location_name, address: location_address, organizer: @tournament)
          location.region_id = region.id
          md5 = location.md5_from_attributes
          loc_by_md5 = Location.where(md5: md5).first
          location = loc_by_md5 if loc_by_md5.present?
        end
        @tournament.location = tc.location = location
      when "Meldeschluss"
        text = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        date_time = DateTime.parse(text)
        @tournament.accredation_end = date_time
      when "Sparte"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        branch_cc = BranchCc.where(name:, context: region_cc.context).first
        if branch_cc.present?
          tc.branch_cc_id = branch_cc.id
        else
          Rails.logger.info "===== scrape ===== Problem Branch name #{name} db-unknown - should not happen here!"
        end
      when "Kategorie"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        category_cc = CategoryCc.where(name:, context: region_cc.context).first
        if category_cc.present?
          tc.category_cc_id = category_cc.id
        else
          tc.category_cc_name = name
        end
      when "Meisterschaftstyp"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        championship_type_cc = ChampionshipTypeCc.where(name:, context: region_cc.context).first
        if championship_type_cc.present?
          tc.championship_type_cc_id = championship_type_cc.id
        else
          tc.championship_type_cc_name = name
        end
      when "Disziplin"
        discipline_name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        discipline = Discipline.where("synonyms ilike ?", "%#{discipline_name}%").to_a.find do |dis|
          dis.synonyms.split("\n").include?(discipline_name)
        end
        unless discipline.present?
          discipline = Discipline.create(name: discipline_name, super_discipline_id: branch_cc.andand.id)
        end
        tc.discipline_id = @tournament.discipline_id = discipline.id
      else
        next
      end
    end
    tc.save
    @tournament.region_id = region.id
    @tournament.save!
    # Meldeliste
    # Nur beim Archivieren (reload_game_results: true) alte Seedings aufräumen
    # Beim Setup (reload_game_results: false) bestehende Seedings NICHT löschen!
    if @opts[:reload_game_results] || @opts[:reload_seedings]
      @tournament.reload.seedings.destroy_all
    end
    player_list = {}
    registration_link = tournament_link.gsub("meisterschaft", "meldeliste")
    Rails.logger.info "reading #{url + registration_link}"
    uri = URI(url + registration_link)
    registration_html = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    registration_doc = Nokogiri::HTML(registration_html)
    registration_table = registration_doc.css("aside table.silver table")[0]
    _header = []
    if registration_table.present?
      registration_table.css("tr")[1..].each_with_index do |tr, ix|
        if tr.css("th").count > 1
          _header = tr.css("th").map(&:text)
        elsif tr.css("td").count.positive?
          _n = tr.css("td")[0].text.to_i
          # New format: td[2] contains player name in <b> tag and club after <br>
          player_td = tr.css("td")[2]
          if player_td.present?
            # Extract player name (in bold) and club (after <br>)
            lines = player_td.inner_html.gsub(/<b>|<\/b>/, "").split(/<br>/i).map { |line| line.gsub(nbsp, " ").strip }
            player_fullname = lines[0] if lines[0].present?
            club_name = lines[1] if lines[1].present?

            # Split player name on last space (lastname is after last space)
            if player_fullname.present?
              last_space_index = player_fullname.rindex(" ")
              if last_space_index
                player_fname = player_fullname[0...last_space_index].strip
                player_lname = player_fullname[last_space_index + 1..-1].strip
              else
                player_fname = ""
                player_lname = player_fullname.strip
              end

              club_name = club_name.andand.gsub("1.", "1. ").andand.gsub("1.  ", "1. ") if club_name.present?
              # Don't create seedings yet - just collect players from registration list
              player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname,
                                                                             @tournament.season, region,
                                                                             club_name, nil,
                                                                             true, true, ix)
              player_list[player.fl_name] = [player, club, ix] if player.present?
            end
          end
        end
      end
    end
    # Seedings ohne Player-Zuordnung immer aufräumen
    @tournament.reload.seedings.where(player: nil).destroy_all
    # Teilnehmerliste
    # player_list = {}
    tournament_doc.css("aside .stanne table.silver table").each do |table|
      next unless table.css("tr th")[0].andand.text.gsub(nbsp, " ").strip == "TEILNEHMERLISTE"

      table.css("tr")[2..].each_with_index do |tr, ix|
        _n = tr.css("td")[0].text.to_i
        name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)[,\/](.*)</strong><br>(.*)})
        if name_match
          player_lname, player_fname, club_name = name_match[1..3]
        else
          name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)\s+(\w+)</strong><br>(.*)})
          if name_match
            player_fname, player_lname, club_name = name_match[1..3]
          else
            name_match = tr.css("td")[2].inner_html.match(%r{<strong>(.*)</strong><br>(.*)})
            player_lname, club_name = name_match[1..2]
          end
        end
        club_name = club_name.andand.gsub("1.", "1. ").andand.gsub("1.  ", "1. ")
        # Don't create seedings yet - just collect players from participant list
        player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname, @tournament.season,
                                                                       region,
                                                                       club_name.strip, nil,
                                                                       true, true, ix)
        # Only add to player_list if not already present (registration list takes precedence for position)
        player_list[player.fl_name] ||= [player, club, ix] if player.present?
      end
    end

    # Now create seedings for all players in the unified player_list
    Rails.logger.info "==== scrape ==== Creating seedings for #{player_list.count} players from combined registration and participant lists"
    player_list.each_with_index do |(fl_name, (player, club, position)), idx|
      next unless player.present?

      seeding = Seeding.find_by_player_id_and_tournament_id(player.id, @tournament.id)
      unless seeding.present?
        seeding = Seeding.new(player_id: player.id, tournament: @tournament, position: position || idx)
        seeding.region_id = region.id
        if seeding.save
          Rails.logger.info("Seeding[#{seeding.id}] created for #{fl_name}.")
        else
          Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player.id} (#{fl_name}): #{seeding.errors.full_messages.join(", ")}")
        end
      end
    end

    @tournament.reload
    return if discipline&.name == "Biathlon"

    # Delete games BEFORE processing results (if reload_game_results is true)
    # This ensures orphan games are deleted even if the results table doesn't exist
    # IMPORTANT: Use destroy_all (not delete_all) to create PaperTrail versions for synchronization with local servers
    if @opts[:reload_game_results]
      games_to_delete = Game.where(tournament_id: @tournament.id)
      count_before = games_to_delete.count
      if count_before > 0
        Rails.logger.info "Deleting #{count_before} game(s) for tournament #{@tournament.id} (reload_game_results: true)"
        games_to_delete.destroy_all
        count_after = Game.where(tournament_id: @tournament.id).count
        Rails.logger.info "After deletion: #{count_after} game(s) remaining for tournament #{@tournament.id}"
      end
    end

    # Ergebnisse
    result_link = tournament_link.gsub("meisterschaft", "einzelergebnisse")
    result_url = url + result_link
    Rails.logger.info "reading #{result_url}"
    uri = URI(result_url)
    result_html = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    result_doc = Nokogiri::HTML(result_html)
    table = result_doc.css("aside table.silver")[1]
    if table.present?
      group_options = result_doc.css('select[name="groupItemId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      group_option_values = group_options.values
      group_cc = tc.group_cc
      unless group_cc.present?
        GroupCc.where(branch_cc: tc.branch_cc).each do |gcc|
          if JSON.parse(gcc.data)["positions"].andand.values == group_option_values
            group_cc = gcc
            break
          end
        end
      end
      unless group_cc.present?
        group_cc = GroupCc.create!(
          context: region_cc.context,
          name: "Unknown Group - scraped from TournamentCc[#{tc.id}]",
          display: "Gruppen",
          status: "Freigegeben",
          branch_cc_id: tc.branch_cc_id,
          data: { "positions" => group_options }.to_json
        )
        tc.assign_attributes(group_cc: group_cc)
      end
      player_options = result_doc.css('select[name="teilnehmerId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      player_options.each do |k, v|
        lastname, firstname = v.split(/[,\/]/).map(&:strip)
        firstname&.gsub!(/\s*\((.*)\)/, "")
        fl_name = "#{firstname} #{lastname}".strip
        player = player_list[fl_name].andand[0]
        if player.present?
          player.assign_attributes(cc_id: k.to_i) unless @tournament.organizer.shortname == "DBU"
          if player.new_record?
            player.source_url ||= result_url unless @tournament.organizer.shortname == "DBU"
          end
          player.region_id ||= region.id
          player.save if player.changed?
        else
          Rails.logger.info("===== scrape ===== Inconsistent Playerlist Player #{[k, v].inspect}")
        end
      end
      # games.destroy_all if @opts[:reload_game_results]
      group = nil
      frame1_lines = result_lines = td_lines = 0
      result = nil
      no = nil
      playera_fl_name = nil
      playerb_fl_name = nil
      frames = []
      frame_points = []
      innings = []
      hs = []
      hb = []
      mp = []
      header = []
      gd = []
      points = []
      frame_result = []
      table.css("tr").each do |tr|
        frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no,
          player_list, playera_fl_name, playerb_fl_name, points, result, result_lines, result_url,
          td_lines, _tr = parse_table_tr(region,
                                         frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                                         header, hs, mp, innings, nbsp, no, player_list, playera_fl_name,
                                         playerb_fl_name,
                                         points, result, result_lines, result_url, td_lines, tr)
      end
      if td_lines.positive? && no.present?
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
      end
    end

    # Rangliste
    ranking_link = tournament_link.gsub("meisterschaft", "einzelrangliste")
    Rails.logger.info "reading #{url + ranking_link}"
    uri = URI(url + ranking_link)
    ranking_html = Rails.env == "development" ? Version.http_get_with_ssl_bypass(uri) : Net::HTTP.get(uri)
    ranking_doc = Nokogiri::HTML(ranking_html)
    ranking_table = ranking_doc.css("aside table.silver table")[0]
    header = []
    if ranking_table.present?
      ranking_table.css("tr")[1..].each do |tr|
        if tr.css("th").count > 1
          header = []
          tr.css("th")[0..].each do |th|
            header << th.text
            colspan = th.attributes["colspan"].andand.value.to_i
            next unless colspan > 1

            (2..colspan).each do
              header << ""
            end
          end
        elsif tr.css("td").count.positive?
          rang = g = v = rp = quote = points = innings = gd = bed = hs = hb = mp = player_fl_name = nil
          header.each_with_index do |h, ii|
            case h
            when /\A(rang)\z/i
              rang = tr.css("td")[ii].text.to_i
            when /\A(rp)\z/i
              rp = tr.css("td")[ii].text.to_i
            when /\A(name|teilnehmer)\z/i
              player_fl_name = tr.css("td")[ii].css("a").text.gsub(nbsp, " ").gsub(/\s*\((.*)\)/, "").strip
            when /\A(g|f)\z/i
              g = tr.css("td")[ii].text.to_i
            when /\A(v)\z/i
              v = tr.css("td")[ii].text.to_i
            when /\A(quote)\z/i
              quote = tr.css("td")[ii].text
            when /\A(punkte)\z/i
              points = tr.css("td")[ii].text.to_i
            when /\A(aufn\.)\z/i
              innings = tr.css("td")[ii].text.to_i
            when /\A(hb)\z/i
              hb = tr.css("td")[ii].text
            when /\A(bed)\z/i
              bed = tr.css("td")[ii].text.gsub(",", ".").to_f.round(2)
            when /\A(gd)\z/i
              gd = tr.css("td")[ii].text.gsub(",", ".").to_f.round(2)
            when /\A(hs)\z/i
              hs = tr.css("td")[ii].text
            when /\A(mp)\z/i
              mp = tr.css("td")[ii].text.to_i
            end
          end
          if player_fl_name =~ /\//
            names = player_fl_name.split(/\//).map(&:strip)
            player_fl_name = player_list[names.join(" ")].present? ? names.join(" ") : names.reverse.join(" ")
          end
          seeding = @tournament.seedings.where(player: player_list[player_fl_name][0]).first if player_list[player_fl_name].present?
          if seeding.blank?
            Rails.logger.info("===== scrape ===== seeding of player #{player_fl_name} should exist!")
          else
            seeding.assign_attributes(
              data: {
                "result" =>
                  { "Gesamtrangliste" =>
                      { "Rang" => rang,
                        "RP" => rp,
                        "Name" => player_list[player_fl_name][0].fullname,
                        "Club" => player_list[player_fl_name].andand[1].andand.shortname,
                        "Punkte" => points,
                        "Frames" => frame_points,
                        "Aufn." => innings,
                        "G" => g,
                        "V" => v,
                        "Quote" => quote,
                        "GD" => gd,
                        "BED" => bed,
                        "HS" => hs,
                        "HB" => hb }.compact }
              }
            )
            seeding.region_id = region.id
            seeding.save if seeding.changed?
          end
        end
      rescue StandardError => e
        Rails.logger.info("===== scrape ===== something wrong: #{e} #{e.backtrace}")
      end
    end

    @tournament.region_id = region.id
    @tournament.save! if @tournament.changed?
    tc.save! if tc.changed?
  rescue StandardError => e
    Tournament.logger.info "===== scrape =====  StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
    @tournament.reset_tournament
  end

  private

  def parse_table_tr(region, frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                     header, hs, mp, innings, nbsp, no,
                     player_list, playera_fl_name, playerb_fl_name,
                     points, result, result_lines, result_url, td_lines, tr)
    if tr.css("th").count == 1
      group_ = tr.css("th").text.gsub(nbsp, " ").strip
      if group.present? && no.present? && group_.present? && group_ != 0 && group != group_
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      group = group_
    elsif tr.css("th").count > 1
      header = tr.css("th").map(&:text)
    elsif tr.css("td").count.positive?
      no_ = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      if no.present? && no_.present? && no_ != 0 && no != no_
        handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      td_lines += 1
      case header
      when %w[Partie Begegnung Partien Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant0(nbsp, points, result_lines, tr)
      when %w[Partie Begegnung Frames HB Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_frames(frame_points, hb, nbsp, tr)
        result_lines += 1
      when %w[Partie Begegnung Partien Ergebnis]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_parties(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Begegnung Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_party(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Frame Begegnung HB Erg.]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
      when ["Partie", "Frame", "Begegnung", "Aufn.", "", "", "Erg."]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
      when %w[Partie Frame Begegnung Erg.]
        if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
          result_lines += 1
          result = tr.css("td")[1].text.gsub(nbsp, " ").strip
        elsif tr.css("td").count == 4
          frames << tr.css("td")[1].text.to_i
          frame_result << tr.css("td")[3].text.gsub(nbsp, " ").strip
        else
          frame1_lines, no, playera_fl_name, playerb_fl_name =
            variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
        end
      when %w[Partie Begegnung Planzeit]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs =
          variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
      when %w[Partie Begegnung Pkt. Aufn. HS GD Erg.], %w[Partie Begegnung Punkte Aufn. HS GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          Variant4(gd, hs, innings, nbsp, points, result_lines, tr)

      when ["Partie", "Begegnung", "Pkt.", "Aufn.", "", "", "Erg."]
        no, playera_fl_name, playerb_fl_name, result, result_lines = variant5(innings, nbsp, points, result_lines, tr)

      when %w[Partie Frame Begegnung Pkt. Aufn. HS GD Erg.]
        # TODO: Begegnung??
        if tr.css("td").count >= 3
          frame1_lines, frame_result, no =
            variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
        end
      when %w[Partie Begegnung Aufn. HS GD Erg.], %w[Partie Begegnung Aufn. HS GD Ergebnis]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant7(gd, hs, innings, nbsp, points, result_lines, tr)
      when %w[Partie Begegnung GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant8(gd, nbsp, points, result_lines, tr)
      else
        Rails.logger.info("===== scrape ===== unknown header #{header.inspect}")
      end
    end
    [frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no, player_list,
     playera_fl_name, playerb_fl_name, points, result, result_lines, result_url, td_lines, tr]
  end

  def variant0(nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant8(gd, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    gd << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant7(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    frame_result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    [frame1_lines, frame_result, no]
  end

  def variant5(innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def Variant4(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[6].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[7].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
    if tr.css("td").count == 3 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Endergebnis|Ergebnis):/
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Frame|Satz)/
      frames << tr.css("td")[0].text.to_i
      frame1_lines += 1
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    elsif tr.css("td").count == 5
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      playera_fl_name = (tr.css("td")[1].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a1, b1, c1 = tr.css("td")[1].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.gsub(nbsp, " ").andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      playerb_fl_name = (tr.css("td")[3].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a2, b2, c2 = tr.css("td")[3].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.gsub(nbsp, " ").andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      hs << "#{a1}/#{a2}"
      innings << "#{b1}/#{b2}"
      gd << "#{c1}/#{c2}"
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    else
      Rails.logger.info("===== scrape ===== Error: unexpected input #{header.inspect}, #{tr.inspect}, url: #{result_url}")
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs]
  end

  def variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    frame_result << tr.css("td")[5].text.gsub(nbsp, " ").strip
    [frame1_lines, no, playera_fl_name, playerb_fl_name]
  end

  def result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 7
      frames << tr.css("td")[1].text.to_i
      innings << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
      points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[8].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5
      frames << tr.css("td")[1].text.to_i
      hb << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[4].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      # innings << tr.css('td')[5].text.gsub(nbsp, " ").strip
      frame_points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_parties(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_frames(frame_points, hb, nbsp, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    frame_points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[6].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  # DEAD CODE: parse_table_td is not called anywhere. Moved with scraper for completeness.
  def parse_table_td(ix, logger, region, season, seeding, state_ix, states, td)
    nbsp = ["c2a0"].pack("H*").force_encoding("UTF-8")
    l_state_ix = state_ix
    if td.css("div").present?
      lastname, firstname, club_str =
        td.css("div").text.gsub(nbsp, " ").strip
          .match(/(.*),\s*(.*)\s*\((.*)\)/).to_a[1..].map(&:strip)
      _player, club, _seeding, _state_ix = Player.fix_from_shortnames(lastname, firstname, season, region,
                                                                      club_str, @tournament,
                                                                      true, true, ix)
      if club.present?
        season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(
          seasons: { id: season.id }, players: { fl_name: "#{firstname} #{lastname}".strip }
        )
        if season_participations.count == 1
          season_participation = season_participations.first
          player = season_participation&.player
          if player.present?
            unless season_participation&.club_id == club.id
              real_club = season_participations.first&.club
              if real_club.present?
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region&.shortname}, season #{season.name}!"

                _sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id,
                                                                                      real_club.id) ||
                  SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id,
                                             position: ix + 1)
                unless _sp.present?
                  sp = SeasonParticipation.new(player_id: player.id, season_id: season.id, club_id: real_club.id,
                                               position: ix + 1)
                  sp.region_id = region.id
                  sp.save
                end
              end
            end
            seeding = Seeding.find_by_player_id_and_tournament_id(player.id, @tournament.id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player.id, tournament: @tournament, position: position)
              seeding.region_id = region.id
              seeding.save
            end
            seeding_ids.delete(seeding.id)
          end
        elsif season_participations.count.zero?
          players = Player.where(type: nil).where(firstname:, lastname:)
          if players.count.zero?
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"

            # Use PlayerFinder to prevent duplicates
            player_fixed = Player.find_or_create_player(
              firstname: firstname,
              lastname: lastname,
              club_id: club.id,
              region_id: region.id,
              season_id: season.id,
              allow_create: true
            )

            if player_fixed.present?
              logger.info "==== scrape ==== [scrape_tournaments] Player #{lastname}, #{firstname} (ID: #{player_fixed.id}) found/created for club #{club_str} [#{club.ba_id}]"
            else
              logger.error "==== scrape ==== [scrape_tournaments] Failed to find/create player #{lastname}, #{firstname}"
            end
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                 club.id)
            unless sp.present?
              sp = SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              records_to_tag |= Array(sp)
            end
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, @tournament.id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player_fixed.id, tournament: @tournament, position: position)
              seeding.region_id = region.id
              seeding.save
            end
            seeding_ids.delete(seeding.id)
          elsif players.count == 1
            player_fixed = players.first
            if player_fixed.present?
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                   club.id)
              unless sp.present?
                sp = SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                records_to_tag |= Array(sp)
              end
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, @tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed&.id, tournament: @tournament, position: position)
                seeding.region_id = region.id
                seeding.save
              end
              seeding_ids.delete(seeding.id)
            end
          elsif players.count > 1
            clubs_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end
            club_fixed_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end.first
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{clubs_str}] "
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{club_fixed_str}] "
            player_fixed = players.first
            if player_fixed.present? && club.present?
              sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                   club.id)
              unless sp.present?
                sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
                sp.region_id = region.id
                sp.save
              end
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, @tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed&.id, tournament: @tournament, position: position)
                seeding.region_id = region.id
                seeding.save
              end
              seeding_ids.delete(seeding.id)
            end
          end
        elsif season_participations.map(&:club_id).uniq.include?(club.id)
          # (ambiguous clubs)
          season_participation = season_participations.where(club_id: club.id).first
          player = season_participation&.player
          if player.present?
            _seeding = Seeding.find_by_player_id_and_tournament_id(player.id, @tournament.id)
            unless _seeding.present?
              _seeding = Seeding.new(player_id: player.id, tournament_id: @tournament.id)
              _seeding.region_id = region.id
              _seeding.save
            end
          end
        else
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
          fixed_season_participation = season_participations.last
          fixed_club = fixed_season_participation.club
          fixed_player = fixed_season_participation.player
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
          sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(fixed_player.id, season.id,
                                                                               fixed_club.id)
          unless sp.present?
            sp = SeasonParticipation.new(player_id: fixed_player.id, season_id: season.id,
                                         club_id: fixed_club.id)
            sp.region_id = region.id
            sp.save
          end
          seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, @tournament.id)
          unless seeding.present?
            seeding = Seeding.new(player_id: fixed_player.id, tournament_id: @tournament.id)
            seeding.region_id = region.id
            seeding.save
          end
          seeding_ids.delete(seeding.id)
        end
      else
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
        fixed_club = region.clubs.new(name: club_str, shortname: club_str)
        fixed_club.region_id = region.id
        fixed_club.save
        fixed_player = fixed_club.players.new(firstname:, lastname:)
        fixed_player.region_id = region.id
        fixed_player.save
        fixed_club.update(ba_id: 999_000_000 + fixed_club.id)
        fixed_player.update(ba_id: 999_000_000 + fixed_player.id)
        sp = SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)
        sp.region_id = region.id
        sp.save
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
        seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, @tournament.id)
        unless seeding.present?
          seeding = Seeding.new(player_id: fixed_player&.id, tournament: @tournament, position: position)
          seeding.region_id = region.id
          seeding.save
        end
        seeding_ids.delete(seeding.id)
      end
    elsif /X/.match?(td.text.gsub(nbsp, " ").strip)
      if seeding.present?
        seeding.update_attribute(:ba_state, states[l_state_ix])
      else
        logger.info "==== scrape ==== [scrape_tournaments] Fatal 501 - seeding nil???"
        Kernel.exit(501)
      end
    end
  end

  def handle_game(region, frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                  playerb_fl_name,
                  frame_points, points, result)
    # Skip games where both players are "Freilos" (bye games) - these shouldn't be created
    # Check if both players are "Freilos" or both are missing from player_list
    playera_missing = playera_fl_name == "Freilos" || !player_list[playera_fl_name].present?
    playerb_missing = playerb_fl_name == "Freilos" || !player_list[playerb_fl_name].present?
    if playera_missing && playerb_missing
      Rails.logger.info "Skipping bye game (Freilos vs Freilos) for tournament #{@tournament.id}, seqno #{no}, group #{group}"
      return
    end
    game = @tournament.games.where(seqno: no, gname: group).first
    region_id = region.id
    data = if frames.count > 1
             frame_data = []
             frames.each_with_index do |_frame, ix|
               frame_data << {
                 "Frame" => frames[ix],
                 "Punkte" => points[ix].presence || frame_points[ix],
                 "Aufn." => innings[ix],
                 "HS" => hs[ix],
                 "HB" => hb[ix],
                 "Durchschnitt" => gd[ix],
                 "FrameResult" => frame_result[ix]
               }.compact
             end
             {
               "Gruppe" => group,
               "Partie" => no,
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname,
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname,
               "Disziplin" => @tournament.discipline.andand.name,
               "Ergebnis" => result
             }.compact.merge(frames: frame_data)
           else
             {
               "Gruppe" => group,
               "Partie" => no,
               "Frame" => frames[0],
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Disziplin" => @tournament.discipline.andand.name,
               "Punkte" => points[0].presence || frame_points[0],
               "MP" => mp[0],
               "Aufn." => innings[0],
               "HS" => hs[0],
               "HB" => hb[0],
               "Durchschnitt" => gd[0],
               "FrameResult" => frame_result[0],
               "Ergebnis" => result
             }.compact
           end
    if game.present?
      game.assign_attributes(tournament_id: @tournament.id,
                             tournament_type: "Tournament",
                             data: data,
                             seqno: no,
                             gname: group)
      if game.changed?
        game.region_id = region_id
        game.save!
      end
    else
      game = Game.new(
        tournament_id: @tournament.id,
        tournament_type: "Tournament",
        data: data,
        seqno: no,
        gname: group
      )
      game.region_id = region_id
      game.save! if game.changed?
    end
    unless game.game_participations.empty? &&
      player_list[playera_fl_name].present? &&
      player_list[playerb_fl_name].present?
      return
    end

    gp = game.game_participations.new(
      player_id: player_list[playera_fl_name][0].id,
      role: "Heim",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[0].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[0].andand.strip,
              "GD" => gd[0].to_s.split("/")[0].andand.strip,
              "HS" => hs[0].to_s.split("/")[0].andand.strip }.compact },
      result: points[0].to_s.split(":")[0].andand.strip,
      innings: innings[0].to_s.split("/")[0].andand.strip,
      gd: gd[0].to_s.split("/")[0].andand.strip,
      hs: hs[0].to_s.split("/")[0].andand.strip
    )
    gp.region_id = region_id
    gp.save! if gp.changed?
    gp = game.game_participations.new(
      player_id: player_list[playerb_fl_name][0].id,
      role: "Gast",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[1].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[1].andand.strip,
              "GD" => gd[0].to_s.split("/")[1].andand.strip,
              "HS" => hs[0].to_s.split("/")[1].andand.strip }.compact },
      result: points[0].to_s.split(":")[1].andand.strip,
      innings: innings[0].to_s.split("/")[1].andand.strip,
      gd: gd[0].to_s.split("/")[1].andand.strip,
      hs: hs[0].to_s.split("/")[1].andand.strip
    )
    gp.region_id = region_id
    gp.save! if gp.changed?
  end

  # DEAD CODE: fix_location_from_location_text is not called anywhere. Moved with scraper for completeness.
  def fix_location_from_location_text
    location_name = @tournament.location_text.split("\n").first
    return unless location_name.present?
    return unless @tournament.location.present?

    nil unless /#{location_name}/.match?(@tournament.location.synonyms)
    # done
  end
end
