class RegionCcAction
  def self.synchronize_region_structure(opts = {})
    regions_todo = []
    regions_done = []
    context = opts[:context]
    region = Region.find_by_shortname(context.upcase)
    unless region.blank?
      regions_todo = [region.id]
      regions_done = RegionCc.sync_regions(opts).map(&:id)
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

  def self.sync_team_players_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    if region_cc.present?
      region_cc.sync_team_players_structure(opts)
    else
      raise ArgumentError
    end
  end

  def self.synchronize_game_plan_structure(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    if region_cc.present?
      region_cc.sync_game_plans(opts)
    else
      raise ArgumentError
    end
  end

  def self.sync_game_details(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    if region_cc.present?
      region_cc.sync_game_details(opts)
    else
      raise ArgumentError
    end
  end

  def self.synchronize_branch_structure(opts = {})
    branches_todo = []
    branches_done = []
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      branches_todo = Branch.all.ids
      branches_done = region_cc.sync_branches(opts).map(&:id)
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

  def self.synchronize_competition_structure(opts = {})
    context = ENV["REGION"] || "NBV"
    region = Region.find_by_shortname(context)
    region_cc = region.region_cc
    unless region_cc.blank?
      competitions_todo = Competition.all.ids
      competitions_done = region_cc.sync_competitions(opts).map(&:id)
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

  def self.synchronize_season_structure(opts = {})
    context = opts[:context]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc
    unless region_cc.blank?
      competition_cc_ids_todo = CompetitionCc.where(context: context).all.map(&:cc_id)
      competition_cc_ids_done = region_cc.sync_seasons_in_competitions(opts).map(&:cc_id)
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

  def synchronize_club_structure(opts = {})
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

  def self.synchronize_league_team_structure(opts = {})
    season_name = opts[:season_name]
    season = Season.find_by_name(opts[:season_name])
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    context = opts[:context]
    force_cc_update = opts[:armed]
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    unless region_cc.blank?
      #dbu_region = Region.find_by_shortname("portal")

      # no dbu !!! league_teams_by_region_todo = LeagueTeam.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
      league_teams_by_region_todo = LeagueTeam.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id] }).where("clubs.region_id = ?", region.id).uniq
      league_teams_todo_ids = league_teams_by_region_todo.to_a.map(&:id)
      league_teams_done, league_team_ccs = region_cc.sync_league_teams(opts)
      league_teams_done_ids = league_teams_done.map(&:id)
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
        RegionCc.logger.warn "REPORT! [synchronize_league_team_structure] LigaTeams für Season #{season_name} nicht definiert in CC #{LeagueTeam.where(id: league_teams_still_todo_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}"
      end
    end
    league_teams_overdone_ids = league_teams_done_ids - league_teams_todo_ids
    unless league_teams_overdone_ids.blank?
      RegionCc.logger.warn "REPORT! [synchronize_league_team_structure] more league_team_ids #{league_teams_overdone_ids} with context #{context} than expected in CC: #{LeagueTeam.where(id: league_teams_overdone_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}"
    end
  end

  def self.synchronize_party_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    season_name = season.name
    context = (ENV["CC_REGION"] || "NBV").downcase
    force_cc_update = opts[:armed].presence || ENV["CC_UPDATE"] == "true" || false
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    unless region_cc.blank?
      dbu_region = Region.find_by_shortname("portal")
      parties_by_region_todo = Party.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
      parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
      parties_done, party_ccs = region_cc.sync_parties(opts)
      parties_done_ids = parties_done.map(&:id)
    else
      raise_err_msg("synchronize_party_structure", "unknown context Region #{context}")
    end
    parties_still_todo_ids = parties_todo_ids.uniq.sort - parties_done_ids.uniq.sort
    unless parties_still_todo_ids.blank?
      if force_cc_update
        parties_still_todo_ids.each do |party_id|
          party = Party[party_id]
          unless party.blank?
            party_cc = PartyCc.create_from_ba(party)
          else
            raise_err_msg("synchronize_party_structure", "no party with id #{party_id}")
          end
        end
      else
        incomplete_leagues = League.joins(:parties).where(parties: { id: parties_still_todo_ids }).uniq
        Rails.logger.warn "REPORT! [synchronize_league_team_structure] Einige Spielpläne für Season #{season_name} nicht definiert in CC für Ligen #{incomplete_leagues.select { |league| league.organizer_id == region.id && league.organizer_type == "Region" }.map { |league| [league.name, league.discipline.andand.name] }}"
        RegionCc.logger.warn "REPORT! WARNING Einige Spielpläne für Season #{season_name} nicht definiert in CC für Ligen #{incomplete_leagues.select { |league| league.organizer_id == region.id && league.organizer_type == "Region" }.map { |league| [league.name, league.discipline.andand.name] }}"
      end
    end
    parties_overdone_ids = parties_done_ids - parties_todo_ids
    unless parties_overdone_ids.blank?
      raise_err_msg("synchronize_party_structure", "more league_team_ids with context #{context} than expected in CC: #{Party.where(id: parties_overdone_ids).map { |party| "#{party.name}[#{party.id}]" }}")
    end
  end

  def self.synchronize_party_game_structure(opts = {})
    season = Season.find_by_name(season_name)
    if season.blank?
      raise ArgumentError, "unknown season name #{season_name}", caller
    end
    context = (ENV["CC_REGION"] || "NBV").downcase
    force_cc_update = opts[:armed].presence || ENV["CC_UPDATE"] == "true" || false
    region = Region.find_by_shortname(context.upcase)
    region_cc = region.region_cc

    unless region_cc.blank?
      dbu_region = Region.find_by_shortname("portal")
      parties_by_region_todo = Party.joins(:league => { :league_teams => :club }).where(league: { season: season, organizer_type: "Region", organizer_id: [region.id, dbu_region.id] }).where("clubs.region_id = ?", region.id).uniq
      parties_todo_ids = parties_by_region_todo.to_a.map(&:id)
      parties_done = region_cc.sync_party_games(parties_todo_ids, opts)
      parties_done_ids = parties_done.map(&:id)
    else
      raise_err_msg("synchronize_league_team_structure", "unknown context Region #{context}")
    end
    parties_still_todo_ids = parties_todo_ids.uniq.sort - parties_done_ids.uniq.sort
    unless parties_still_todo_ids.blank?
      parties_still_todo_ids.each do |party_id|
        party = Party[party_id]
        unless party.blank?
          PartyGameCc.fix_party_games(party, armed: force_cc_update)
        else
          raise_err_msg("synchronize_league_team_structure", "no league_team with id #{league_id}")
        end
      end
    end
    parties_overdone_ids = parties_done_ids - parties_todo_ids
    unless parties_overdone_ids.blank?
      raise_err_msg("synchronize_league_team_structure", "more league_team_ids with context #{context} than expected in CC: #{LeagueTeam.where(id: parties_overdone_ids).map { |league_team| "#{league_team.name}[#{league_team.id}] - in Liga #{league_team.league.name} #{league_team.league.discipline.andand.name}" }}")
    end
  end

  def self.raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg}"
    raise ArgumentError, msg, caller
  end
end
