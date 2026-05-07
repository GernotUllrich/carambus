# frozen_string_literal: true
# Phase 40 MCP-Server Deploy-Task — stellt sicher, dass bin/mcp-server nach jedem Deploy ausführbar ist.
#
# Hintergrund (RESEARCH Open Question §5 RESOLVED):
# Capistranos Standard-`linked_files`-Workflow bewahrt git-gespeicherte executable-Bits
# beim `release_path`-Symlinking nicht zuverlässig auf allen Servern.
# Ohne diesen Hook schlägt ein MCP-Client, der bin/mcp-server auf einem frisch deployte
# Server spawnt, mit EACCES (Permission denied) fehl.
#
# Hook-Zeitpunkt: after :bundle:install — release-Dir ist vorhanden, vor Restart-Hooks.
# Lokale Entwicklung: nicht betroffen — git trackt den File-Mode, Devs setzen `chmod +x` einmalig.
# E2E-Test (test/mcp_server/integration/stdio_e2e_test.rb): prüft File.executable? lokal.

namespace :deploy do
  namespace :mcp_server do
    desc "Executable-Bit auf bin/mcp-server setzen (Phase 40 MCP-Server)"
    task :set_executable do
      on roles(:app) do
        # release_path ist das frisch deployte Release-Verzeichnis dieses Runs.
        within release_path do
          execute :chmod, "0755", "bin/mcp-server"
        end
      end
    end
  end
end

# Nach bundle:install ausführen — release-Dir ist vorhanden, vor allen Restart-Hooks.
after "bundle:install", "deploy:mcp_server:set_executable"
