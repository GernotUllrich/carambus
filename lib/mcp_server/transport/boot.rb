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
        # Plan 10-05 Task 1 (Befund #2b D-10-03-1 Belt-and-Suspenders):
        # AR-Logger explizit auf Rails.logger setzen — verhindert dass ActiveRecord
        # einen eigenen STDOUT-Logger initialisiert (z.B. wenn Rails-Default in
        # development.rb oder durch Initializer-Reset überschrieben wird).
        # MCP-Server nutzt JSON-RPC über STDIO — STDOUT muss pollution-frei sein.
        ActiveRecord::Base.logger = Rails.logger if defined?(ActiveRecord)
        $stdout.sync = true

        server = McpServer::Server.build

        %w[INT TERM].each do |sig|
          Signal.trap(sig) do
            # Direkter $stderr-Write — Logger akquiriert einen Mutex und ist im Trap-Kontext
            # nicht erlaubt (Ruby ThreadError: can't be called from trap context).
            # Pitfall 8 (40-RESEARCH.md §4): Signal-Handler im SDK undokumentiert; trap-safe IO Pflicht.
            $stderr.write("[mcp-server] caught SIG#{sig}, exiting\n")
            exit 0
          end
        end

        transport = MCP::Server::Transports::StdioTransport.new(server)
        transport.open
      end
    end
  end
end
