# frozen_string_literal: true

require "test_helper"

# v1.0 Phase 34-01: Tests für UserPersonas-Concern (Persona-Ableitung + cc_write_access?).
# Schreibrecht (D-34-1) = system_admin ODER Sportwart ODER Turnierleiter.
class UserPersonasTest < ActiveSupport::TestCase
  setup do
    @location = locations(:one)
    @discipline = disciplines(:carom_3band)
  end

  test "reiner player: personas [:player], kein Schreibrecht" do
    u = User.create!(email: "up_player@test.de", password: "password123")
    assert_equal [:player], u.personas
    assert_not u.sportwart?
    assert_not u.turnierleiter?
    assert_not u.cc_write_access?
  end

  test "player mit Sportwart-Disziplin: personas enthält :sportwart, Schreibrecht true" do
    u = User.create!(email: "up_sw@test.de", password: "password123")
    u.sportwart_disciplines << @discipline
    assert u.sportwart?
    assert_includes u.personas, :sportwart
    assert u.cc_write_access?
  end

  test "player mit Sportwart-Location (ohne Disziplin): sportwart? true, Schreibrecht true" do
    u = User.create!(email: "up_swloc@test.de", password: "password123")
    u.sportwart_locations << @location
    assert u.sportwart?
    assert u.cc_write_access?
  end

  test "Turnierleiter eines Tournaments: turnierleiter? true, personas enthält :turnierleiter, Schreibrecht true" do
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

  test "system_admin: Schreibrecht true (auch ohne Sportwart-Scope/TL)" do
    u = User.create!(email: "up_admin@test.de", password: "password123", role: :system_admin)
    assert u.system_admin?
    assert u.cc_write_access?
    assert_includes u.personas, :system_admin
  end

  test "club_admin ohne Scope/TL: kein Schreibrecht (read-only)" do
    u = User.create!(email: "up_clubadmin@test.de", password: "password123", role: :club_admin)
    assert_not u.cc_write_access?
    assert_equal [:club_admin], u.personas
  end

  test "turnierleiter?-Guard: unsaved User (id nil) → false (matcht keine NULL-TL-Turniere)" do
    u = User.new(email: "up_unsaved@test.de", password: "password123")
    assert_not u.turnierleiter?
    assert_not u.cc_write_access?
  end
end
