# frozen_string_literal: true

module ModeHelper
  def current_mode
    if Carambus.config.carambus_api_url.present?
      'API'
    else
      'LOCAL'
    end
  end

  def mode_badge_class
    case current_mode
    when 'LOCAL'
      'bg-yellow-100 text-yellow-800 border-yellow-200'
    when 'API'
      'bg-blue-100 text-blue-800 border-blue-200'
    else
      'bg-gray-100 text-gray-800 border-gray-200'
    end
  end

  def mode_icon
    case current_mode
    when 'LOCAL'
      '🏠'
    when 'API'
      '🌐'
    else
      '❓'
    end
  end

  def mode_description
    case current_mode
    when 'LOCAL'
      'Local Development Mode - Testing local_server functionality'
    when 'API'
      'API Mode - Connected to production API'
    else
      'Unknown Mode'
    end
  end

  def render_mode_indicator
    content_tag :div, class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium border #{mode_badge_class}" do
      concat content_tag(:span, mode_icon, class: 'mr-1')
      concat current_mode
    end
  end

  def render_mode_tooltip
    content_tag :div, class: 'group relative inline-block' do
      concat render_mode_indicator
      concat content_tag(:div, mode_description, 
                        class: 'absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 text-sm text-white bg-gray-900 rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 whitespace-nowrap z-50')
    end
  end
end 