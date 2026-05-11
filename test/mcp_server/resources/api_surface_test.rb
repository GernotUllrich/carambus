# frozen_string_literal: true

require "test_helper"

class McpServer::Resources::ApiSurfaceTest < ActiveSupport::TestCase
  test "all gibt 26 kuratierte MCP::Resource-Instanzen zurück (D-04 Allowlist, +3 Plan 04-04, +2 Plan 06-03, +5 Plan 07-03, +1 Plan 08-02)" do
    resources = McpServer::Resources::ApiSurface.all
    assert_equal 26, resources.size, "ALLOWLIST-Größe drifted — Test aktualisieren oder Allowlist überprüfen (D-04-Boundary aus Plan 08-01 D-08-01 ist 26)"
    assert resources.all? { |r| r.is_a?(MCP::Resource) }
  end

  test "alle URIs entsprechen cc://api/{action}" do
    McpServer::Resources::ApiSurface.all.each do |r|
      assert_match %r{\Acc://api/[\w-]+\z}, r.uri
    end
  end

  test "alle ALLOWLIST-Entries existieren in PATH_MAP (Drift-Guard)" do
    missing = McpServer::Resources::ApiSurface::ALLOWLIST.reject { |k| RegionCc::ClubCloudClient::PATH_MAP.key?(k) }
    assert_empty missing, "ALLOWLIST-Entries fehlen in PATH_MAP: #{missing.inspect}"
  end

  test "read(action: 'releaseMeldeliste') referenziert cc_finalize_teilnehmerliste-Tool (D-04 Mapping)" do
    md = McpServer::Resources::ApiSurface.read(action: "releaseMeldeliste")
    assert_match(/cc_finalize_teilnehmerliste/, md)
    assert_match(/Read-Only.*false/, md)
  end

  test "read(action: 'showLeagueList') nennt den Syncer (D-04 Mapping)" do
    md = McpServer::Resources::ApiSurface.read(action: "showLeagueList")
    assert_match(/league_syncer\.rb/, md)
  end

  test "read(action: unbekannt) gibt nicht-in-Allowlist-Body zurück (keine Exception)" do
    md = McpServer::Resources::ApiSurface.read(action: "nonexistent")
    assert_match(/nicht in Allowlist/, md)
  end

  test "server.build enthält 26 cc://api/* Resources (15 + 3 Plan 04-04 + 2 Plan 06-03 + 5 Plan 07-03 + 1 Plan 08-02 — D-04-Limit erreicht)" do
    server = McpServer::Server.build
    api_uris = server.resources.map(&:uri).select { |u| u.start_with?("cc://api/") }
    assert_equal 26, api_uris.size
  end
end
