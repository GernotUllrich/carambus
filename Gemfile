# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby file: ".ruby-version"
gem 'bundler', '2.7.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem "rails", "~> 7.2.0.beta2"

gem "aasm"
gem "acts_as_list"
gem "andand"
gem "erb_lint", require: false

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails", ">= 3.4.1"

# Use postgresql as the database for Active Record
gem "pg"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.6"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails", "~> 2.0.11"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails", "~> 1.0", ">= 1.0.2"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder", "~> 2.12"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 5.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", ">= 1.4.2", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.14"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  # Commented out: incompatible with debase (used by ruby-debug-ide)
  # Use ruby-debug-ide with debase for debugging in RubyMine instead
  # gem "debug", platforms: %i[mri windows]

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Lint code for consistent style
  gem "standard", require: false

  #gem "letter_opener_web", "~> 2.0"

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara", ">= 3.39"
  gem "selenium-webdriver", ">= 4.20.1"
  gem "webmock"
  gem 'factory_bot_rails'
  
  # Snapshot testing for external APIs (ClubCloud scraping)
  gem 'vcr'
  
  # Test coverage reporting (for information, not dogma)
  gem 'simplecov', require: false
  
  # Better test assertions
  gem 'shoulda-matchers'
end
gem "redcarpet", "~> 3.5"
gem "stimulus_reflex", "3.5.3"

gem "gcal-ruby", "~> 0.1.0"
gem "google-apis-calendar_v3", "~> 0.5.0"
gem "google-apis-youtube_v3", "~> 0.40.0"
gem "i15r", "~> 0.5.1"
gem "i18n_yaml_sort", git: "https://github.com/GovTechSG/i18n_yaml_sort.git"
gem "multipart-post"
gem "paper_trail", "~> 15.2"
gem "rails-i18n"
gem "devise"
gem "devise-i18n", "~> 1.10"
gem "pagy", "~> 9.3"
gem "pundit", "~> 2.1"
gem "inline_svg", "~> 1.6"
gem "nokogiri", ">= 1.12.5" # Security update
gem "invisible_captcha", "~> 2.0"
gem "pretender", "~> 0.4"
gem 'text'

# We recommend using strong migrations when your app is in production
gem "strong_migrations", "~> 0.7.6"

group :development do
  gem "letter_opener_web", "~> 3.0"
  gem "aasm-diagram", require: false
  # Required for ActiveSupport::EventedFileUpdateChecker (file watching in development)
  gem "listen", "~> 3.9"
  gem "capistrano", "~> 3.19.2"
  gem "capistrano-bundler"
  gem "capistrano-rails"
  gem "capistrano-rbenv", github: "capistrano/rbenv"
  gem "capistrano-secrets-yml"
  gem "capistrano3-puma"
  gem "rack-mini-profiler", require: false
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console", ">= 4.1.0"

  gem "stackprof", require: true

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler", ">= 2.3.3"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  # Annotate models and tests with database columns
  gem "annotate", ">= 3.2.0"

  # Enhanced Exception messages
  # removed because included by default
  # gem 'error_highlight', '>= 0.6.0', platforms: [:ruby]

  # A fully configurable and extendable Git hook manager
  gem "overcommit", require: false
end

gem "cable_ready", "5.0.6"
#gem "unicorn"

gem "importmap-rails", "~> 1.1"

gem "redis-session-store", "~> 0.11.5"

gem "net-ping"
gem 'flay'

# We recommend using strong migrations when your app is in production
# gem "strong_migrations"

gem 'administrate', '~> 0.19.0'

gem 'cancancan', '~> 3.5'

# Syntax highlighting for code blocks
gem 'rouge', '~> 3.26'

# OpenAI API integration for AI-powered search
gem 'ruby-openai', '~> 7.3'

# PDF text extraction for tournament invitation parsing
gem 'pdf-reader', '~> 2.12'
# PDF generation for game protocols
gem 'prawn', '~> 2.4'
gem 'prawn-table', '~> 0.2'

# OCR for screenshot/image text extraction (requires tesseract-ocr system package)
gem 'rtesseract', '~> 3.1'
