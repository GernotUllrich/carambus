# frozen_string_literal: true

# Carambus Environment Configuration
# Provides portable path resolution for Carambus projects
#
# Usage in Rails:
#   require_relative 'carambus_env'
#   CarambusEnv.base_path
#   CarambusEnv.data_path
#   CarambusEnv.scenarios_path
#
module CarambusEnv
  class << self
    # Get the base Carambus directory
    def base_path
      @base_path ||= detect_base_path
    end

    # Get the carambus_data directory
    def data_path
      @data_path ||= File.join(base_path, 'carambus_data')
    end

    # Get the scenarios directory
    def scenarios_path
      @scenarios_path ||= File.join(data_path, 'scenarios')
    end

    # Get a specific application path (master, api, bcw, location_5101)
    def app_path(app_name)
      File.join(base_path, "carambus_#{app_name}")
    end

    # Reset cached paths (useful for testing)
    def reset!
      @base_path = nil
      @data_path = nil
      @scenarios_path = nil
    end

    # Enable debug output
    def debug=(value)
      @debug = value
    end

    def debug?
      @debug ||= ENV['CARAMBUS_DEBUG'].to_s.downcase == 'true'
    end

    private

    def detect_base_path
      path = detect_from_env ||
             detect_from_config ||
             detect_from_rails_root ||
             detect_from_file_location ||
             fallback_path

      log_debug "Detected CARAMBUS_BASE: #{path}"
      path
    end

    # 1. Check environment variable
    def detect_from_env
      ENV['CARAMBUS_BASE'] if ENV['CARAMBUS_BASE']&.strip&.length&.positive?
    end

    # 2. Check config file
    def detect_from_config
      config_file = File.expand_path('~/.carambus_config')
      return unless File.exist?(config_file)

      content = File.read(config_file)
      if (match = content.match(/^CARAMBUS_BASE=(.+)$/))
        match[1].strip
      end
    rescue StandardError => e
      log_debug "Error reading config file: #{e.message}"
      nil
    end

    # 3. Auto-detect based on Rails.root
    def detect_from_rails_root
      return unless defined?(Rails) && Rails.respond_to?(:root)

      current = Rails.root.to_s
      max_depth = 5
      depth = 0

      while current != '/' && depth < max_depth
        parent = File.dirname(current)
        carambus_data = File.join(parent, 'carambus_data')

        if File.directory?(carambus_data)
          log_debug "Found via Rails.root: #{parent}"
          return parent
        end

        current = parent
        depth += 1
      end

      nil
    end

    # 4. Auto-detect based on this file's location
    def detect_from_file_location
      current = File.dirname(__FILE__)
      max_depth = 5
      depth = 0

      while current != '/' && depth < max_depth
        parent = File.dirname(current)
        carambus_data = File.join(parent, 'carambus_data')

        if File.directory?(carambus_data)
          log_debug "Found via file location: #{parent}"
          return parent
        end

        current = parent
        depth += 1
      end

      nil
    end

    # 5. Fallback
    def fallback_path
      log_debug "Using fallback path"
      '/Volumes/EXT2TB/gullrich/DEV/carambus'
    end

    def log_debug(message)
      warn "[CARAMBUS_ENV] #{message}" if debug?
    end
  end
end

