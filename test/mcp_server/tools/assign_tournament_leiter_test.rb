# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 34-04: cc_assign_tournament_leiter — lokale TL-Zuordnung (UserTournament), gated, armed.
class AssignTournamentLeiterTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "ATL-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @tcc = TournamentCc.create!(cc_id: 80_201, context: "nbv", tournament: @tournament)
    @sportwart = User.create!(email: "atl_sw@test.de", password: "password123")
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline
    @random = User.create!(email: "atl_random@test.de", password: "password123")
    @target = User.create!(email: "atl_target@test.de", password: "password123", first_name: "Max", last_name: "Mueller")
    @sw_ctx = {user_id: @sportwart.id, cc_region: "NBV"}
    @random_ctx = {user_id: @random.id, cc_region: "NBV"}
  end

  def assign(ctx, **kw)
    McpServer::Tools::AssignTournamentLeiter.call(tournament_cc_id: @tcc.cc_id, server_context: ctx, **kw)
  end

  test "Random-User → Authority-Denied, kein UserTournament" do
    res = assign(@random_ctx, leiter_email: @target.email, armed: true)
    assert res.error?
    assert_not UserTournament.exists?(user: @target, tournament: @tournament)
  end

  test "Sportwart armed:false → Probelauf, kein UserTournament" do
    res = assign(@sw_ctx, leiter_email: @target.email, armed: false)
    assert_not res.error?
    assert_match(/Probelauf/, res.content.first[:text])
    assert_not UserTournament.exists?(user: @target, tournament: @tournament)
  end

  test "Sportwart armed:true → UserTournament angelegt, leiter? true" do
    res = assign(@sw_ctx, leiter_email: @target.email, armed: true)
    assert_not res.error?
    assert UserTournament.exists?(user: @target, tournament: @tournament, role: "turnier_leiter")
    assert @tournament.reload.leiter?(@target)
  end

  test "erneuter armed:true → bereits zugeordnet, kein Duplikat" do
    assign(@sw_ctx, leiter_email: @target.email, armed: true)
    res = assign(@sw_ctx, leiter_email: @target.email, armed: true)
    assert_not res.error?
    assert_match(/bereits Turnierleiter/, res.content.first[:text])
    assert_equal 1, UserTournament.where(user: @target, tournament: @tournament, role: "turnier_leiter").count
  end

  test "leiter_name ohne Match → Not-Found-Fehler" do
    res = assign(@sw_ctx, leiter_name: "Niemand Existiertnicht", armed: true)
    assert res.error?
    assert_match(/Kein Benutzerkonto/, res.content.first[:text])
  end

  test "mehrdeutiger Name → Disambiguierungs-Fehler" do
    User.create!(email: "atl_h1@test.de", password: "password123", first_name: "Hansjoerg", last_name: "Meier")
    User.create!(email: "atl_h2@test.de", password: "password123", first_name: "Hansjoerg", last_name: "Schulz")
    res = assign(@sw_ctx, leiter_name: "Hansjoerg", armed: true)
    assert res.error?
    assert_match(/Mehrere Nutzer/, res.content.first[:text])
  end
end
