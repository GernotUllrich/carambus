# frozen_string_literal: true

# MkDocs Documentation URLs Configuration
# This file defines the URLs for the MkDocs-generated documentation
# that replaces the static documentation pages

module MkDocsUrls
  # Base URL for the MkDocs documentation
  # Use relative URLs for local deployment, or set MKDOCS_BASE_URL for external hosting
  BASE_URL = ENV.fetch('MKDOCS_BASE_URL', '/docs').freeze

  # Documentation URLs for different languages and sections
  class << self
    def tournament_doc_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/tournament/"
      when 'en'
        "#{BASE_URL}/en/tournament/"
      else
        "#{BASE_URL}/tournament/" # Default to German
      end
    end

    def league_doc_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/league/"
      when 'en'
        "#{BASE_URL}/en/league/"
      else
        "#{BASE_URL}/league/" # Default to German
      end
    end

    def developer_guide_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/DEVELOPER_GUIDE/"
      when 'en'
        "#{BASE_URL}/en/DEVELOPER_GUIDE/"
      else
        "#{BASE_URL}/de/DEVELOPER_GUIDE/" # Default to German
      end
    end

    def api_doc_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/API/"
      when 'en'
        "#{BASE_URL}/en/API/"
      else
        "#{BASE_URL}/de/API/" # Default to German
      end
    end

    def database_design_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/database_design/"
      when 'en'
        "#{BASE_URL}/en/database_design/"
      else
        "#{BASE_URL}/de/database_design/" # Default to German
      end
    end

    def scoreboard_setup_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/scoreboard_autostart_setup/"
      when 'en'
        "#{BASE_URL}/en/scoreboard_autostart_setup/"
      else
        "#{BASE_URL}/de/scoreboard_autostart_setup/" # Default to German
      end
    end

    def table_reservation_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/table_reservation_heating_control/"
      when 'en'
        "#{BASE_URL}/en/table_reservation_heating_control/"
      else
        "#{BASE_URL}/de/table_reservation_heating_control/" # Default to German
      end
    end

    def mode_switcher_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/mode_switcher/"
      when 'en'
        "#{BASE_URL}/en/mode_switcher/"
      else
        "#{BASE_URL}/de/mode_switcher/" # Default to German
      end
    end

    def mkdocs_documentation_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/mkdocs_dokumentation/"
      when 'en'
        "#{BASE_URL}/en/mkdocs_documentation/"
      else
        "#{BASE_URL}/de/mkdocs_dokumentation/" # Default to German
      end
    end

    # Main documentation index
    def main_doc_url(locale = I18n.locale)
      case locale.to_s
      when 'de'
        "#{BASE_URL}/de/"
      when 'en'
        "#{BASE_URL}/en/"
      else
        "#{BASE_URL}/de/" # Default to German
      end
    end
  end
end 