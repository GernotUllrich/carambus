# frozen_string_literal: true

class FilterPopupReflex < ApplicationReflex
  def filter_clubs_by_region_for_clubs
    # Get the region value from the triggering element
    region_shortname = element.value
    
    if region_shortname.present?
      clubs = Club.joins(:region)
                  .where(regions: { shortname: region_shortname })
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(100)
                  .pluck(:id, :shortname, :name, 'regions.shortname')

      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact

      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    else
      # If no region selected, show all clubs
      clubs = Club.joins(:region)
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(50)
                  .pluck(:id, :shortname, :name, 'regions.shortname')

      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact

      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    end

    # Morph the club dropdown
    morph '#club-dropdown', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
  end

  def filter_clubs_by_region
    # Get the region value from the triggering element
    region_shortname = element.value
    
    if region_shortname.present?
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .where(regions: { shortname: region_shortname })
                  .order(:shortname)
                  .limit(100)

      club_options = clubs.map do |club|
        display_name = club.name.present? ? "#{club.shortname} (#{club.name})" : club.shortname
        region_info = club.region&.shortname.present? ? " - #{club.region.shortname}" : ""
        { value: club.shortname, label: "#{display_name}#{region_info}" }
      end

      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    else
      # If no region selected, show all clubs
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(50)

      club_options = clubs.map do |club|
        display_name = club.name.present? ? "#{club.shortname} (#{club.name})" : club.shortname
        region_info = club.region&.shortname.present? ? " - #{club.region.shortname}" : ""
        { value: club.shortname, label: "#{display_name}#{region_info}" }
      end

      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    end

    # Morph the club dropdown
    morph '#club-dropdown', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
  end

  def filter_clubs_by_region_for_locations
    region_shortname = element.value
    
    if region_shortname.present?
      clubs = Club.joins(:region)
                  .where(regions: { shortname: region_shortname })
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(50)
                  .pluck(:id, :shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    else
      club_options = []
    end
    
    morph '#club-dropdown-locations', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
  end

  def filter_clubs_by_region_for_players
    region_shortname = element.value
    
    if region_shortname.present?
      clubs = Club.joins(:region)
                  .where(regions: { shortname: region_shortname })
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(50)
                  .pluck(:id, :shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    else
      club_options = []
    end
    
    morph '#club-dropdown-players', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
  end

  def filter_seasons_by_region_for_party_games
    region_shortname = element.value
    
    if region_shortname.present?
      # Use all available seasons ordered by ID descending to avoid polymorphic eager loading issues
      seasons = Season.where.not(name: [nil, ''])
                     .order(id: :desc)
                     .limit(50)
      
      season_options = seasons.map do |season|
        next if season.name.blank?
        { value: season.name, label: season.name, id: season.id }
      end.compact
      
      season_options.sort_by! { |option| option[:label].downcase }
    else
      season_options = []
    end
    
    morph '#season-dropdown-party-games', render(partial: 'shared/season_dropdown_options', locals: { seasons: season_options })
  end

  def filter_leagues_by_season_for_party_games
    season_name = element.value
    
    if season_name.present?
      season = Season.find_by(name: season_name)
      if season
        leagues = League.where(season: season)
                       .where.not(shortname: [nil, ''])
                       .order(:shortname)
                       .limit(50)
                       .includes(:organizer)
        
        league_options = leagues.map do |league|
          next if league.shortname.blank?
          display_name = league.name.present? ? "#{league.shortname} (#{league.name})" : league.shortname
          season_info = league.season&.name.present? ? " - #{league.season.name}" : ""
          { value: league.shortname, label: "#{display_name}#{season_info}", id: league.id }
        end.compact
        
        league_options.sort_by! { |option| option[:label].downcase }
      else
        league_options = []
      end
    else
      league_options = []
    end
    
    morph '#league-dropdown-party-games', render(partial: 'shared/league_dropdown_options', locals: { leagues: league_options })
  end

  def filter_parties_by_league_for_party_games
    league_shortname = element.value
    
    if league_shortname.present?
      league = League.find_by(shortname: league_shortname)
      if league
        parties = Party.where(league: league)
                      .where.not(day_seqno: nil)
                      .order(:day_seqno)
                      .limit(50)
                      .includes(:league)
        
        party_options = parties.map do |party|
          next if party.day_seqno.nil?
          # Use the party name which shows league team names
          display_name = party.name.present? ? party.name : "Party #{party.day_seqno}"
          league_info = party.league&.shortname.present? ? " (#{party.league.shortname})" : ""
          { value: party.id, label: "#{display_name}#{league_info}", id: party.id }
        end.compact
        
        party_options.sort_by! { |option| option[:label].downcase }
      else
        party_options = []
      end
    else
      party_options = []
    end
    
    morph '#party-dropdown-party-games', render(partial: 'shared/party_dropdown_options', locals: { parties: party_options })
  end

  def save_recent_selection
    field_key = element.dataset[:fieldKey]
    value = element.dataset[:value]
    
    if field_key.present? && value.present?
      # Store in session for server-side access
      session["filter_recent_#{field_key}"] ||= []
      recent = session["filter_recent_#{field_key}"]
      recent.delete(value)
      recent.unshift(value)
      recent = recent.first(5) # Keep only last 5
      session["filter_recent_#{field_key}"] = recent
    end
  end
end 