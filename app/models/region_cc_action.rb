class RegionCcAction
  def self.get_base_opts_from_environment
    session_id = ENV["PHPSESSID"].presence || Setting.key_get_value("session_id")
    context = (ENV["CC_REGION"].andand.upcase.presence || Setting.key_get_value("context") || "NBV").downcase
    season_name = ENV["CC_SEASON"].presence || Setting.key_get_value(:season_name)
    force_update = (ENV["CC_UPDATE"].presence || Setting.key_get_value("force_update").presence) == "true"
    # exclude_season_names = ["2009/2010", "2010/2011", "2011/2012", "2012/2013", "2013/2014", "2014/2015", "2015/2016",
    #                         "2019/2020", "2020/2021"]
    exclude_season_names = %w[2009/2010 2010/2011 2011/2012 2012/2013 2013/2014 2014/2015 2015/2016 2016/2017 2017/2018 2018/2019 2019/2020 2020/2021 2021/2022]
    pool_ba_ids = League
                  .joins(:discipline)
                  .where(organizer_id: [1, 17])
                  .where("disciplines.name ilike '%Pool%'")
                  .map(&:ba_id)
    snooker_ba_ids = League
                     .joins(:discipline)
                     .where(organizer_id: [1, 17])
                     .where("disciplines.name ilike '%Snooker%'")
                     .map(&:ba_id)
    karambol_ba_ids = League
                      .joins(:discipline)
                      .where(organizer_id: [1, 17])
                      .where("disciplines.name ilike '%Karambol%'").
                      # where.not("leagues.name ilike '%NDMM Dreiband MB%'").
                      map(&:ba_id) - [1826]
    exclude_league_ba_ids = pool_ba_ids + snooker_ba_ids + karambol_ba_ids
    pool_ba_ids = TournamentCc
                  .joins(:tournament)
                  .joins(:branch_cc)
                  .where(season: exclude_season_names)
                  .where(tournaments: { organizer_id: [1, 17] })
                  .where("branch_ccs.name ilike '%Pool%'")
                  .map(&:tournament).map(&:ba_id)
    snooker_ba_ids = TournamentCc
                     .joins(:tournament)
                     .joins(:branch_cc)
                     .where(season: exclude_season_names)
                     .where(tournaments: { organizer_id: [1, 17] })
                     .where("branch_ccs.name ilike '%Snooker%'")
                     .map(&:tournament).map(&:ba_id)
    karambol_ba_ids = TournamentCc
                      .joins(:tournament)
                      .joins(:branch_cc)
                      .where(season: exclude_season_names)
                      .where(tournaments: { organizer_id: [1, 17] })
                      .where("branch_ccs.name ilike '%Karambol%'").
                      # where.not("leagues.name ilike '%NDMM Dreiband MB%'").
                      map(&:tournament).map(&:ba_id)
    exclude_tournament_ba_ids = pool_ba_ids + snooker_ba_ids + karambol_ba_ids

    { session_id: session_id, armed: force_update, context: context, season_name: season_name,
      exclude_season_names: exclude_season_names, exclude_league_ba_ids: exclude_league_ba_ids, exclude_tournament_ba_ids: exclude_tournament_ba_ids }
  end

  def self.remove_local_objects(opts)
    if opts[:armed]
      RegionCc.where("id > 50000000").delete_all
      BranchCc.where("id > 50000000").delete_all
      CompetitionCc.where("id > 50000000").delete_all
      GamePlanCc.where("id > 50000000").delete_all
      GamePlanRowCc.where("id > 50000000").delete_all
      LeagueCc.where("id > 50000000").delete_all
      LeagueTeamCc.where("id > 50000000").delete_all
      PartyCc.where("id > 50000000").delete_all
      PartyGameCc.where("id > 50000000").delete_all
      SeasonCc.where("id > 50000000").delete_all
      ChampionshipTypeCc.where("id > 50000000").delete_all
      CategoryCc.where("id > 50000000").delete_all
      GroupCc.where("id > 50000000").delete_all
      RegistrationListCc.where("id > 50000000").delete_all
      RegistrationCc.where("id > 50000000").delete_all
      TournamentCc.where("id > 50000000").delete_all

    else
      RegionCc.logger.info "REPORT WARNING !!! WILL delete
