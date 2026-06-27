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

  # Baut eine Party mit PartyMonitor-Rows + gespielten Games (gname/ended_at/ba_results)
  # für die Charakterisierung von Party#intermediate_result (Phase 47-02). KEIN echter Lauf.
  #
  # game_specs: Array von Hashes mit:
  #   :seqno, :type (Spiel-Typ), :sets (sets_to_win, default 1),
  #   :sets1, :sets2 (Satz-/Rack-Stand team_a/team_b),
  #   :ergebnis1, :ergebnis2 (optional, default = sets1/sets2),
  #   :game_points (optional Hash win/draw/lost), :played (default true).
  # Rows mit String-Keys (wie Produktions-JSON, das intermediate_result via row["..."] liest).
  def build_party_with_results(game_specs)
    result = create_party_monitor_with_party
    party = result[:party]
    party_monitor = result[:party_monitor]

    rows = game_specs.map do |s|
      row = {
        "seqno" => s[:seqno],
        "type" => s[:type],
        "sets" => s.fetch(:sets, 1)
      }
      row["game_points"] = s[:game_points] if s.key?(:game_points)
      row
    end
    party_monitor.update!(data: {"rows" => rows})

    game_specs.each do |s|
      next if s[:played] == false

      ba = {
        "Sets1" => s[:sets1], "Sets2" => s[:sets2],
        "Ergebnis1" => s.fetch(:ergebnis1, s[:sets1]),
        "Ergebnis2" => s.fetch(:ergebnis2, s[:sets2])
      }
      party.games.create!(
        gname: "#{s[:seqno]}-#{s[:type]}",
        seqno: s[:seqno],
        ended_at: Time.current,
        data: {"ba_results" => ba}
      )
    end
    party.reload
    {party: party, party_monitor: party_monitor}
  end
end
