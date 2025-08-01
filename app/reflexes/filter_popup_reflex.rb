# frozen_string_literal: true

class FilterPopupReflex < ApplicationReflex
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
                  .pluck(:shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}" }
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
                  .pluck(:shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}" }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
    else
      club_options = []
    end
    
    morph '#club-dropdown-players', render(partial: 'shared/club_dropdown_options', locals: { clubs: club_options })
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