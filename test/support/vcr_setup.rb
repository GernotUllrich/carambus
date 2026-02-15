# frozen_string_literal: true

require 'vcr'

VCR.configure do |config|
  # Store cassettes in test/snapshots/vcr
  config.cassette_library_dir = 'test/snapshots/vcr'
  
  # Use webmock for HTTP interception
  config.hook_into :webmock
  
  # Don't interfere with local connections
  config.ignore_localhost = true
  
  # Filter sensitive data from cassettes
  # These will be replaced with <USERNAME> and <PASSWORD> in recorded files
  config.filter_sensitive_data('<CC_USERNAME>') do |interaction|
    # Extract from request body if present
    if interaction.request.body.include?('username=')
      CGI.parse(interaction.request.body)['username']&.first
    end
  end
  
  config.filter_sensitive_data('<CC_PASSWORD>') do |interaction|
    # Extract from request body if present
    if interaction.request.body.include?('password=') || interaction.request.body.include?('userpw=')
      CGI.parse(interaction.request.body)['password']&.first ||
        CGI.parse(interaction.request.body)['userpw']&.first
    end
  end
  
  # Configure cassette matching
  config.default_cassette_options = {
    record: :once,                    # Record once, then replay
    match_requests_on: [:method, :uri], # Match on HTTP method and URI
    allow_playback_repeats: true      # Allow repeated playback
  }
  
  # Pretty print JSON in cassettes for better diffs
  config.before_record do |interaction|
    if interaction.response.headers['Content-Type']&.include?('application/json')
      begin
        body = JSON.parse(interaction.response.body)
        interaction.response.body = JSON.pretty_generate(body)
      rescue JSON::ParserError
        # Not valid JSON, leave as is
      end
    end
  end
end
