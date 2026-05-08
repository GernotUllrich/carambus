# frozen_string_literal: true
# MockClient — Drop-in-Ersatz für RegionCc::ClubCloudClient wenn CARAMBUS_MCP_MOCK=1.
# Hardcoded Fixture-Responses; Plan 05 erweitert dies mit releaseMeldeliste-Fixture.

module McpServer
  module Tools
    class MockClient
      # Action-Namen, die in PATH_MAP NOCH NICHT registriert sind, aber als
      # destruktive Writes behandelt werden sollen (für dry-run-Spiegelung).
      # Plan 04-02: "registerForTournament" — finalisiert in Plan 04-03 nach DevTools-Sniff;
      # nach PATH_MAP-Eintrag in 04-03 kann der Eintrag hier entfernt werden.
      WRITABLE_ACTIONS_NOT_IN_PATH_MAP = %w[registerForTournament].freeze

      attr_reader :calls

      def initialize
        @calls = []
      end

      def get(action, get_options = {}, opts = {})
        @calls << [:get, action, get_options, opts]
        [stub_response("OK"), Nokogiri::HTML("<html><body>MOCK GET #{action}</body></html>")]
      end

      def post(action, post_options = {}, opts = {})
        @calls << [:post, action, post_options, opts]
        # Honoriert armed-flag dry-run-Konvention zur Spiegelung des echten Clients (Pitfall 5).
        return [nil, nil] if opts[:armed].blank? && writable?(action)
        [stub_response("OK"), Nokogiri::HTML("<html><body>MOCK POST #{action} OK</body></html>")]
      end

      def post_with_formdata(action, post_options = {}, opts = {})
        post(action, post_options, opts)
      end

      private

      def writable?(action)
        return true if WRITABLE_ACTIONS_NOT_IN_PATH_MAP.include?(action)
        entry = RegionCc::ClubCloudClient::PATH_MAP[action]
        entry && entry[1] == false
      end

      def stub_response(message)
        Struct.new(:code, :message, :body).new("200", message, "")
      end
    end
  end
end
