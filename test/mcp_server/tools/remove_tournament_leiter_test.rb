# frozen_string_literal: true

require "test_helper"
require_relative "../../../lib/mcp_server/tools/base_tool"
Dir[Rails.root.join("lib/mcp_server/tools/*.rb")].each { |f| require f }

# Phase 34-04: cc_remove_tournament_leiter — entfernt lokale TL-Zuordnung; lehnt globale ab.
class RemoveTournamentLeiterTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "RTL-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
    @tcc = TournamentCc.create!(cc_id: 80_202, context: "nbv", tournament: @tournament)
    @sportwart = User.create!(email: "rtl_sw@test.de", password: "password123")
    @sportwart.sportwart_locations << @location
    @sportwart.sportwart_disciplines << @discipline
    @random = User.create!(email: "rtl_random@test.de", password: "password123")
    @target = User.create!(email: "rtl_target@test.de", password: "password123", first_name: "Max", last_name: "Mueller")
    @sw_ctx = {user_id: @sportwart.id, cc_region: "NBV"}
    @random_ctx = {user_id: @random.id, cc_region: "NBV"}
  end

  def remove(ctx, **kw)
    McpServer::Tools::RemoveTournamentLeiter.call(tournament_cc_id: @tcc.cc_id, server_context: ctx, **kw)
  end

  test "lokale Zuordnung + Sportwart armed:true → entfernt, leiter? false" do
    UserTournament.create!(user: @target, tournament: @tournament, role: "turnier_leiter")
    res = remove(@sw_ctx, leiter_email: @target.email, armed: true)
    assert_not res.error?
    assert_not UserTournament.exists?(user: @target, tournament: @tournament, role: "turnier_leiter")
    assert_not @tournament.reload.leiter?(@target)
  end

  test "nur globale Zuordnung → Ablehnung, globales Feld unverändert" do
    @tournament.update_column(:turnier_leiter_user_id, @target.id)
    res = remove(@sw_ctx, leiter_email: @target.email, armed: true)
    assert res.error?
    assert_match(/Turnier-Formular/, res.content.first[:text])
    assert_equal @target.id, @tournament.reload.turnier_leiter_user_id
  end

  test "gar nicht TL → no-op-Hinweis" do
    res = remove(@sw_ctx, leiter_email: @target.email, armed: true)
    assert_not res.error?
    assert_match(/nicht als Turnierleiter/, res.content.first[:text])
  end

  test "Random-User → Authority-Denied, UserTournament bleibt" do
    UserTournament.create!(user: @target, tournament: @tournament, role: "turnier_leiter")
    res = remove(@random_ctx, leiter_email: @target.email, armed: true)
    assert res.error?
    assert UserTournament.exists?(user: @target, tournament: @tournament, role: "turnier_leiter")
  end
end