RegionCc[#{RegionCc.where("id > 50000000").ids}]
BranchCc[#{BranchCc.where("id > 50000000").ids}]
CompetitionCc[#{CompetitionCc.where("id > 50000000").ids}]
GamePlanCc[#{GamePlanCc.where("id > 50000000").ids}]
GamePlanRowCc[#{GamePlanRowCc.where("id > 50000000").ids}]
LeagueCc[#{LeagueCc.where("id > 50000000").ids}]
LeagueTeamCc[#{LeagueTeamCc.where("id > 50000000").ids}]
PartyCc[#{PartyCc.where("id > 50000000").ids}]
PartyGameCc[#{PartyGameCc.where("id > 50000000").ids}]
SeasonCc[#{SeasonCc.where("id > 50000000").ids}]
ChampionshipTypeCc[#{ChampionshipTypeCc.where("id > 50000000").ids}]
CategoryCc[#{CategoryCc.where("id > 50000000").ids}]
GroupCc[#{GroupCc.where("id > 50000000").ids}]
RegistrationListCc[#{RegistrationListCc.where("id > 50000000").ids}]
RegistrationCc[#{RegistrationCc.where("id > 50000000").ids}]
TournamentCc[#{TournamentCc.where("id > 50000000").ids}]
"
    end
  end

  def self.synchronize_region_structure(opts = {})
    regions_todo = []
    regions_done = []
    context = opts[:context]
    region = Region.find_by_shortname(context.upcase)
    if region.blank?
      raise_err_msg("synchronize_region_structure", "unknown context Region #{context}")
    else
      regions_todo = [region.id]
      regions_done = RegionCc.sync_regions(opts)&.map(&:id).to_a
    end
    regions_still_todo = regions_todo - regions_done
    unless regions_still_todo.blank?
      raise_err_msg("synchronize_region_structure",
                    "regions with context #{context} not yet in CC: #{Region.where(id: regions_todo).map(&:name)}")
    end
    regions_overdone = regions_done - regions_todo
    return if regions_overdone.blank?

    raise_err_msg("synchronize_region_structure",
                  "more regions with context #{context} than expected in CC: #{Region.where(id: regions_overdone).map(&:name)}")
  end

  def self.sync_team_players_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    raise ArgumentError unless region_cc.present?

    region_cc.sync_team_players_structure(opts)
  end

  def self.synchronize_game_plan_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    raise ArgumentError unless region_cc.present?

    region_cc.sync_game_plans(opts)
  end

  def self.sync_game_details(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    raise ArgumentError unless region_cc.present?

    region_cc.sync_game_details(opts)
  end

  def self.synchronize_branch_structure(opts = {})
    branches_todo = []
    branches_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    if region_cc.blank?
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    else
      branches_todo = Branch.all.ids
      branches_done = region_cc.sync_branches(opts).map(&:id)
    end
    branches_still_todo = branches_todo - branches_done
    unless branches_still_todo.blank?
      raise_err_msg("synchronize_branch_structure",
                    "branches with context #{context} not yet in CC: #{Branch.where(id: branches_todo).map(&:name)}")
    end
    branches_overdone = branches_done - branches_todo
    return if branches_overdone.blank?

    raise_err_msg("synchronize_branch_structure",
                  "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
  end

  def self.synchronize_competition_structure(opts = {})
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    if region_cc.blank?
      raise_err_msg("synchronize_branch_structure", "unknown context Region #{context}")
    else
      competitions_todo = Competition.all.ids
      competitions_done = region_cc.sync_competitions(opts).map(&:id)
    end
    competitions_still_todo = competitions_todo - competitions_done
    unless competitions_still_todo.blank?
      raise_err_msg("synchronize_branch_structure",
                    "branches with context #{context} not yet in CC: #{Branch.where(id: competitions_todo).map(&:name)}")
    end
    branches_overdone = competitions_done - competitions_todo
    return if branches_overdone.blank?

    raise_err_msg("synchronize_branch_structure",
                  "more branches with context #{context} than expected in CC: #{Branch.where(id: branches_overdone).map(&:name)}")
  end

  def self.synchronize_season_structure(opts = {})
    context = opts[:context]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc
    if region_cc.blank?
      raise_err_msg("synchronize_season_structure", "unknown context Region #{context}")
    else
      competition_cc_ids_todo = CompetitionCc.where(context: context).all.map(&:cc_id)
      competition_cc_ids_done = region_cc.sync_seasons_in_competitions(opts).map(&:cc_id)
    end
    competition_cc_ids_still_todo = competition_cc_ids_todo - competition_cc_ids_done
    unless competition_cc_ids_still_todo.blank?

      Rails.logger.warn "REPORT! [synchronize_season_structure] Saison #{opts[:season_name]} nicht definiert für Wettbewerbe #{CompetitionCc.where(cc_id: competition_cc_ids_still_todo).map { |ccc|
        "#{ccc.branch_cc.name} - #{ccc.name} (#{ccc.cc_id})"
      }}"
    end
    competition_cc_ids_overdone = competition_cc_ids_done - competition_cc_ids_todo
    return if competition_cc_ids_overdone.blank?

    raise_err_msg("synchronize_season_structure",
                  "more competions_cc_ids with context #{context} than expected in CC: #{CompetitionCc.where(id: competition_cc_ids_overdone).map(&:cc_id)}")
  end

  def self.synchronize_league_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.synchronize_league_structure(opts)
  end

  def self.synchronize_league_plan_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.synchronize_league_plan_structure(opts)
  end

  def self.synchronize_club_structure(opts = {})
    context = (ENV["CC_REGION"] || "NBV").downcase
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc
    clubs_todo_ids = Club.where(region: region).map(&:id)
    clubs_done_ids = region_cc.sync_clubs(opts).map(&:id)
    club_ids_still_todo = clubs_todo_ids - clubs_done_ids
    unless club_ids_still_todo.blank?
      Rails.logger.warn "REPORT! [synchronize_club_structure] Club bislang nicht in CC: #{Club.where(id: club_ids_still_todo).map { |ccc|
        "#{ccc.name}[#{ccc.id}]"
      }}"
    end
    club_ids_overdone = clubs_done_ids - clubs_todo_ids
    return if club_ids_overdone.blank?

    raise_err_msg("synchronize_club_structure", "more club_cc_ids with context than expected in CC: #{Club.where(id: club_ids_still_todo).map do |ccc|
      "#{ccc.name}[#{ccc.id}]"
    end}")
  end

  def self.synchronize_league_team_structure_new(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    context = opts[:context]
    force_cc_update = opts[:armed]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    if region_cc.blank?
      raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
    else
      league_teams_by_region_todo = LeagueTeam.joins(league: { league_teams: :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id] }).where(
        "clubs.region_id = ?", region.id
      ).where.not(league: { ba_id: opts[:exclude_league_ba_ids] }).uniq
      league_teams_todo_ids = league_teams_by_region_todo.to_a.map(&:id)
      league_teams_done, = region_cc.sync_league_teams_new(opts)
      league_teams_done_ids = league_teams_done.map(&:id)
    end
    league_teams_still_todo_ids = league_teams_todo_ids&.uniq&.sort.to_a - league_teams_done_ids&.uniq&.sort.to_a
    unless league_teams_still_todo_ids.blank?
      if force_cc_update
        league_teams_still_todo_ids.each do |league_team_id|
          league_team = LeagueTeam[league_team_id]
          if !league_team.blank?
            LeagueTeamCc.create_from_ba(league_team)
          else
            raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
          end
        end
      else
        Rails.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{opts[:season_name]} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids)
          .map { |league_team|
                                                                                                                                            "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
                                                                                                                                          }}"
        RegionCc.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{opts[:season_name]} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids).map { |league_team|
          "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
        }}"
      end
    end
    league_teams_overdone_ids = league_teams_done_ids - league_teams_todo_ids
    return if league_teams_overdone_ids.blank?

    RegionCc.logger.info "REPORT [synchronize_league_team_structure] more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: league_teams_overdone_ids).map { |league_team|
      "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
    }}"
  end

  def self.synchronize_league_team_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    context = opts[:context]
    force_cc_update = opts[:armed]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    if region_cc.blank?
      raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
    else
      # dbu_region = Region.find_by_shortname("DBU")

      # no dbu !!! league_teams_by_region_todo = LeagueTeam.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
      league_teams_by_region_todo = LeagueTeam.joins(league: { league_teams: :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id] }).where(
        "clubs.region_id = ?", region.id
      ).where.not(league: { ba_id: opts[:exclude_league_ba_ids] }).uniq
      league_teams_todo_ids = league_teams_by_region_todo.to_a.map(&:id)
      league_teams_done, = region_cc.sync_league_teams(opts)
      league_teams_done_ids = league_teams_done.map(&:id)
    end
    league_teams_still_todo_ids = league_teams_todo_ids&.uniq&.sort.to_a - league_teams_done_ids&.uniq&.sort.to_a
    unless league_teams_still_todo_ids.blank?
      if force_cc_update
        league_teams_still_todo_ids.each do |league_team_id|
          league_team = LeagueTeam[league_team_id]
          if !league_team.blank?
            LeagueTeamCc.create_from_ba(league_team)
          else
            raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
          end
        end
      else
        Rails.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{opts[:season_name]} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids).map { |league_team|
          "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
        }}"
        RegionCc.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{opts[:season_name]} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids).map { |league_team|
          "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
        }}"
      end
    end
    league_teams_overdone_ids = league_teams_done_ids - league_teams_todo_ids
    return if league_teams_overdone_ids.blank?

    RegionCc.logger.info "REPORT [synchronize_league_team_structure] more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: league_teams_overdone_ids).map { |league_team|
      "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
    }}"
  end

  def self.synchronize_party_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    context = opts[:context]
    force_cc_update = opts[:armed]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    if region_cc.blank?
      raise_err_msg("synchronize_party_structure", "unknown context Region #{context}")
    else
      dbu_region = Region.find_by_shortname("DBU")
      parties_by_region_todo = Party.joins(league: { league_teams: :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where(
        "clubs.region_id = ?", region.id
      ).uniq
      parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
      parties_done, = region_cc.sync_parties(opts)
      parties_done_ids = parties_done.map(&:id)
    end
    parties_still_todo_ids = parties_todo_ids&.uniq&.sort.to_a - parties_done_ids&.uniq&.sort.to_a
    unless parties_still_todo_ids.blank?
      if force_cc_update
        parties_still_todo_ids.each do |party_id|
          party = Party[party_id]
          if party.blank?
            raise_err_msg("synchronize_party_structure", "no party with id #{party_id}")
          else
            PartyCc.create_from_ba(party)
          end
        end
      else
        incomplete_leagues = League.joins(:parties).where(parties: { id: parties_still_todo_ids }).uniq
        Rails.logger.warn "REPORT! [synchronize_league_team_structure] Einige Spielpläne für Season #{opts[:season_name]} nicht definiert in CC für Ligen #{incomplete_leagues.select { |league|
          league.organizer_id == region.id && league.organizer_type == "Region"
        }.map { |league|
          [league.name,
           league.discipline.andand.name]
        }}"
        RegionCc.logger.warn "REPORT! WARNING Einige Spielpläne für Season #{opts[:season_name]} nicht definiert in CC für Ligen #{incomplete_leagues.select { |league|
          league.organizer_id == region.id && league.organizer_type == "Region"
        }.map { |league|
          [league.name,
           league.discipline.andand.name]
        }}"
      end
    end
    parties_overdone_ids = parties_done_ids - parties_todo_ids
    return if parties_overdone_ids.blank?

    raise_err_msg("synchronize_party_structure", "more league_team_ids with context #{context} than expected in CC: #{Party.where(id: parties_overdone_ids).map do |party|
      "#{party.name}[#{party.id}]"
    end}")
  end

  def self.synchronize_party_game_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    context = (ENV["CC_REGION"] || "NBV").downcase
    force_cc_update = opts[:armed].presence || ENV["CC_UPDATE"] == "true" || false
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    if region_cc.blank?
      raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
    else
      dbu_region = Region.find_by_shortname("DBU")
      parties_by_region_todo = Party.joins(league: { league_teams: :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where(
        "clubs.region_id = ?", region.id
      ).uniq
      parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
      parties_done = region_cc.sync_party_games(parties_todo_ids, opts)
      parties_done_ids = parties_done.map(&:id)
    end
    parties_still_todo_ids = parties_todo_ids&.uniq&.sort.to_a - parties_done_ids&.uniq&.sort.to_a
    unless parties_still_todo_ids.blank?
      parties_still_todo_ids.each do |party_id|
        party = Party[party_id]
        if party.blank?
          raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
        else
          PartyGameCc.fix_party_games(party, armed: force_cc_update)
        end
      end
    end
    parties_overdone_ids = parties_done_ids - parties_todo_ids
    return if parties_overdone_ids.blank?

    raise_err_msg("synchronize_league_team_structure", "more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: parties_overdone_ids).map do |league_team|
      "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}"
    end}")
  end

  def self.raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg}"
    raise ArgumentError, msg, caller
  end
end
