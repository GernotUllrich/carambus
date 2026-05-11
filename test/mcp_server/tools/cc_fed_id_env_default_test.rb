# frozen_string_literal: true

require "test_helper"

# Regression-Tests für CC_FED_ID-ENV-Default in allen MCP-Tools mit fed_id-Argument.
# BaseTool.default_fed_id liest ENV['CC_FED_ID'] und stellt es 11 Tools als Fallback bereit,
# wenn der Aufrufer keine fed_id übergibt.
class McpServer::Tools::CcFedIdEnvDefaultTest < ActiveSupport::TestCase
  setup do
    McpServer::CcSession.reset!
    McpServer::CcSession.session_id = "TEST_SESSION_ID"
    McpServer::CcSession.session_started_at = Time.now
    @mock = McpServer::Tools::MockClient.new
    McpServer::CcSession._client_override = @mock
  end

  teardown do
    ENV["CC_FED_ID"] = nil
    McpServer::CcSession._client_override = nil
    McpServer::CcSession.reset!
  end

  # ===== LookupRegion (DB-first; live_lookup-Pfad braucht Default) =====
  test "LookupRegion: ENV CC_FED_ID=20 wird als Default für force_refresh-Live-Pfad gelesen" do
    ENV["CC_FED_ID"] = "20"
    response = McpServer::Tools::LookupRegion.call(force_refresh: true, server_context: nil)
    refute response.error?, "Erwartet kein Fehler bei gesetztem ENV; got: #{response.content.first[:text]}"
    assert_match(/fed_id=20/, response.content.first[:text])
  end

  test "LookupRegion: ENV unset → bestehender Missing-fed_id-Fehler bleibt" do
    ENV["CC_FED_ID"] = nil
    response = McpServer::Tools::LookupRegion.call(force_refresh: true, server_context: nil)
    assert response.error?
    # anyof-Validation feuert je nach Reihenfolge — beide Nachrichten akzeptabel
    assert_match(/Missing required parameter|provide at least one/i, response.content.first[:text])
  end

  # ===== LookupTeam (live-only; fed_id ist Pflicht) =====
  test "LookupTeam: ENV CC_FED_ID=20 wird als Default verwendet" do
    ENV["CC_FED_ID"] = "20"
    response = McpServer::Tools::LookupTeam.call(team_id: 99, server_context: nil)
    refute response.error?, "Erwartet kein Fehler bei gesetztem ENV; got: #{response.content.first[:text]}"
    assert_match(/fed_id=20/, response.content.first[:text])
  end

  test "LookupTeam: ENV unset → Missing-fed_id-Fehler bleibt" do
    ENV["CC_FED_ID"] = nil
    response = McpServer::Tools::LookupTeam.call(team_id: 99, server_context: nil)
    assert response.error?
    assert_match(/Missing required parameter: .fed_id./, response.content.first[:text])
  end

  # ===== FinalizeTeilnehmerliste (Write-Tool; fed_id im required-Array) =====
  test "FinalizeTeilnehmerliste: ENV CC_FED_ID=20 wird im validate_required!-Pfad als Default verwendet (dry-run)" do
    ENV["CC_FED_ID"] = "20"
    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      branch_id: 10, season: "2025/2026", meldeliste_id: 42,
      server_context: nil
    )
    refute response.error?, "Erwartet kein Fehler bei gesetztem ENV; got: #{response.content.first[:text]}"
    assert_match(/Would finalize Meldeliste 42/, response.content.first[:text])
  end

  test "FinalizeTeilnehmerliste: ENV unset → Missing-fed_id-Fehler bleibt" do
    ENV["CC_FED_ID"] = nil
    response = McpServer::Tools::FinalizeTeilnehmerliste.call(
      branch_id: 10, season: "2025/2026", meldeliste_id: 42,
      server_context: nil
    )
    assert response.error?
    assert_match(/Missing required parameter.*fed_id/i, response.content.first[:text])
  end

  # ===== Region-Lookup-Pfad (CC_FED_ID unset → Region.find_by(shortname:CC_REGION).region_cc.cc_id) =====
  test "default_fed_id: ENV CC_FED_ID unset + CC_REGION=NBV → Region-Lookup liefert cc_id" do
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = "NBV"

    fake_cc = Struct.new(:cc_id).new(20)
    fake_reg = Struct.new(:region_cc).new(fake_cc)
    Region.stub(:find_by, ->(args) { (args == {shortname: "NBV"}) ? fake_reg : nil }) do
      assert_equal 20, McpServer::Tools::BaseTool.default_fed_id
    end
  ensure
    ENV["CC_REGION"] = nil
  end

  test "default_fed_id: CC_FED_ID-Override beats CC_REGION-Lookup" do
    ENV["CC_FED_ID"] = "999"
    ENV["CC_REGION"] = "NBV"

    # Region.find_by darf NICHT aufgerufen werden — Override-Pfad
    Region.stub(:find_by, ->(_args) { raise "Region.find_by should not be called when CC_FED_ID is set" }) do
      assert_equal 999, McpServer::Tools::BaseTool.default_fed_id
    end
  ensure
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = nil
  end

  test "default_fed_id: defensives rescue — DB-Fehler liefert nil ohne Exception" do
    ENV["CC_FED_ID"] = nil
    ENV["CC_REGION"] = "NBV"

    Region.stub(:find_by, ->(_args) { raise ActiveRecord::ConnectionNotEstablished, "no DB in mock-smoke" }) do
      result = nil
      assert_nothing_raised { result = McpServer::Tools::BaseTool.default_fed_id }
      assert_nil result
    end
  ensure
    ENV["CC_REGION"] = nil
  end
end
