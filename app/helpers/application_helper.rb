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
    
    # Handle styles separately from class
    if options[:styles].present?
      options[:style] = options[:styles]
      options.delete(:styles)
    end
    
    # Add nonce to both class and style attributes
    nonce = content_security_policy_nonce
    options[:nonce] = nonce
    options[:class] = [options[:class], "fill-current text-gray-500"].compact.join(" ")
    
    # Add nonce to style attribute if present
    if options[:style].present?
      options[:style] = "#{options[:style]}; nonce=#{nonce}"
    end

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
    links = available_locales.map do |locale|
      if locale == I18n.locale
        content_tag(:span, locale.to_s.upcase, class: 'current-locale')
      else
        link_to locale.to_s.upcase, url_for(locale: locale), class: 'locale-link'
      end
    end

    safe_join(links, ' | ')
  end

  def debug_translation(key)
    "#{I18n.locale}: #{key} => #{I18n.t(key)}"
  end

  def generate_filter_fields(model_class)
    return [] unless model_class.respond_to?(:search_hash) && model_class.search_hash({})[:column_names].present?

    column_names = model_class.search_hash({})[:column_names]

    fields = []
    column_names.each do |display_name, column_def|
      next if column_def.blank?

      # Extract the field key from the display name
      # Remove any (*) or <br/> tags
      clean_name = display_name.gsub(/\(\*\)/, '').gsub(/<br\/>.*/, '')
      field_key = clean_name.parameterize(separator: '_').downcase

      # Determine field type based on column definition
      field_type = if column_def =~ /::date$/
                     'date'
                   elsif column_def =~ /_id$/ || column_def =~ /\.id$/
                     'number'
                   else
                     'text'
                   end

      # Determine if comparison operators should be available
      show_operators = field_type == 'date' || field_type == 'number'

      fields << {
        display_name: clean_name.strip,
        field_key: field_key,
        field_type: field_type,
        show_operators: show_operators
      }
    end

    fields
  end
end
