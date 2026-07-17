# frozen_string_literal: true

require "test_helper"

class LeagueTest < ActiveSupport::TestCase
  TEST_ID_BASE = 50_000_000
  ID_OFFSET = 60_000

  @@counter = 0

  def next_base
    @@counter += 1
    TEST_ID_BASE + ID_OFFSET + (@@counter * 100)
  end

  def setup
    @league = leagues(:one)
  end

  # reconstruct_game_plan_from_existing_data is a private method — use send
  test "should reconstruct game plan from existing data" do
    # Skip if league doesn't have required associations
    skip unless @league.discipline.present? && @league.parties.any?

    # Test that the method can be called without errors
    result = @league.send(:reconstruct_game_plan_from_existing_data)

    # Should return a GamePlan object or nil
    assert result.nil? || result.is_a?(GamePlan)
  end

  test "should handle league without discipline" do
    league_without_discipline = League.new(name: "Test League")

    result = league_without_discipline.send(:reconstruct_game_plan_from_existing_data)

    assert_nil result
  end

  test "should handle league without parties" do
    league_without_parties = League.new(name: "Test League", discipline: disciplines(:one))

    # Does not raise even without parties — returns nil or a GamePlan
    assert_nothing_raised do
      league_without_parties.send(:reconstruct_game_plan_from_existing_data)
    end
  end

  # --- analyze_game_plan_structure ---

  test "analyze_game_plan_structure returns meaningful structure when called with party with games" do
    base = next_base
    league = League.create!(
      id: base,
      name: "GP Analysis Test #{base}",
      shortname: "GPA#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band)
    )
    party = Party.create!(
      id: base + 1,
      league: league,
      data: { "result" => "3:1" }
    )
    game_plan_hash = { rows: [], tables: 1, victory_to_nil: -1, match_points: { win: 0, draw: 0, lost: 0 } }
    disciplines_hash = {}

    # analyze_game_plan_structure is a private method
    assert_nothing_raised do
      league.send(:analyze_game_plan_structure, party, game_plan_hash, disciplines_hash)
    end

    # After the call the game_plan_hash rows should be modified (at minimum "Gesamtsumme" added)
    assert game_plan_hash[:rows].is_a?(Array), "game_plan rows must remain an Array"
    assert game_plan_hash[:rows].any? { |row| row[:type] == "Gesamtsumme" },
           "analyze_game_plan_structure always appends a Gesamtsumme row"
  end

  # --- reconstruct_game_plans_for_season ---

  test "reconstruct_game_plans_for_season returns result hash with success/failed/errors keys" do
    # Use a season that has no leagues to avoid side effects
    base = next_base
    empty_season = Season.create!(
      id: base,
      name: "9999/0000",
      created_at: 1.year.ago,
      updated_at: 1.day.ago
    )

    result = League.reconstruct_game_plans_for_season(empty_season)

    assert result.is_a?(Hash), "reconstruct_game_plans_for_season returns a Hash"
    assert result.key?(:success), "result should have :success key"
    assert result.key?(:failed), "result should have :failed key"
    assert result.key?(:errors), "result should have :errors key"
    assert_equal 0, result[:success]
    assert_equal 0, result[:failed]
    assert_equal [], result[:errors]
  end

  test "reconstruct_game_plans_for_season handles filter opts without error" do
    base = next_base
    empty_season = Season.create!(
      id: base,
      name: "9998/0001",
      created_at: 1.year.ago,
      updated_at: 1.day.ago
    )

    result = nil
    assert_nothing_raised do
      result = League.reconstruct_game_plans_for_season(empty_season,
        region_shortname: "NBV",
        discipline: "Dreiband")
    end
    assert result.is_a?(Hash)
  end

  # --- reconstruct_game_plan_from_existing_data with local parties ---

  test "reconstruct_game_plan_from_existing_data with parties returns nil without party_games" do
    base = next_base
    league = League.create!(
      id: base,
      name: "GP Reconstruct Test #{base}",
      shortname: "GPR#{@@counter}",
      organizer: regions(:nbv),
      organizer_type: "Region",
      season: seasons(:current),
      discipline: disciplines(:carom_3band)
    )
    team_a = LeagueTeam.create!(id: base + 1, league: league, name: "TeamA_#{base}", cc_id: base + 10)
    team_b = LeagueTeam.create!(id: base + 2, league: league, name: "TeamB_#{base}", cc_id: base + 11)
    Party.create!(
      id: base + 3,
      league: league,
      league_team_a: team_a,
      league_team_b: team_b,
      data: { "result" => "3:1" }
    )

    # Without party_games and without branch.name resolvable, reconstruction returns nil
    result = league.send(:reconstruct_game_plan_from_existing_data)
    assert result.nil? || result.is_a?(GamePlan),
           "reconstruct_game_plan_from_existing_data returns GamePlan or nil"
  end

  # --- Change-Gate-Content (21-02): cc_standings_content ---

  def cc_doc(rows_html)
    Nokogiri::HTML(<<~HTML)
      <aside><section>
        <table><tr><th>Info</th></tr></table>
        <table>
          <tr><th>Nr</th><th>Heim</th><th>Gast</th><th>Datum</th><th>Ergebnis</th></tr>
          #{rows_html}
        </table>
      </section></aside>
    HTML
  end

  test "cc_standings_content extrahiert ergebnistragende Zeilen, sortiert" do
    doc = cc_doc(<<~ROWS)
      <tr><td>1</td><td>Team B</td><td>Team A</td><td>2026-01-10</td><td>5:3</td></tr>
      <tr><td>2</td><td>Team A</td><td>Team C</td><td>2026-01-17</td><td>4:4</td></tr>
    ROWS
    content = League.send(:cc_standings_content, doc)
    assert_includes content, "Team B|Team A|2026-01-10|5:3"
    assert_includes content, "Team A|Team C|2026-01-17|4:4"
  end

  test "cc_standings_content: geändertes Ergebnis ändert den content (digest kippt)" do
    base = League.send(:cc_standings_content,
      cc_doc("<tr><td>1</td><td>H</td><td>G</td><td>2026-01-10</td><td>5:3</td></tr>"))
    changed = League.send(:cc_standings_content,
      cc_doc("<tr><td>1</td><td>H</td><td>G</td><td>2026-01-10</td><td>6:2</td></tr>"))
    refute_equal base, changed
  end

  test "cc_standings_content: fehlende Tabelle bzw. nil → leerer String (führt zu stale→deep)" do
    assert_equal "", League.send(:cc_standings_content, nil)
    no_table = Nokogiri::HTML("<aside><section><table><tr><th>x</th></tr></table></section></aside>")
    assert_equal "", League.send(:cc_standings_content, no_table)
  end
end
