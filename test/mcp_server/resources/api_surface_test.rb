# frozen_string_literal: true
require "test_helper"

class McpServer::Resources::ApiSurfaceTest < ActiveSupport::TestCase
  test "all gibt 20 kuratierte MCP::Resource-Instanzen zurück (D-04 Allowlist gesperrt, +3 in Plan 04-04, +2 in Plan 06-03)" do
    resources = McpServer::Resources::ApiSurface.all
    assert_equal 20, resources.size, "ALLOWLIST-Größe drifted — Test aktualisieren oder Allowlist überprüfen"
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

  test "server.build enthält 20 cc://api/* Resources (15 + 3 in Plan 04-04 + 2 in Plan 06-03)" do
    server = McpServer::Server.build
    api_uris = server.resources.map(&:uri).select { |u| u.start_with?("cc://api/") }
    assert_equal 20, api_uris.size
  end
end
