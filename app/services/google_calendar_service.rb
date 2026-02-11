# frozen_string_literal: true

# Service class for Google Calendar operations
# Centralizes Google API credentials and authentication
class GoogleCalendarService
  CALENDAR_SCOPES = %w[
    https://www.googleapis.com/auth/calendar
    https://www.googleapis.com/auth/calendar.events
  ].freeze

  class << self
    # Returns a configured Google Calendar service instance
    # Uses location-specific credentials from Rails.application.credentials
    def calendar_service
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = authorizer
      service
    end

    # Returns the calendar ID for the current location
    def calendar_id
      Rails.application.credentials[:location_calendar_id]
    end

    private

    def authorizer
      Google::Auth::ServiceAccountCredentials.make_creds(
        json_key_io: StringIO.new(service_account_credentials_json),
        scope: CALENDAR_SCOPES
      )
    end

    def service_account_credentials_json
      {
        type: "service_account",
        project_id: credentials_config[:project_id],
        private_key_id: credentials_config[:private_key_id],
        private_key: credentials_config[:private_key].gsub('\n', "\n"),
        client_email: credentials_config[:client_email],
        client_id: credentials_config[:client_id],
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: client_cert_url,
        universe_domain: "googleapis.com"
      }.to_json
    end

    def credentials_config
      @credentials_config ||= begin
        google_service = Rails.application.credentials.dig(:google_service) || {}
        
        {
          project_id: google_service[:project_id] || "carambus-test",
          private_key_id: google_service[:private_key_id] || google_service[:public_key],
          private_key: google_service[:private_key] || raise_missing_credential(:private_key),
          client_email: google_service[:client_email] || "service-test@carambus-test.iam.gserviceaccount.com",
          client_id: google_service[:client_id] || "110923757328591064447"
        }
      end
    end

    def client_cert_url
      email_encoded = ERB::Util.url_encode(credentials_config[:client_email])
      "https://www.googleapis.com/robot/v1/metadata/x509/#{email_encoded}"
    end

    def raise_missing_credential(key)
      raise "Missing Google Service credential: #{key}. Please configure it in Rails credentials."
    end
  end
end
