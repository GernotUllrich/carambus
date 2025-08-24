# frozen_string_literal: true

# global helpers
module ApplicationHelper
  include Pagy::Frontend

  # Generates button tags for Turbo disable with
  # Preserve opacity-25 opacity-75 during purge
  def button_text(text = nil, disable_with: t("processing"), &block)
    text = capture(&block) if block

    tag.span(text, class: "when-enabled") +
      tag.span(class: "when-disabled") do
        <<~ICON.html_safe + disable_with
          <svg class="animate-spin inline-block mr-2 h-4 w-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        ICON
      end
  end

  def render_svg(name, options = {})
    options[:title] ||= name.underscore.humanize
    options[:aria] = true
    options[:nocomment] = true
    options[:class] = options.fetch(:styles, "fill-current text-gray-500")

    filename = "#{name}.svg"
    inline_svg_tag(filename, options)
  end

  def my_sanitize(str)
    sanitize(str.to_s, tags: %w[b i br])
  end

  # Font Awesome icon helper
  # fa_icon "thumbs-up", weight: "fa-solid"
  # <i class="fa-solid fa-thumbs-up"></i>
  def fa_icon(name, options = {})
    weight = options.delete(:weight) || "fa-regular"
    options[:class] = [weight, "fa-#{name}", options.delete(:class)]
    tag.i(nil, **options)
  end

  # <%= badge "Active", color: "bg-green-100 text-green-800" %>
  # <%= badge color: "bg-green-100 text-green-800", data: {controller: "tooltip", tooltip_controller_value: "Hello"} do
  #   <svg>...</svg>
  #   Active
  # <% end %>
  def badge(text = nil, options = {}, &block)
    if block
      options = text
      text = nil
    end
    base = options&.delete(:base) || "rounded py-0.5 px-2 text-xs inline-block font-semibold leading-normal mr-2"
    color = options&.delete(:color) || "bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200"
    options[:class] = Array.wrap(options[:class]) + [base, color]
    tag.div(text, **options, &block)
  end

  def title(page_title)
    content_for(:title) { page_title }
  end

  def viewport_meta_tag(content: "width=device-width, initial-scale=1",
                        turbo_native: "maximum-scale=1.0, user-scalable=0")
    full_content = [content, (turbo_native if turbo_native_app?)].compact.join(", ")
    tag.meta name: "viewport", content: full_content
  end

  def first_page?
    @pagy.page == 1
  end

  def markdown(text)
    return unless text

    renderer = Redcarpet::Render::HTML.new(
      filter_html: true,
      hard_wrap: true
    )

    # Explicit extensions hash definition
    extensions = {
      autolink: true,
      tables: true,
      fenced_code_blocks: true
    }

    markdown = Redcarpet::Markdown.new(renderer, extensions)
    markdown.render(text).html_safe
  end

  # Helper method for creating links to documentation pages
  def docs_page_link(path, locale: nil, text: nil, options: {})
    text ||= path.humanize
    locale ||= I18n.locale.to_s
    
    link_to text, docs_page_path(path: path, locale: locale), options
  end

  def custom_link_to(*args, &block)
    begin
      options = block_given? ? args[1] : args[2]
      options = {} unless options.is_a? Hash
      options[:"data-turbo"] = false unless options.key?(:"data-turbo")

      if block_given?
        link_to(capture(&block), args[0], options)
      else
        link_to(args[0], args[1], options)
      end
    rescue StandardError => e
      Rails.logger.debug "#{e} #{e.backtrace.join("\n")}"
    end
  end

  def language_switcher
    available_locales = [:de, :en]
    current_locale = I18n.locale
    
    content_tag :div, class: 'language-switcher' do
      available_locales.map do |locale|
        if locale == current_locale
          content_tag :span, locale.to_s.upcase, class: 'current-locale'
        else
          link_to locale.to_s.upcase, url_for(locale: locale), class: 'locale-link'
        end
      end.join(' | ').html_safe
    end
  end

  # Hilfsmethode für Links zu integrierten Dokumentationsseiten
  def docs_page_link(path, locale: nil, text: nil, options: {})
    locale ||= I18n.locale.to_s
    text ||= path.split('/').last.humanize
    
    link_to text, docs_page_path(path: path, locale: locale), options
  end

  # Hilfsmethode für externe MkDocs-Links
  def mkdocs_link(path, locale: nil, text: nil, options: {})
    locale ||= I18n.locale.to_s
    text ||= path.split('/').last.humanize
    
    # Korrekte URL-Struktur für MkDocs-Seiten
    # Beispiel: path = "about" -> https://gernotullrich.github.io/carambus/about/
    url = "https://gernotullrich.github.io/carambus/#{path}/"
    link_to text, url, options.merge(target: '_blank', rel: 'noopener')
  end

  def debug_translation(key)
    "#{I18n.locale}: #{key} => #{I18n.t(key)}"
  end

  def generate_filter_fields(model_class)
    return [] unless model_class.respond_to?(:search_hash) && model_class.search_hash({})[:column_names].present?

    search_hash = model_class.search_hash({})
    column_names = search_hash[:column_names]

    fields = []
    column_names.each do |display_name, column_def|
      input_type, input_type_name, options = detect_field_type_and_options(column_def, display_name, model_class)
      
      field_key = if column_def.include?('regions.shortname')
                    'region_shortname'
                  elsif column_def.include?('clubs.shortname')
                    'club_shortname'
                  elsif column_def.include?('seasons.name')
                    'season_name'
                  elsif column_def.include?('leagues.shortname')
                    'league_shortname'
                  elsif column_def.include?('parties.id')
                    'party_shortname'
                  elsif column_def.include?('regions.id')
                    'region_id'
                  elsif column_def.include?('seasons.id')
                    'season_id'
                  elsif column_def.include?('clubs.id')
                    'club_id'
                  elsif column_def.include?('leagues.id')
                    'league_id'
                  else
                    column_def.split('.').last
                  end
      max_options = options.is_a?(Array) ? options.length : nil
      
      field = {
        display_name: display_name,
        field_key: field_key,
        column_def: column_def,
        input_type: input_type,
        input_type_name: input_type_name,
        options: options,
        max_options: max_options,
        show_operators: should_show_operators(input_type),
        model_class: model_class
      }
      
      fields << field
    end

    fields
  end

  def render_filter_input(field, value = nil)
    case field[:input_type]
    when 'select'
      render_select_input(field, value)
    when 'autocomplete'
      render_autocomplete_input(field, value)
    when 'date'
      render_date_input(field, value)
    when 'number'
      render_number_input(field, value)
    else
      render_text_input(field, value)
    end
  end

  def render_select_input(field, value)
    options = field[:options] || []
    
    # Add special data attributes for club fields to enable dynamic filtering
    data_attributes = { 
      action: "change->filter-popup#saveRecentSelection",
      field_key: field[:field_key]
    }
    
    # If this is a club field, add data attributes for Stimulus Reflex filtering
    if field[:field_key] == 'shortname'
      # Club field is the target for morphing, no reflex trigger needed
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
    end
    
    # If this is a region field, add data attributes for triggering club filtering
    if field[:field_key] == 'region'
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_clubs_by_region'
    end

    # If this is a region field for locations page, add data attributes for triggering club filtering
    if field[:field_key] == 'region_shortname' && field[:model_class] == Location
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_clubs_by_region_for_locations'
    end

    # If this is a region field for clubs page, add data attributes for triggering club filtering
    if field[:field_key] == 'region_shortname' && field[:model_class] == Club
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_clubs_by_region_for_clubs'
    end

    # If this is a region field for players page, add data attributes for triggering club filtering
    if field[:field_key] == 'region_shortname' && field[:model_class] == Player
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_clubs_by_region_for_players'
    end

    # If this is a region field for party_games page, add data attributes for triggering season filtering
    if field[:field_key] == 'region_shortname' && field[:model_class] == PartyGame
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_seasons_by_region_for_party_games'
    end

    # If this is a season field for party_games page, add data attributes for triggering league filtering
    if field[:field_key] == 'season_name' && field[:model_class] == PartyGame
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_leagues_by_season_for_party_games'
    end

    # If this is a league field for party_games page, add data attributes for triggering party filtering
    if field[:field_key] == 'league_shortname' && field[:model_class] == PartyGame
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
      data_attributes[:reflex] = 'change->FilterPopupReflex#filter_parties_by_league_for_party_games'
    end

    # If this is a party field for party_games page, add data attributes for saving selection
    if field[:field_key] == 'party_shortname' && field[:model_class] == PartyGame
      data_attributes[:action] = "change->filter-popup#saveRecentSelection"
    end
    
    # Build options with data-id attributes for reference fields
    select_options = options.map do |option|
      if option[:id].present?
        # For reference fields, include data-id attribute
        content_tag(:option, option[:label], value: option[:value], 'data-id': option[:id])
      else
        # For non-reference fields, use standard option
        content_tag(:option, option[:label], value: option[:value])
      end
    end.join.html_safe
    
    select_tag field[:field_key], 
      select_options,
      class: "flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm py-1 px-3",
      include_blank: "Select #{field[:display_name]}",
      data: data_attributes,
      id: get_select_id(field)
  end

  def get_select_id(field)
    case field[:field_key]
    when 'region_shortname'
      if field[:model_class] == Location
        'region-dropdown-locations'
      elsif field[:model_class] == Club
        'region-dropdown-clubs'
      elsif field[:model_class] == Player
        'region-dropdown-players'
      elsif field[:model_class] == PartyGame
        'region-dropdown-party-games'
      else
        'region-dropdown'
      end
    when 'club_shortname'
      if field[:model_class] == Location
        'club-dropdown-locations'
      elsif field[:model_class] == Club
        'club-dropdown'
      elsif field[:model_class] == Player
        'club-dropdown-players'
      else
        'club-dropdown'
      end
    when 'season_name'
      if field[:model_class] == PartyGame
        'season-dropdown-party-games'
      else
        'season-dropdown'
      end
    when 'league_shortname'
      if field[:model_class] == PartyGame
        'league-dropdown-party-games'
      else
        'league-dropdown'
      end
    when 'party_shortname'
      if field[:model_class] == PartyGame
        'party-dropdown-party-games'
      else
        'party-dropdown'
      end
    when 'shortname'
      'club-dropdown'
    when 'name'
      'location-dropdown'
    else
      nil
    end
  end

  def render_autocomplete_input(field, value)
    text_field_tag field[:field_key], value,
      class: "flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm py-1 px-3",
      placeholder: field[:options]&.dig(:placeholder) || field[:display_name],
      data: { 
        action: "input->filter-popup#handleAutocomplete",
        endpoint: field[:options]&.dig(:endpoint),
        field_key: field[:field_key]
      }
  end

  def render_date_input(field, value)
    date_field_tag field[:field_key], value,
      class: "flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm py-1 px-3",
      placeholder: field[:display_name],
      data: { 
        action: "change->filter-popup#saveRecentSelection",
        field_key: field[:field_key]
      }
  end

  def render_number_input(field, value)
    css_class = "flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm py-1 px-3"
    css_class += " hidden" if field[:field_key].end_with?('_id') || field[:field_key] == 'id'
    
    number_field_tag field[:field_key], value,
      class: css_class,
      placeholder: field[:display_name],
      data: { 
        action: "change->filter-popup#saveRecentSelection",
        field_key: field[:field_key]
      }
  end

  def render_text_input(field, value)
    css_class = "flex-1 rounded-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-700 dark:text-gray-200 text-sm py-1 px-3"
    css_class += " hidden" if field[:field_key].end_with?('_id') || field[:field_key] == 'id'
    
    text_field_tag field[:field_key], value,
      class: css_class,
      placeholder: field[:display_name],
      data: { 
        action: "change->filter-popup#saveRecentSelection",
        field_key: field[:field_key]
      }
  end

  private

  def detect_field_type_and_options(column_def, display_name, model_class)
    # Date fields
    if column_def =~ /::date$/
      return 'date', 'date', nil
    end

    # Party fields (for PartyGame model) - must be checked before numeric fields
    if column_def.include?('parties.id') && model_class == PartyGame
      # For cascading filters, start with empty options
      # The options will be populated by StimulusReflex when a league is selected
      return 'select', 'select', []
    end

    # Numeric fields
    if column_def =~ /_id$/ || column_def =~ /\.id$/ || column_def =~ /\.balls$/ || column_def =~ /\.innings$/
      return 'number', 'number', nil
    end

    # Region fields
    if column_def.include?('regions.shortname')
      regions = Region.order(:shortname).limit(50).pluck(:id, :shortname, :name)
      region_options = regions.map { |id, shortname, name| { value: shortname, label: "#{shortname} (#{name})", id: id } }
      
      # Sort alphabetically by label
      region_options.sort_by! { |option| option[:label].downcase }
      
      return 'select', 'select', region_options
    end

    # Season fields (for PartyGame model)
    if column_def.include?('seasons.name') && model_class == PartyGame
      # For cascading filters, Season is the first dropdown after Region, so populate with all seasons
      seasons = Season.where.not(name: [nil, ''])
                     .order(id: :desc)
                     .limit(50)
      
      season_options = seasons.map do |season|
        next if season.name.blank?
        { value: season.name, label: season.name, id: season.id }
      end.compact
      
      season_options.sort_by! { |option| option[:label].downcase }
      return 'select', 'select', season_options
    end

    # League fields (for PartyGame model)
    if column_def.include?('leagues.shortname') && model_class == PartyGame
      # For cascading filters, start with empty options
      # The options will be populated by StimulusReflex when a season is selected
      return 'select', 'select', []
    end



    # Location fields with cascading filters
    if column_def.include?('locations.name')
      # For location names, we'll use autocomplete since there are many locations
      return 'text', 'autocomplete', { 
        endpoint: '/api/locations/autocomplete',
        placeholder: 'Search locations...'
      }
    end

    # Location address field
    if column_def.include?('locations.address')
      return 'text', 'text', nil
    end

    # Club fields (for locations page)
    if column_def.include?('clubs.shortname') && model_class == Location
      # For locations page, clubs depend on region selection
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(300)
                  .pluck(:id, :shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
      
      return 'select', 'select', club_options
    end

    # Club fields (for clubs page)
    if column_def.include?('clubs.shortname') && model_class == Club
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(300)
                  .pluck(:id, :shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
      
      return 'select', 'select', club_options
    end

    # Club fields (for players page)
    if column_def.include?('clubs.shortname') && model_class == Player
      clubs = Club.includes(:region)
                  .where.not(shortname: [nil, ''])
                  .order(:shortname)
                  .limit(300)
                  .pluck(:id, :shortname, :name, 'regions.shortname')
      
      club_options = clubs.map do |id, shortname, name, region|
        next if shortname.blank?
        display_name = name.present? ? "#{shortname} (#{name})" : shortname
        region_info = region.present? ? " - #{region}" : ""
        { value: shortname, label: "#{display_name}#{region_info}", id: id }
      end.compact
      
      # Sort alphabetically by label
      club_options.sort_by! { |option| option[:label].downcase }
      
      return 'select', 'select', club_options
    end

    # Season fields
    if column_def.include?('seasons.name')
      seasons = Season.order(id: :desc).limit(10).pluck(:name)
      return 'select', 'select', seasons.map { |name| { value: name, label: name } }
    end

    # Discipline fields
    if column_def.include?('disciplines.name')
      disciplines = Discipline.order(:name).pluck(:name)
      return 'select', 'select', disciplines.map { |name| { value: name, label: name } }
    end

    # Player fields (complex concatenated fields)
    if column_def.include?('players.lastname') || column_def.include?('players.firstname')
      return 'text', 'autocomplete', { 
        endpoint: '/api/players/autocomplete',
        placeholder: 'Start typing player name...'
      }
    end

    # Default to text input
    ['text', 'text', nil]
  end

  def should_show_operators(input_type)
    case input_type
    when 'number', 'date'
      true  # Show operators for numbers and dates
    when 'select', 'autocomplete', 'text'
      false # Don't show operators for text-based fields
    else
      false # Default to false for unknown types
    end
  end
end
