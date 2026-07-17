# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 42 Re-Plan-Spike: cc_prepare_tournament — idempotent, KEIN armed-Flag,
# nutzt ausschließlich Version.update_from_carambus_api für den Sync.
class PrepareTournamentTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "PrepT-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @tcc = TournamentCc.create!(cc_id: 80_904, context: "nbv", tournament: @tournament, status: "finalized")

    @sportwart = User.create!(
      email: "prept_sw@test.de", password: "password123",
      persona_grants: ["sportwart"]
    )
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline

    @random = User.create!(email: "prept_random@test.de", password: "password123")

    @sw_ctx = {user_id: @sportwart.id, cc_region: "NBV"}
    @random_ctx = {user_id: @random.id, cc_region: "NBV"}
  end

  def prep(ctx)
    McpServer::Tools::PrepareTournament.call(
      tournament_cc_id: @tcc.cc_id, server_context: ctx
    )
  end

  def parse(res)
    JSON.parse(res.content.first[:text])
  end

  test "tournament_cc_id fehlend → Validierungsfehler" do
    res = McpServer::Tools::PrepareTournament.call(server_context: @sw_ctx)
    assert res.error?
    assert_match(/tournament_cc_id/, res.content.first[:text])
  end

  test "Turnier nicht auflösbar → klare Fehlermeldung, kein Sync" do
    sync_calls = 0
    Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
      res = McpServer::Tools::PrepareTournament.call(
        tournament_cc_id: 99_999_999, server_context: @sw_ctx
      )
      assert res.error?
      assert_match(/nicht gefunden/, res.content.first[:text])
    end
    assert_equal 0, sync_calls
  end

  test "AC-4: Random-User → Authority-Denied, kein Sync, kein Audit" do
    sync_calls = 0
    audit_calls = 0
    Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
      McpServer::AuditTrail.stub(:write_entry, ->(**_) { audit_calls += 1 }) do
        res = prep(@random_ctx)
        assert res.error?
        assert_match(/Authority-Denied/, res.content.first[:text])
      end
    end
    assert_equal 0, sync_calls
    assert_equal 0, audit_calls
  end

  test "AC-4: Sportwart + Sync-Erfolg → ok:true + Status + URL + Audit" do
    audit_calls = []
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "http://api.example", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**_) {}) do
        McpServer::AuditTrail.stub(:write_entry, ->(**kw) { audit_calls << kw }) do
          res = prep(@sw_ctx)
          refute res.error?
          payload = parse(res)
          assert payload["ok"]
          assert_equal @tournament.title, payload["tournament_name"]
          # Status hat 5 Felder
          assert_equal "finalized", payload["status"]["tournament_cc_status"]
          assert_equal "tournament_mode_defined", payload["status"]["tournament_state"]
          assert_equal true, payload["status"]["plan_chosen"]
          assert_kind_of Integer, payload["status"]["seedings_count"]
          assert_kind_of Integer, payload["status"]["games_count"]
          # Link + Message
          assert_match(%r{/tournaments/#{@tournament.id}\z}, payload["preparation_url"])
          assert_match(/finalisiere zuerst die Setzliste|prüfe die Setzliste/, payload["message"])
        end
      end
    end
    assert_equal 1, audit_calls.size
    audit = audit_calls.first
    assert_equal "cc_prepare_tournament", audit[:tool_name]
    assert_equal @sportwart.email, audit[:operator]
    assert_equal @tournament.id, audit[:payload][:tournament_id]
    assert_equal @tcc.cc_id, audit[:payload][:tournament_cc_id]
    assert_equal "success", audit[:result]
    assert_equal @sportwart.id, audit[:user_id]
  end

  test "AC-3: Sync-Exception → ok:false sync_failed + Link, Audit:failure" do
    audit_calls = []
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "http://api.example", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**_) { raise StandardError, "Authority offline" }) do
        McpServer::AuditTrail.stub(:write_entry, ->(**kw) { audit_calls << kw }) do
          res = prep(@sw_ctx)
          refute res.error?
          payload = parse(res)
          refute payload["ok"]
          assert_equal "sync_failed", payload["reason"]
          assert_match(/Sync.*nicht geklappt/, payload["message"])
          assert_match(%r{/tournaments/#{@tournament.id}\z}, payload["preparation_url"])
        end
      end
    end
    assert_equal 1, audit_calls.size
    assert_equal "failure", audit_calls.first[:result]
  end

  test "AC-2: Authority (api_url blank) → no_authority_configured, kein Audit, Link mitgegeben" do
    sync_calls = 0
    audit_calls = 0
    Carambus.stub(:config, OpenStruct.new(carambus_api_url: "", carambus_domain: "lvh.me:3007")) do
      Version.stub(:update_from_carambus_api, ->(**_) { sync_calls += 1 }) do
        McpServer::AuditTrail.stub(:write_entry, ->(**_) { audit_calls += 1 }) do
          res = prep(@sw_ctx)
          refute res.error?
          payload = parse(res)
          refute payload["ok"]
          assert_equal "no_authority_configured", payload["reason"]
          assert_match(%r{/tournaments/#{@tournament.id}\z}, payload["preparation_url"])
        end
      end
    end
    assert_equal 0, sync_calls
    assert_equal 0, audit_calls
  end

  test "AC-5: Tool hat KEINEN armed-Parameter im input_schema" do
    raw = McpServer::Tools::PrepareTournament.input_schema.instance_variable_get(:@schema)
    properties = raw[:properties] || raw["properties"] || {}
    keys = properties.keys.map(&:to_s)
    refute_includes keys, "armed"
    refute_includes keys, "table_ids"
    assert_includes keys, "tournament_cc_id"
  end
end
