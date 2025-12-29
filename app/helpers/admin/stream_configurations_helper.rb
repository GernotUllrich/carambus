# frozen_string_literal: true

module Admin
  module StreamConfigurationsHelper
    # Return Tailwind CSS classes for status border color
    def status_border_color(status)
      case status
      when 'active'
        'border-green-500'
      when 'starting'
        'border-yellow-500'
      when 'stopping'
        'border-orange-500'
      when 'error'
        'border-red-500'
      else # inactive
        'border-gray-300 dark:border-gray-600'
      end
    end

    # Return status badge with icon
    def status_badge(status)
      icon, color_class = case status
      when 'active'
        ['🟢', 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200']
      when 'starting'
        ['🟡', 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200']
      when 'stopping'
        ['🟠', 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200']
      when 'error'
        ['🔴', 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200']
      else # inactive
        ['⚪', 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-200']
      end

      content_tag(:span, class: "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium #{color_class}") do
        "#{icon} #{status.titleize}"
      end
    end

    # Return formatted uptime string
    def format_uptime(started_at)
      return '-' unless started_at

      duration = Time.current - started_at
      hours = (duration / 3600).to_i
      minutes = ((duration % 3600) / 60).to_i

      if hours > 0
        "#{hours}h #{minutes}m"
      else
        "#{minutes}m"
      end
    end

    # Return stream quality badge
    def quality_badge(bitrate)
      color_class = if bitrate >= 3000
        'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200'
      elsif bitrate >= 1500
        'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200'
      else
        'bg-yellow-100 text-yellow-800 dark:bg-yellow-900 dark:text-yellow-200'
      end

      content_tag(:span, class: "inline-flex items-center px-2 py-1 rounded text-xs font-medium #{color_class}") do
        "#{bitrate}k"
      end
    end
  end
end

