# frozen_string_literal: true
# MockClient — Drop-in-Ersatz für RegionCc::ClubCloudClient wenn CARAMBUS_MCP_MOCK=1.
# Hardcoded Fixture-Responses; reine PATH_MAP-Prüfung für writable?-Check.
# Plan 04-04 (cc_register_for_tournament): WRITABLE_ACTIONS_NOT_IN_PATH_MAP-Brücke entfernt,
# da addPlayerToMeldeliste/saveMeldeliste/showCommittedMeldeliste jetzt in PATH_MAP sind.
# Plan 06-03 (cc_update_tournament_deadline): editMeldelisteCheck/editMeldelisteSave
# jetzt in PATH_MAP. showMeldeliste-Pre-Read nutzt existierenden read-only-Key (kein neuer Eintrag).
# Per-Action rich Mock-Responses werden in Tests via `@mock.define_singleton_method(:post)` injiziert.

module McpServer
  module Tools
    class MockClient
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
        entry = RegionCc::ClubCloudClient::PATH_MAP[action]
        entry && entry[1] == false
      end

      def stub_response(message)
        Struct.new(:code, :message, :body).new("200", message, "")
      end
    end
  end
end
