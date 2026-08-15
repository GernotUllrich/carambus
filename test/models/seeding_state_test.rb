# frozen_string_literal: true

require "test_helper"

# Unit-Test der Seeding-Zustandsmaschine (Plan 32-04, Konzern B Write-Side, Modell X).
# Events: seed (registered->seeded), participate (registered/seeded->participated),
# mark_no_show (->no_show), reset_seeding_state (->registered). Ziel-Zustaende idempotent.
# LocalProtector ist im Test deaktiviert (LocalProtectorTestOverride in test_helper.rb).
class SeedingStateTest < ActiveSupport::TestCase
  def setup
    @tournament = Tournament.create!(
      id: 9_610_001,
      title: "Seeding-State Test",
      season_id: 50_000_001,
      organizer_id: 50_000_001,
      organizer_type: "Region",
      discipline_id: 50_000_004,
      tournament_plan_id: 50_000_100,
      player_class: "1",
      state: "tournament_mode_defined",
      date: 2.weeks.from_now,
      handicap_tournier: false
    )
  end

  # Eindeutige id je Aufruf (kollisionsfest unabhaengig vom Fixture-/Rollback-Verhalten).
  @@seeding_seq = 50_900_600
  def next_seeding_id
    @@seeding_seq += 1
  end

  def seeding(id: nil, state: nil)
    attrs = {
      id: id || next_seeding_id,
      player_id: 50_001_001,
      tournament_id: @tournament.id,
      tournament_type: "Tournament",
      position: 1
    }
    attrs[:state] = state if state
    Seeding.create!(**attrs)
  end

  test "registered ist der Initialzustand" do
    assert_equal "registered", seeding.state
    assert seeding.registered?
  end

  test "seed: registered -> seeded" do
    s = seeding
    s.seed!
    assert_equal "seeded", s.reload.state
  end

  test "participate: registered -> participated" do
    s = seeding
    s.participate!
    assert_equal "participated", s.reload.state
  end

  test "participate: seeded -> participated" do
    s = seeding
    s.seed!
    s.participate!
    assert_equal "participated", s.reload.state
  end

  test "mark_no_show und reset_seeding_state" do
    s = seeding(state: "participated")
    s.mark_no_show!
    assert_equal "no_show", s.reload.state
    s.reset_seeding_state!
    assert_equal "registered", s.reload.state
  end

  test "seed und participate sind idempotent (Ziel in from-Liste)" do
    s = seeding
    s.seed!
    assert_nothing_raised { s.seed! }
    assert_equal "seeded", s.reload.state

    s.participate!
    assert_nothing_raised { s.participate! }
    assert_equal "participated", s.reload.state
  end
end
