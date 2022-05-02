class RegionCcAction
  def self.synchronize_region_structure(session_id)
    regions_todo = []
    regions_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context.upcase)
    unless region.blank?
      regions_todo = [region.id]
      regions_done = RegionCc.sync_regions(session_id, region).map(&:id)
    else
      raise_err_msg("synchronize_region_structure", "unknown context Region #{context}")
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      raise_err_msg("synchronize_region_structure", "regions with context #{context} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}")
    end
    regions_overdone = regions_done - regions_todo
    unless regions_overdone.blank?
      raise_err_msg("synchronize_region_structure", "more regions with context #{context} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}")
    end
  end

  def self.synchronize_branch_structure(session_id)
    branches_todo = []
    branches_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      branches_todo = Branch.all.ids
      branches_done = region_cc.sync_branches(session_id).map(&:id)
    else
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    end
    branches_still_todo = branches_todo - branches_done
    unless branches_still_todo.blank?
      raise_err_msg("synchronize_branch_structure", "branches with context #{context} not yet in CC: #{Branch.where(id: branches_todo).map(&:name)}")
    end
    branches_overdone = branches_done - branches_todo
    unless branches_overdone.blank?
      raise_err_msg("synchronize_branch_structure", "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
    end
  end

  def self.synchronize_competition_structure(session_id)
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      competitions_todo = Competition.all.ids
      competitions_done = region_cc.sync_competitions.map(&:id)
    else
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    end
    competitions_still_todo = competitions_todo - competitions_done
    unless competitions_still_todo.blank?
      raise_err_msg("synchronize_branch_structure", "branches with context #{context} not yet in CC: #{Branch.where(id: competitions_todo).map(&:name)}")
    end
    branches_overdone = competitions_done - competitions_todo
    unless branches_overdone.blank?
      raise_err_msg("synchronize_branch_structure", "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
    end
  end

  def synchronize_season_structure(session_id)
    ["2010/2011"].each do |season_name|
      context = ENV["REGION"] || "NBV"
      region = Region.find_by_shortname(context)
      region_cc = region.region_cc
      unless region_cc.blank?
        competition_cc_ids_todo = CompetitionCc.where(context: context.downcase).all.map(&:cc_id)
        competition_cc_ids_done = region_cc.sync_seasons_in_competitions(season_name).map(&:cc_id)
      else
        raise_err_msg("synchronize_season_structure", "unknown context Region #{context}")
      end
      competition_cc_ids_still_todo = competition_cc_ids_todo - competition_cc_ids_done
      unless competition_cc_ids_still_todo.blank?

        Rails.logger.warn "REPORT! [synchronize_season_structure] Saison #{season_name} nicht definiert für Wettbewerbe #{CompetitionCc.where(cc_id: competition_cc_ids_still_todo).map { |ccc| "#{ccc.branch_cc.name} - #{ccc.name} (#{ccc.cc_id})" }}"
      end
      competition_cc_ids_overdone = competition_cc_ids_done - competition_cc_ids_todo
      unless competition_cc_ids_overdone.blank?
        raise_err_msg("synchronize_season_structure", "more competions_cc_ids with context #{context} than expected in CC: #{CompetitionCc.where(id: competition_cc_ids_overdone).map(&:cc_id)}")
      end
    end
  end

  def synchronize_league_structure(session_id)
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = (ENV["CC_REGION"] || "NBV").downcase
      force_cc_update = ENV["CC_UPDATE"] == "true" || false
      region = Region.find_by_shortname(context.upcase)
      region_cc = region.region_cc

      unless region_cc.blank?
        leagues_region_todo = League.joins(:league_teams => :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where("clubs.region_id = ?", region.id).uniq
        dbu_region = Region.find_by_shortname("portal")
        dbu_leagues_todo = League.joins(:league_teams => :club).where(season: season, organizer_type: "Region", organizer_id: dbu_region.id).where("clubs.region_id = ?", region.id).uniq
        leagues_todo_ids = (leagues_region_todo.to_a + dbu_leagues_todo.to_a).map(&:id)
        leagues_done_ids = region_cc.sync_leagues(season_name).map(&:id)
      else
        raise_err_msg("synchronize_league_structure", "unknown context Region #{context}")
      end
      leagues_still_todo_ids = leagues_todo_ids - leagues_done_ids
      unless leagues_still_todo_ids.blank?
        if force_cc_update
          leagues_still_todo_ids.each do |league_id|
            league = League[league_id]
            unless league.blank?
              league_cc = LeagueCc.create_from_ba(league)
            else
              raise_err_msg("synchronize_league_structure", "no league with id #{league_id}")
            end
          end
        else
          Rails.logger.warn "REPORT! [synchronize_league_structure] Ligen für Season #{season_name} nicht definiert in CC #{League.where(id: leagues_still_todo_ids).map { |league| "#{league.name}[#{league.id}] - #{league.discipline.andand.name}" }}"
        end
      end
      league_ids_overdone = leagues_done_ids - leagues_todo_ids
      unless league_ids_overdone.blank?
        raise_err_msg("synchronize_league_structure", "more league_ids with context #{context} than expected in CC: #{League.where(id: league_ids_overdone).map { |league| "#{league.name}[#{league.id}] - #{league.discipline.andand.name}" }}")
      end
    end
  end

  def synchronize_club_structure(session_id)
    context = (ENV["CC_REGION"] || "NBV").downcase
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc
    clubs_todo_ids = Club.where(region: region).map(&:id)
    clubs_done_ids = region_cc.sync_clubs(context).map(&:id)
    club_ids_still_todo = clubs_todo_ids - clubs_done_ids
    unless club_ids_still_todo.blank?
      Rails.logger.warn "REPORT! [synchronize_club_structure] Club bislang nicht in CC: #{Club.where(id: club_ids_still_todo).map { |ccc| "#{ccc.name}[#{ccc.id}]" }}"
    end
    club_ids_overdone = clubs_done_ids - clubs_todo_ids
    unless club_ids_overdone.blank?
      raise_err_msg("synchronize_club_structure", "more club_cc_ids with context than expected in CC: #{Club.where(id: club_ids_still_todo).map { |ccc| "#{ccc.name}[#{ccc.id}]" }}")
    end
  end

  def synchronize_league_team_structure(session_id)
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = (ENV["CC_REGION"] || "NBV").downcase
      force_cc_update = ENV["CC_UPDATE"] == "true" || false
      region = Region.find_by_shortname(context.upcase)
      region_cc = region.region_cc

      unless region_cc.blank?
        dbu_region = Region.find_by_shortname("portal")
        league_teams_by_region_todo = LeagueTeam.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
        league_teams_todo_ids = league_teams_by_region_todo.to_a.map(&:id)
        league_teams_done_ids = region_cc.sync_league_teams(season_name).map(&:id)
      else
        raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
      end
      league_teams_still_todo_ids = league_teams_todo_ids.uniq.sort - league_teams_done_ids.uniq.sort
      unless league_teams_still_todo_ids.blank?
        if force_cc_update
          league_teams_still_todo_ids.each do |league_team_id|
            league_team = LeagueTeam[league_team_id]
            unless league.blank?
              league_team_cc = LeagueTeamCc.create_from_ba(league_team)
            else
              raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
            end
          end
        else
          Rails.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{season_name} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}"
        end
      end
      league_teams_overdone_ids = league_teams_done_ids - league_teams_todo_ids
      unless league_teams_overdone_ids.blank?
        raise_err_msg("synchronize_league_team_structure", "more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: league_teams_overdone_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}")
      end
    end
  end

  def synchronize_party_structure(session_id)
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = (ENV["CC_REGION"] || "NBV").downcase
      force_cc_update = ENV["CC_UPDATE"] == "true" || false
      region = Region.find_by_shortname(context.upcase)
      region_cc = region.region_cc

      unless region_cc.blank?
        dbu_region = Region.find_by_shortname("portal")
        parties_by_region_todo = Party.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
        parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
        parties_done, party_ccs = region_cc.sync_parties(season_name)
        parties_done_ids = parties_done.map(&:id)
      else
        raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
      end
      parties_still_todo_ids = parties_todo_ids.uniq.sort - parties_done_ids.uniq.sort
      unless parties_still_todo_ids.blank?
        if force_cc_update
          parties_still_todo_ids.each do |party_id|
            party = Party[party_id]
            unless party.blank?
              party_cc = PartyCc.create_from_ba(session_id, party)
            else
              raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
            end
          end
        else
          incomplete_leagues = League.joins(:parties).where(parties: { id: parties_still_todo_ids }).uniq
          Rails.logger.warn "REPORT! [synchronize_league_team_structure] Einige Spielpläne für Season #{season_name} nicht definiert in CC für Ligen #{incomplete_leagues.map { |league| [league.name, league.branch.name] }}"
        end
      end
      parties_overdone_ids = parties_done_ids - parties_todo_ids
      unless parties_overdone_ids.blank?
        raise_err_msg("synchronize_league_team_structure", "more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: parties_overdone_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}")
      end
    end
  end

  def synchronize_party_game_structure(session_id)
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = (ENV["CC_REGION"] || "NBV").downcase
      force_cc_update = ENV["CC_UPDATE"] == "true" || false
      region = Region.find_by_shortname(context.upcase)
      region_cc = region.region_cc

      BranchCc.where(context: context).each do |branch_cc|
        branch_cc.competition_ccs.each do |competition_cc|
          competition_cc.season_ccs.each do |season_cc|
            next unless season_cc.name == season.name
            season_cc.league_ccs.order(:cc_id).each do |league_cc|
              league_cc.party_ccs.each do |party_cc|
                #get Spielplan
                _, doc = post_cc(
                  "admin_report_showLeague",
                  session_id,
                  branchId: party_cc.branchId,
                  fedId: party_cc.fedId,
                  subBranchId: party_cc.subBranchId,
                  seasonId: party_cc.seasonId,
                  leagueId: party_cc.leagueId
                )
                doc.inspect
              end
            end
          end
        end
      end
      # unless region_cc.blank?
      #   dbu_region = Region.find_by_shortname("portal")
      #   parties_by_region_todo = Party.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
      #   parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
      #   parties_done, party_ccs = region_cc.sync_parties(season_name)
      #   parties_done_ids = parties_done.map(&:id)
      # else
      #   raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
      # end
      # parties_still_todo_ids = parties_todo_ids.uniq.sort - parties_done_ids.uniq.sort
      # unless parties_still_todo_ids.blank?
      #   if force_cc_update
      #     parties_still_todo_ids.each do |party_id|
      #       party = Party[party_id]
      #       unless party.blank?
      #         party_cc = PartyCc.create_from_ba(party)
      #       else
      #         raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
      #       end
      #     end
      #   else
      #     incomplete_leagues = League.joins(:parties).where(parties: { id: parties_still_todo_ids }).uniq
      #     Rails.logger.warn "REPORT! [synchronize_league_team_structure] Einige Spielpläne für Season #{season_name} nicht definiert in CC für Ligen #{incomplete_leagues.map { |league| [league.name, league.branch.name] }}"
      #   end
      # end
      # parties_overdone_ids = parties_done_ids - parties_todo_ids
      # unless parties_overdone_ids.blank?
      #   raise_err_msg("synchronize_league_team_structure", "more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: parties_overdone_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}")
      # end
    end
  end

  def synchronize_team_players_structure(session_id)
    ["2010/2011"].each do |season_name|
      season = Season.find_by_name(season_name)
      if season.blank?
        raise ArgumentError, "unknown season name #{season_name}", caller
      end
      context = (ENV["CC_REGION"] || "NBV").downcase
      force_cc_update = ENV["CC_UPDATE"] == "true" || false
      region = Region.find_by_shortname(context.upcase)
      region_cc = region.region_cc

      League.where(season: season, organizer_type: "Region", organizer_id: region.id).each do |league|
        league_team_players = {}
        league.parties.each do |party|
          league_team_players[party.league_team_a_id] ||= []
          league_team_players[party.league_team_b_id] ||= []
          party.party_games.each do |party_game|
            if !league_team_players[party.league_team_a_id].include?(party_game.player_a_id)
              league_team_players[party.league_team_a_id].push(party_game.player_a_id)
            end
            if !league_team_players[party.league_team_b_id].include?(party_game.player_b_id)
              league_team_players[party.league_team_b_id].push(party_game.player_b_id)
            end
          end
        end
        league_team_player_object_hash = {}
        league_team_players.keys.each do |lt_id|
          league_team = LeagueTeam[lt_id]
          league_team_player_object_hash[league_team.id] ||= []
          league_team_players[lt_id].each do |p_id|
            player = Player[p_id]
            league_team_player_object_hash[league_team.id].push(player)
          end
        end
        league_team_player_object_hash.keys.each do |lt_id|
          league_team = LeagueTeam[lt_id]
          league_team_cc = league_team.league_team_cc
          if league_team_cc.present?
            league_team_players_todo = league_team_player_object_hash[lt_id]
            league_team_player_done = region_cc.sync_team_players(league_team, context)
            league_team_player_still_todo = league_team_players_todo - league_team_player_done
            league_team_player_still_todo.each do |player|
              if force_cc_update
                unless player.ba_id > 999000000 || player.ba_id.blank?
                  _, doc = region_cc.post_cc(
                    "showLeague_add_teamplayer",
                    session_id,
                    fedId: league_team_cc.fedId,
                    leagueId: league_team_cc.leagueId,
                    staffelId: 0,
                    branchId: league_team_cc.branchId,
                    subBranchId: league_team_cc.subBranchId,
                    seasonId: league_team_cc.seasonId,
                    p: league_team_cc.p,
                    passnr: player.ba_id,
                    )
                  doc
                else
                  Rails.logger.info "REPORT! [synchronize_team_players_structure] BA-unbekannter Spieler #{player.fullname}(Player[#{player.id}]) aus LeagueTeam[#{league_team.id}] #{league_team.andand.name} in Liga[#{league_team.league.id}]#{league_team.league.name} nicht in CC"
                end
              end
            end
          else
            Rails.logger.info "REPORT! [synchronize_team_players_structure] LeagueTeam #{league_team.andand.name} in Liga #{league_team.league.andand.name} nicht in CC"
          end
        end

      end
    end
  end

  private

  def raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg}"
    raise ArgumentError, msg, caller
  end
end
