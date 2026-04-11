# frozen_string_literal: true

# PartyMonitorTestHelper — shared factory for PartyMonitor characterization tests.
#
# Creates a minimal PartyMonitor with associated Party and League using local IDs
# (>= 50_000_000) to avoid collisions with global records and fixtures.
# Uses class-level counter to ensure unique IDs across test invocations.
module PartyMonitorTestHelper
  TEST_ID_BASE = 50_000_000

  def create_party_monitor_with_party(attrs = {})
    @@pm_counter ||= 0
    @@pm_counter += 1
    base_id = TEST_ID_BASE + 30_000 + (@@pm_counter * 100)

    league = League.create!(
      id: base_id,
      name: "PM Test League #{@@pm_counter}",
      shortname: "PL#{@@pm_counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:one)
    )
    party = Party.create!(
      id: base_id + 1,
      league: league,
      sets_to_play: attrs.fetch(:sets_to_play, 1),
      sets_to_win: attrs.fetch(:sets_to_win, 1),
      team_size: attrs.fetch(:team_size, 1)
    )
    party_monitor = PartyMonitor.create!(
      id: base_id + 2,
      party: party,
      state: attrs.fetch(:state, "seeding_mode"),
      data: attrs.fetch(:data, {})
    )
    { party_monitor: party_monitor, party: party, league: league }
  end
end
