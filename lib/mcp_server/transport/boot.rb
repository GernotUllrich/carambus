# frozen_string_literal: true
# Boot-Helper: leitet Rails.logger auf STDERR um (sonst korrumpiert Logger-Output JSON-RPC),
# registriert Signal-Handler (SDK undokumentiert — Pitfall 8), öffnet StdioTransport.
#
# SDK-Verhalten bei invalidem JSON von stdin (RESOLVED in 40-RESEARCH.md Open Questions §1):
# SDK gibt JSON-RPC -32700 Parse error per Spec zurück; Server-Loop crashed nicht.

require "mcp"

module McpServer
  module Transport
    module Boot
      def self.run
        Rails.logger = Logger.new($stderr)
        Rails.logger.level = Logger::INFO
        $stdout.sync = true

        server = McpServer::Server.build

        %w[INT TERM].each do |sig|
          Signal.trap(sig) do
            Rails.logger.info "[mcp-server] caught SIG#{sig}, exiting"
            exit 0
          end
        end

        transport = MCP::Server::Transports::StdioTransport.new(server)
        transport.open
      end
    end
  end
end
