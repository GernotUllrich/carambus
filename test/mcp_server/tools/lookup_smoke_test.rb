# frozen_string_literal: true

require "test_helper"

# Smoke-Tests für die 7 Lookup-Tools, die in Plan 04 NICHT erschöpfend unit-getestet wurden.
# Plan 04 testet LookupRegion + LookupTeilnehmerliste + SearchPlayer ausführlich;
# diese Datei verifiziert, dass die restlichen 7 Tools korrekt aufgebaut sind
# (Subclass + tool_name + Validierung).

class McpServer::Tools::LookupSmokeTest < ActiveSupport::TestCase
  setup do
    ENV["CARAMBUS_MCP_MOCK"] = "1"
    McpServer::CcSession.reset!
    McpServer::CcSession._client_override = McpServer::Tools::MockClient.new
  end

  teardown do
    ENV["CARAMBUS_MCP_MOCK"] = nil
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # Frozen Reference List — beste Kombination (Info 11):
  # 1. Dynamische Ableitung erkennt Drift, wenn ein neues Tool hinzukommt ohne dieses Update.
  # 2. Frozen Reference erkennt Drift, wenn ein Tool umbenannt oder entfernt wird.
  EXPECTED_TOOL_NAMES = %w[
    cc_lookup_region
    cc_lookup_league
    cc_lookup_tournament
    cc_lookup_teilnehmerliste
    cc_lookup_team
    cc_lookup_club
    cc_lookup_spielbericht
    cc_lookup_category
    cc_lookup_serie
    cc_search_player
    cc_finalize_teilnehmerliste
    cc_register_for_tournament
    cc_list_clubs_by_discipline
    cc_list_players_by_club_and_discipline
    cc_list_open_tournaments
    cc_list_players_by_name
    cc_check_player_discipline_experience
    cc_update_tournament_deadline
  ].freeze

  WRITE_TOOL_NAMES = %w[
    cc_finalize_teilnehmerliste
    cc_register_for_tournament
    cc_update_tournament_deadline
  ].freeze

  test "dynamic tool registry matches frozen reference (drift detection both ways)" do
    # Alle Tool-Dateien force-laden
    McpServer::Server.build  # triggers eager_load_namespace!

    dynamic = McpServer::Tools.constants.map { |c| McpServer::Tools.const_get(c) }
      .select { |k| k.is_a?(Class) && k < McpServer::Tools::BaseTool }
      .map { |k| k.respond_to?(:tool_name) ? k.tool_name.to_s : k.name.to_s.split("::").last }
      .reject(&:empty?)
      .sort

    expected_sorted = EXPECTED_TOOL_NAMES.sort

    assert_equal expected_sorted, dynamic,
      "Tool-Registry-Drift erkannt. Entweder EXPECTED_TOOL_NAMES aktualisieren " \
      "(ein Tool wurde hinzugefügt/umbenannt) oder Implementierung prüfen " \
      "(ein Tool fehlt oder hat den falschen Namen)."
  end

  test "all 18 expected tools (15 read + 3 write) are registered on McpServer::Server.build" do
    # server.tools liefert Arrays [name, klass] — erstes Element ist der tool_name-String.
    registered = McpServer::Server.build.tools.map { |t|
      if t.is_a?(Array)
        t.first.to_s
      else
        (t.respond_to?(:tool_name) ? t.tool_name.to_s : t.to_s)
      end
    }
    EXPECTED_TOOL_NAMES.each do |expected|
      assert_includes registered, expected, "Tool #{expected} nicht registriert"
    end
  end

  test "lookup_league validation: missing all params returns error" do
    response = McpServer::Tools::LookupLeague.call(server_context: nil)
    assert response.error?
  end

  test "lookup_tournament validation" do
    response = McpServer::Tools::LookupTournament.call(server_context: nil)
    assert response.error?
  end

  test "lookup_team validation" do
    response = McpServer::Tools::LookupTeam.call(server_context: nil)
    assert response.error?
  end

  test "lookup_club validation: missing fed_id returns error" do
    response = McpServer::Tools::LookupClub.call(server_context: nil)
    assert response.error?
  end

  test "lookup_spielbericht validation" do
    response = McpServer::Tools::LookupSpielbericht.call(server_context: nil)
    assert response.error?
  end

  test "lookup_category validation" do
    response = McpServer::Tools::LookupCategory.call(server_context: nil)
    assert response.error?
  end

  test "lookup_serie validation" do
    response = McpServer::Tools::LookupSerie.call(server_context: nil)
    assert response.error?
  end

  # Annotation-Disziplin — Read-Tools sind read_only_hint:true, Finalize ist destructive_hint:true.
  # Dateiname-Mapping: cc_lookup_X → lookup_X.rb; cc_search_player → search_player.rb;
  # cc_finalize_teilnehmerliste → finalize_teilnehmerliste.rb.
  test "all 15 read tools have read_only_hint: true annotation" do
    read_tool_names = EXPECTED_TOOL_NAMES - WRITE_TOOL_NAMES
    read_tool_names.each do |tname|
      fname = case tname
      when "cc_search_player" then "search_player.rb"
      else "#{tname.delete_prefix("cc_")}.rb"
      end
      file = Rails.root.join("lib/mcp_server/tools/#{fname}")
      content = file.read
      assert_match(/read_only_hint:\s*true/, content, "#{tname} (#{fname}) fehlt read_only_hint:true Annotation")
    end
  end

  test "all write tools have destructive_hint: true + read_only_hint: false" do
    WRITE_TOOL_NAMES.each do |tname|
      fname = "#{tname.delete_prefix("cc_")}.rb"
      content = Rails.root.join("lib/mcp_server/tools/#{fname}").read
      assert_match(/destructive_hint:\s*true/, content, "#{tname} fehlt destructive_hint:true")
      assert_match(/read_only_hint:\s*false/, content, "#{tname} fehlt read_only_hint:false")
    end
  end
end
