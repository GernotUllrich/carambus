require "application_system_test_case"

class TournamentsTest < ApplicationSystemTestCase
  setup do
    @tournament = tournaments(:one)
  end

  test "visiting the index" do
    visit tournaments_url
    assert_selector "h1", text: "Tournaments"
  end

  test "creating a Tournament" do
    visit tournaments_url
    click_on "New Tournament"

    fill_in "Accredation end", with: @tournament.accredation_end
    fill_in "Age restriction", with: @tournament.age_restriction
    fill_in "Ba", with: @tournament.ba_id
    fill_in "Ba state", with: @tournament.ba_state
    fill_in "Balls goal", with: @tournament.balls_goal
    fill_in "Data", with: @tournament.data
    fill_in "Date", with: @tournament.date
    fill_in "Discipline", with: @tournament.discipline_id
    fill_in "End date", with: @tournament.end_date
    check "Handicap tournier" if @tournament.handicap_tournier
    fill_in "Innings goal", with: @tournament.innings_goal
    fill_in "Last ba sync date", with: @tournament.last_ba_sync_date
    fill_in "Location", with: @tournament.location
    fill_in "Modus", with: @tournament.modus
    fill_in "Plan or show", with: @tournament.plan_or_show
    fill_in "Player class", with: @tournament.player_class
    fill_in "Region", with: @tournament.region_id
    fill_in "Season", with: @tournament.season_id
    fill_in "Shortname", with: @tournament.shortname
    fill_in "Single or league", with: @tournament.single_or_league
    fill_in "State", with: @tournament.state
    fill_in "Title", with: @tournament.title
    fill_in "Tournament plan", with: @tournament.tournament_plan_id
    click_on "Create Tournament"

    assert_text "Tournament was successfully created"
    assert_selector "h1", text: "Tournaments"
  end

  test "updating a Tournament" do
    visit tournament_url(@tournament)
    click_on "Edit", match: :first

    fill_in "Accredation end", with: @tournament.accredation_end
    fill_in "Age restriction", with: @tournament.age_restriction
    fill_in "Ba", with: @tournament.ba_id
    fill_in "Ba state", with: @tournament.ba_state
    fill_in "Balls goal", with: @tournament.balls_goal
    fill_in "Data", with: @tournament.data
    fill_in "Date", with: @tournament.date
    fill_in "Discipline", with: @tournament.discipline_id
    fill_in "End date", with: @tournament.end_date
    check "Handicap tournier" if @tournament.handicap_tournier
    fill_in "Hosting club", with: @tournament.hosting_club_id
    fill_in "Innings goal", with: @tournament.innings_goal
    fill_in "Last ba sync date", with: @tournament.last_ba_sync_date
    fill_in "Location", with: @tournament.location
    fill_in "Modus", with: @tournament.modus
    fill_in "Plan or show", with: @tournament.plan_or_show
    fill_in "Player class", with: @tournament.player_class
    fill_in "Region", with: @tournament.region_id
    fill_in "Season", with: @tournament.season_id
    fill_in "Shortname", with: @tournament.shortname
    fill_in "Single or league", with: @tournament.single_or_league
    fill_in "State", with: @tournament.state
    fill_in "Title", with: @tournament.title
    fill_in "Tournament plan", with: @tournament.tournament_plan_id
    click_on "Update Tournament"

    assert_text "Tournament was successfully updated"
    assert_selector "h1", text: "Tournaments"
  end

  test "destroying a Tournament" do
    visit edit_tournament_url(@tournament)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament was successfully destroyed"
  end
end
