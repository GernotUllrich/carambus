# frozen_string_literal: true

require "test_helper"

# Phase 34-01 + D-38: Tests für UserPersonas-Concern.
# D-38: sportwart? kommt aus EXPLIZITEN persona_grants ("sportwart"/"landessportwart"),
# NICHT mehr aus Join-Präsenz. Schreibrecht (D-34-1) = system_admin ODER Sportwart ODER Turnierleiter.
class UserPersonasTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
  end

  test "reiner player ohne Grants: personas [:player], kein Sportwart, kein Schreibrecht" do
    u = User.create!(email: "up_player@test.de", password: "password123")
    assert_equal [:player], u.personas
    assert_not u.sportwart?
    assert_not u.landessportwart?
    assert_not u.turnierleiter?
    assert_not u.cc_write_access?
  end

  test "persona_grants=[sportwart]: sportwart? true, personas enthält :sportwart, Schreibrecht" do
    u = User.create!(email: "up_sw@test.de", password: "password123", persona_grants: ["sportwart"])
    assert u.sportwart?
    assert_not u.landessportwart?
    assert_includes u.personas, :sportwart
    assert u.cc_write_access?
  end

  test "persona_grants=[landessportwart]: sportwart? UND landessportwart? true, Schreibrecht" do
    u = User.create!(email: "up_lsw@test.de", password: "password123", persona_grants: ["landessportwart"])
    assert u.sportwart?
    assert u.landessportwart?
    assert_includes u.personas, :landessportwart
    assert_not_includes u.personas, :sportwart
    assert u.cc_write_access?
  end

  test "D-38: leeres Fallback-Input in persona_grants wird normalisiert (kein Leerstring gespeichert)" do
    u = User.create!(email: "up_norm@test.de", password: "password123", persona_grants: ["", "landessportwart"])
    assert_equal ["landessportwart"], u.persona_grants
  end

  test "D-38: Location-/Disziplin-Join OHNE persona_grants → NICHT Sportwart (kein Schreibrecht)" do
    u = User.create!(email: "up_jointonly@test.de", password: "password123")
    u.sportwart_locations << @location
    u.sportwart_disciplines << @discipline
    assert_not u.sportwart?, "Join-Präsenz allein macht keinen Sportwart mehr (D-38)"
    assert_not u.cc_write_access?
  end

  test "Turnierleiter eines Tournaments: turnierleiter? true, personas enthält :turnierleiter, Schreibrecht" do
    u = User.create!(email: "up_tl@test.de", password: "password123")
    Tournament.create!(
      title: "UP-TL-Test", season_id: 50_000_001,
      organizer_id: 50_000_001, organizer_type: "Region",
      discipline_id: @discipline.id, tournament_plan_id: 50_000_100,
      location_id: @location.id, state: "tournament_mode_defined",
      date: 1.week.from_now, turnier_leiter_user_id: u.id
    )
    assert u.turnierleiter?
    assert_includes u.personas, :turnierleiter
    assert u.cc_write_access?
  end

  test "system_admin: Schreibrecht true (auch ohne Grants/TL)" do
    u = User.create!(email: "up_admin@test.de", password: "password123", role: :system_admin)
    assert u.system_admin?
    assert u.cc_write_access?
    assert_includes u.personas, :system_admin
  end

  test "club_admin ohne Grants/TL: kein Schreibrecht (read-only)" do
    u = User.create!(email: "up_clubadmin@test.de", password: "password123", role: :club_admin)
    assert_not u.cc_write_access?
    assert_equal [:club_admin], u.personas
  end

  test "turnierleiter?-Guard: unsaved User (id nil) → false" do
    u = User.new(email: "up_unsaved@test.de", password: "password123")
    assert_not u.turnierleiter?
    assert_not u.cc_write_access?
  end

  # Phase 34-03 (D-34-5): Union — turnierleiter? auch via lokale UserTournament-Relation.
  test "Union: turnierleiter? via UserTournament (ohne globales turnier_leiter_user_id)" do
    u = User.create!(email: "up_ut@test.de", password: "password123")
    UserTournament.create!(user: u, tournament: tournaments(:local), role: "turnier_leiter")
    assert u.turnierleiter?
    assert_includes u.personas, :turnierleiter
    assert u.cc_write_access?
  end
end
