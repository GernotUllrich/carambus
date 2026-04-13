# frozen_string_literal: true

require "test_helper"

# Characterization tests for LeagueTeam (63 lines).
# Per D-07: test associations, cc_id_link, empty scrape method, and name attribute.
class LeagueTeamTest < ActiveSupport::TestCase
  def setup
    @league_team = league_teams(:team_alpha)
  end

  # --- Association tests ---

  test "belongs to league" do
    assert_not_nil @league_team.league
    assert_instance_of League, @league_team.league
  end

  test "has many parties_a (home)" do
    assert @league_team.respond_to?(:parties_a)
    assert @league_team.parties_a.is_a?(ActiveRecord::Associations::CollectionProxy)
  end

  test "has many parties_b (guest)" do
    assert @league_team.respond_to?(:parties_b)
    assert @league_team.parties_b.is_a?(ActiveRecord::Associations::CollectionProxy)
  end

  test "has many seedings" do
    assert @league_team.respond_to?(:seedings)
  end

  # --- cc_id_link test ---

  test "cc_id_link returns URL containing cc_id" do
    # The method calls league.organizer.public_cc_url_base and league.season.name.
    # The test league fixture has no season and the region fixture has no cc_id/public_cc_url_base.
    # Stub these on the organizer and season objects so the method can execute.
    organizer = @league_team.league.organizer
    organizer.define_singleton_method(:public_cc_url_base) { "https://nbv.club-cloud.de/" }
    organizer.define_singleton_method(:cc_id) { 42 }

    mock_season = OpenStruct.new(name: "2025/2026")
    @league_team.league.define_singleton_method(:season) { mock_season }
    @league_team.league.define_singleton_method(:cc_id) { 7 }
    @league_team.league.define_singleton_method(:cc_id2) { nil }

    url = @league_team.cc_id_link
    assert_includes url, "101"
    assert_includes url, "https://nbv.club-cloud.de/"
  end

  # --- scrape_players_from_ba_league_team test ---

  test "scrape_players_from_ba_league_team returns nil without raising" do
    result = nil
    assert_nothing_raised do
      result = @league_team.scrape_players_from_ba_league_team
    end
    assert_nil result
  end

  # --- name attribute test ---

  test "name returns the team name" do
    assert_equal "Team Alpha", @league_team.name
  end
end
