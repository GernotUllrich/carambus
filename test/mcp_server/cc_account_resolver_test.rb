# frozen_string_literal: true

require "test_helper"

# Plan 39-02 Task 2 (D-39-2/D-39-3/D-39-6): CcAccountResolver klassifiziert die effektive
# CC-Identität deterministisch (:own / :tl_inherited / :none). Reine DB-Logik, kein CC.
class McpServer::CcAccountResolverTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
    @tournament = Tournament.create!(
      title: "CAR-Resolver-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now
    )
  end

  def make_user(email:, with_creds:)
    attrs = {email: email, password: "password123"}
    attrs.merge!(cc_username: "#{email}-cc", cc_password: "#{email}-pw") if with_creds
    User.create!(**attrs)
  end

  test ":own — User mit eigenen CC-Creds" do
    user = make_user(email: "own@test.de", with_creds: true)
    acc = McpServer::CcAccountResolver.resolve(user: user, tournament: @tournament)
    assert_equal :own, acc.source
    assert acc.resolved?
    assert_equal user.cc_username, acc.login_username
    assert_equal user.cc_password, acc.password
    assert_equal user.id, acc.acting_user_id
    assert_nil acc.granted_by_user_id
  end

  test ":own funktioniert auch ohne tournament-Argument" do
    user = make_user(email: "own2@test.de", with_creds: true)
    acc = McpServer::CcAccountResolver.resolve(user: user)
    assert_equal :own, acc.source
    assert_equal user.cc_username, acc.login_username
  end

  test ":tl_inherited — TL ohne eigene Creds erbt die Creds des einsetzenden Sportwarts" do
    granter = make_user(email: "granter@test.de", with_creds: true)
    tl = make_user(email: "tl@test.de", with_creds: false)
    UserTournament.create!(user: tl, tournament: @tournament, role: "turnier_leiter", granted_by: granter)

    acc = McpServer::CcAccountResolver.resolve(user: tl, tournament: @tournament)
    assert_equal :tl_inherited, acc.source
    assert acc.resolved?
    assert_equal granter.cc_username, acc.login_username
    assert_equal granter.cc_password, acc.password
    assert_equal tl.id, acc.acting_user_id, "acting_user_id = der echte TL"
    assert_equal granter.id, acc.granted_by_user_id
  end

  test ":none — TL via UserTournament, aber Granter OHNE Creds" do
    granter = make_user(email: "granter_nocred@test.de", with_creds: false)
    tl = make_user(email: "tl2@test.de", with_creds: false)
    UserTournament.create!(user: tl, tournament: @tournament, role: "turnier_leiter", granted_by: granter)

    acc = McpServer::CcAccountResolver.resolve(user: tl, tournament: @tournament)
    assert_equal :none, acc.source
    assert_not acc.resolved?
    assert_equal tl.id, acc.acting_user_id
  end

  test ":none — Legacy-UserTournament ohne granted_by" do
    tl = make_user(email: "tl3@test.de", with_creds: false)
    UserTournament.create!(user: tl, tournament: @tournament, role: "turnier_leiter")

    acc = McpServer::CcAccountResolver.resolve(user: tl, tournament: @tournament)
    assert_equal :none, acc.source
  end

  test ":none — nur globaler turnier_leiter_user_id (kein UserTournament, D-39-6)" do
    user = make_user(email: "globaltl@test.de", with_creds: false)
    @tournament.update!(turnier_leiter_user_id: user.id)

    acc = McpServer::CcAccountResolver.resolve(user: user, tournament: @tournament)
    assert_equal :none, acc.source, "globaler TL-Pfad hat keinen granter → :none (kein shared_fallback)"
  end

  test ":none — normaler User ohne Creds, kein TL" do
    user = make_user(email: "plain@test.de", with_creds: false)
    acc = McpServer::CcAccountResolver.resolve(user: user, tournament: @tournament)
    assert_equal :none, acc.source
    assert_not acc.resolved?
  end

  test ":none — user nil" do
    acc = McpServer::CcAccountResolver.resolve(user: nil, tournament: @tournament)
    assert_equal :none, acc.source
    assert_nil acc.acting_user_id
  end
end
