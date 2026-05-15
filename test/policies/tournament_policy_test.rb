# frozen_string_literal: true

require "test_helper"

# D-14-G4 + D-14-G5: Tests für TournamentPolicy (Authority-Layer-Substrate).
class TournamentPolicyTest < ActiveSupport::TestCase
  setup do
    @sportwart_user = User.create!(email: "policy_sw@test.de", password: "password123")
    @tl_user = User.create!(email: "policy_tl@test.de", password: "password123")
    @random_user = User.create!(email: "policy_random@test.de", password: "password123")

    @location = locations(:one)
    @discipline = disciplines(:carom_3band)

    @sportwart_user.sportwart_locations << @location
    @sportwart_user.sportwart_disciplines << @discipline

    @tournament = Tournament.new(location_id: @location.id, discipline_id: @discipline.id)
    @tournament.turnier_leiter_user_id = @tl_user.id
  end

  test "anonymous user (nil) → alle 4 Methoden false" do
    p = TournamentPolicy.new(nil, @tournament)
    assert_not p.assign_leiter?
    assert_not p.update_deadline?
    assert_not p.manage_teilnehmerliste?
    assert_not p.enter_results?
  end

  test "random user (kein TL, kein Sportwart-Wirkbereich) → alle 4 Methoden false" do
    p = TournamentPolicy.new(@random_user, @tournament)
    assert_not p.assign_leiter?
    assert_not p.update_deadline?
    assert_not p.manage_teilnehmerliste?
    assert_not p.enter_results?
  end

  test "Sportwart im Wirkbereich (nicht TL) → assign_leiter? + update_deadline? + manage_teilnehmerliste? true; enter_results? false" do
    p = TournamentPolicy.new(@sportwart_user, @tournament)
    assert p.assign_leiter?
    assert p.update_deadline?
    assert p.manage_teilnehmerliste?
    assert_not p.enter_results?
  end

  test "TL für das Turnier (kein Sportwart) → update_deadline? + manage_teilnehmerliste? + enter_results? true; assign_leiter? false" do
    p = TournamentPolicy.new(@tl_user, @tournament)
    assert_not p.assign_leiter?, "TL darf NICHT TL für sein eigenes Turnier benennen (Authority-Boundary)"
    assert p.update_deadline?
    assert p.manage_teilnehmerliste?
    assert p.enter_results?
  end

  test "User ist gleichzeitig Sportwart UND TL → alle 4 Methoden true" do
    @sportwart_user.sportwart_locations << @location unless @sportwart_user.sportwart_locations.include?(@location)
    @tournament.turnier_leiter_user_id = @sportwart_user.id
    p = TournamentPolicy.new(@sportwart_user, @tournament)
    assert p.assign_leiter?
    assert p.update_deadline?
    assert p.manage_teilnehmerliste?
    assert p.enter_results?
  end

  test "Sportwart außerhalb der Location-Schnittmenge → alle 4 Methoden false" do
    other_tournament = Tournament.new(location_id: 99_999_999, discipline_id: @discipline.id)
    p = TournamentPolicy.new(@sportwart_user, other_tournament)
    assert_not p.assign_leiter?
    assert_not p.update_deadline?
    assert_not p.manage_teilnehmerliste?
    assert_not p.enter_results?
  end
end
