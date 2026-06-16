# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 43 Spike: cc_open_in_tournament_app — Chat-Brücke zu carambus_app.
# Idempotent, KEIN armed; synct Teilnehmer (Opener) + liefert App-Deep-Link.
class OpenInTournamentAppTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "OITA-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @tcc = TournamentCc.create!(cc_id: 80_906, context: "nbv", tournament: @tournament, status: "finalized")

    @sportwart = User.create!(email: "oita_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline
    @random = User.create!(email: "oita_random@test.de", password: "password123")

    @sw_ctx = {user_id: @sportwart.id, cc_region: "NBV"}
    @random_ctx = {user_id: @random.id, cc_region: "NBV"}

    @cfg = OpenStruct.new(
      carambus_api_url: "http://api.example",
      tournament_app_url: "http://192.168.2.210:3131/app/",
      external_app_api_base_url: "http://192.168.2.210:3131"
    )
  end

  def open_app(ctx)
    McpServer::Tools::OpenInTournamentApp.call(tournament_cc_id: @tcc.cc_id, server_context: ctx)
  end

  def parse(res)
    JSON.parse(res.content.first[:text])
  end

  test "tournament_cc_id fehlend → Validierungsfehler" do
    res = McpServer::Tools::OpenInTournamentApp.call(server_context: @sw_ctx)
    assert res.error?
    assert_match(/tournament_cc_id/, res.content.first[:text])
  end

  test "Turnier nicht auflösbar → Fehlermeldung, kein Sync" do
    sync_calls = 0
    Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
      res = McpServer::Tools::OpenInTournamentApp.call(tournament_cc_id: 99_999_999, server_context: @sw_ctx)
      assert res.error?
      assert_match(/nicht gefunden/, res.content.first[:text])
    end
    assert_equal 0, sync_calls
  end

  test "AC-3: Random-User → Authority-Denied, kein Sync/Audit" do
    sync_calls = 0
    audit_calls = 0
    Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
      McpServer::AuditTrail.stub(:write_entry, ->(**_) { audit_calls += 1 }) do
        res = open_app(@random_ctx)
        assert res.error?
        assert_match(/Authority-Denied/, res.content.first[:text])
      end
    end
    assert_equal 0, sync_calls
    assert_equal 0, audit_calls
  end

  test "AC-2: Sportwart + Sync ok → JSON ok:true + app_link + Audit success" do
    audit_calls = []
    Carambus.stub(:config, @cfg) do
      Version.stub(:update_from_carambus_api, ->(**_) {}) do
        McpServer::AuditTrail.stub(:write_entry, ->(**kw) { audit_calls << kw }) do
          res = open_app(@sw_ctx)
          refute res.error?
          payload = parse(res)
          assert payload["ok"]
          assert_equal "OITA-Test", payload["tournament_name"]
          assert_match(%r{192.168.2.210:3131/app/\?}, payload["app_link"])
          assert_match(/cb_tournament_cc_id=80906/, payload["app_link"])
          assert_match(/cb_region=NBV/, payload["app_link"])
          assert_match(/Turnier-App/, payload["message"])
        end
      end
    end
    assert_equal 1, audit_calls.size
    audit = audit_calls.first
    assert_equal "cc_open_in_tournament_app", audit[:tool_name]
    assert_equal @sportwart.email, audit[:operator]
    assert_equal @tournament.id, audit[:payload][:tournament_id]
    assert_equal "success", audit[:result]
  end

  test "AC-3: Sync-Exception → app_link TROTZDEM + Hinweis, Audit failure" do
    audit_calls = []
    Carambus.stub(:config, @cfg) do
      Version.stub(:update_from_carambus_api, ->(**_) { raise StandardError, "Authority offline" }) do
        McpServer::AuditTrail.stub(:write_entry, ->(**kw) { audit_calls << kw }) do
          res = open_app(@sw_ctx)
          refute res.error?
          payload = parse(res)
          refute payload["ok"]
          assert_match(%r{/app/\?.*cb_tournament_cc_id=80906}, payload["app_link"])
          assert_match(/älteren Stand|nicht frisch/, payload["message"])
        end
      end
    end
    assert_equal 1, audit_calls.size
    assert_equal "failure", audit_calls.first[:result]
  end

  test "AC-4: input_schema ohne armed/table_ids, mit tournament_cc_id" do
    raw = McpServer::Tools::OpenInTournamentApp.input_schema.instance_variable_get(:@schema)
    keys = (raw[:properties] || raw["properties"] || {}).keys.map(&:to_s)
    refute_includes keys, "armed"
    refute_includes keys, "table_ids"
    assert_includes keys, "tournament_cc_id"
  end
end
