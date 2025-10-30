# config/application.rb
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Carambus
  def self.config
    @config ||= begin
                  yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))
                  settings = yaml['default'].merge(yaml[Rails.env] || {})
                  OpenStruct.new(settings)
                end
  end

  def self.config=(new_config)
    @config = new_config
  end

  def self.save_config(create_lock: false)
    yaml = YAML.load_file(Rails.root.join('config', 'carambus.yml'))

    # Konvertiere die Werte zu Symbolen für konsistente Speicherung
    config_hash = @config.to_h.transform_keys(&:to_sym)

    # Stelle sicher, dass der Environment-Block existiert
    yaml[Rails.env] ||= {}

    # Deep convert HashWithIndifferentAccess to regular Hash to avoid Ruby serialization markers
    config_hash = deep_stringify_hash(config_hash)

    # Update nur die geänderten Werte im Environment-Block
    config_hash.each do |key, value|
      if value != yaml['default'][key.to_s]  # Vergleiche mit default-Wert
        yaml[Rails.env][key.to_s] = value    # Speichere nur wenn abweichend
      else
        yaml[Rails.env].delete(key.to_s)     # Entferne wenn gleich default
      end
    end

    # Schreibe die aktualisierte YAML-Datei
    File.write(Rails.root.join('config', 'carambus.yml'), yaml.to_yaml)

    # Create lock file if requested (prevents scenario deployment from overwriting)
    if create_lock
      lock_file = Rails.root.join('config', 'carambus.yml.lock')
      File.write(lock_file, {
        created_at: Time.now.iso8601,
        created_by: 'admin_settings',
        message: 'Configuration manually edited via admin settings. Prevents scenario deployment from overwriting.'
      }.to_yaml)
    end
  end

  # Deep convert HashWithIndifferentAccess and other Rails types to plain Ruby types
  def self.deep_stringify_hash(obj)
    case obj
    when Hash, ActiveSupport::HashWithIndifferentAccess
      obj.each_with_object({}) do |(key, value), hash|
        hash[key.to_s] = deep_stringify_hash(value)
      end
    when Array
      obj.map { |item| deep_stringify_hash(item) }
    else
      obj
    end
  end
end

module CarambusApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2
    # Attempt to configure strong_migrations
    config.after_initialize do
      if defined?(StrongMigrations)
        StrongMigrations.disable_check(:force_option)
      end
    end
    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets generators tasks templates])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    config.time_zone = "Berlin"
    # config.eager_load_paths << Rails.root.join("extras")

    # Use ErrorsController for handling 404s and 500s.
    config.exceptions_app = routes
    config.active_record.yaml_column_permitted_classes = [ActiveSupport::TimeWithZone, ActiveSupport::TimeZone, Time, Date, ActiveSupport::HashWithIndifferentAccess, Symbol]

    # Where the I18n library should search for translation files
    # Search nested folders in config/locales for better organization
    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]

    # Permitted locales available for the application
    config.i18n.available_locales = [:en, :de]

    # Set default locale
    config.i18n.default_locale = :de

    # Use default language as fallback if translation is missing
    config.i18n.fallbacks = true

    # Prevent sassc-rails from setting sass as the compressor
    # Libsass is deprecated and doesn't support modern CSS syntax used by TailwindCSS
    config.assets.css_compressor = nil

    config.action_cable.allowed_request_origins = [/http:\/\/*/, /https:\/\/*/]
    config.action_cable.disable_request_forgery_protection = true
    config.action_cable.allow_same_origin_as_host = true
    config.action_cable.mount_path = '/cable'

    # Rails 7 defaults to libvips as the variant processor
    # libvips is up to 10x faster and consumes 1/10th the memory of imagemagick
    # If you need to use imagemagick, uncomment this to switch
    # config.active_storage.variant_processor = :mini_magick

    # Support older SHA1 digests for ActiveStorage so ActionText attachments don't break
    config.after_initialize do |app|
      app.message_verifier("ActiveStorage").rotate(digest: "SHA1")
    end

    # Use Rails credentials as normal

    # Support older SHA1 digests for ActiveRecord::Encryption
    config.active_record.encryption.support_sha1_for_non_deterministic_encryption = true

    # Lade alle Übersetzungsdateien (auch in Unterordnern)
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}')]

  end
end
