require "application_system_test_case"

class TournamentCcsTest < ApplicationSystemTestCase
  setup do
    @tournament_cc = tournament_ccs(:one)
  end

  test "visiting the index" do
    visit tournament_ccs_url
    assert_selector "h1", text: "Tournament Ccs"
  end

  test "creating a Tournament cc" do
    visit tournament_ccs_url
    click_on "New Tournament Cc"

    fill_in "Branch cc", with: @tournament_cc.branch_cc_id
    fill_in "Category cc", with: @tournament_cc.category_cc_id
    fill_in "Cc", with: @tournament_cc.cc_id
    fill_in "Championship type cc", with: @tournament_cc.championship_type_cc_id
    fill_in "Context", with: @tournament_cc.context
    fill_in "Description", with: @tournament_cc.description
    fill_in "Discipline", with: @tournament_cc.discipline_id
    fill_in "Entry fee", with: @tournament_cc.entry_fee
    fill_in "Flowchart", with: @tournament_cc.flowchart
    fill_in "Group cc", with: @tournament_cc.group_cc_id
    fill_in "League climber quote", with: @tournament_cc.league_climber_quote
    fill_in "Location", with: @tournament_cc.location_id
    fill_in "Location text", with: @tournament_cc.location_text
    fill_in "Max players", with: @tournament_cc.max_players
    fill_in "Name", with: @tournament_cc.name
    fill_in "Poster", with: @tournament_cc.poster
    fill_in "Ranking list", with: @tournament_cc.ranking_list
    fill_in "Registration list cc", with: @tournament_cc.registration_list_cc_id
    fill_in "Registration rule", with: @tournament_cc.registration_rule
    fill_in "Season", with: @tournament_cc.season
    fill_in "Shortname", with: @tournament_cc.shortname
    fill_in "Starting at", with: @tournament_cc.starting_at
    fill_in "Status", with: @tournament_cc.status
    fill_in "Successor list", with: @tournament_cc.successor_list
    fill_in "Tender", with: @tournament_cc.tender
    fill_in "Tournament end", with: @tournament_cc.tournament_end
    fill_in "Tournament series cc", with: @tournament_cc.tournament_series_cc_id
    fill_in "Tournament start", with: @tournament_cc.tournament_start
    click_on "Create Tournament cc"

    assert_text "Tournament cc was successfully created"
    assert_selector "h1", text: "Tournament Ccs"
  end

  test "updating a Tournament cc" do
    visit tournament_cc_url(@tournament_cc)
    click_on "Edit", match: :first

    fill_in "Branch cc", with: @tournament_cc.branch_cc_id
    fill_in "Category cc", with: @tournament_cc.category_cc_id
    fill_in "Cc", with: @tournament_cc.cc_id
    fill_in "Championship type cc", with: @tournament_cc.championship_type_cc_id
    fill_in "Context", with: @tournament_cc.context
    fill_in "Description", with: @tournament_cc.description
    fill_in "Discipline", with: @tournament_cc.discipline_id
    fill_in "Entry fee", with: @tournament_cc.entry_fee
    fill_in "Flowchart", with: @tournament_cc.flowchart
    fill_in "Group cc", with: @tournament_cc.group_cc_id
    fill_in "League climber quote", with: @tournament_cc.league_climber_quote
    fill_in "Location", with: @tournament_cc.location_id
    fill_in "Location text", with: @tournament_cc.location_text
    fill_in "Max players", with: @tournament_cc.max_players
    fill_in "Name", with: @tournament_cc.name
    fill_in "Poster", with: @tournament_cc.poster
    fill_in "Ranking list", with: @tournament_cc.ranking_list
    fill_in "Registration list cc", with: @tournament_cc.registration_list_cc_id
    fill_in "Registration rule", with: @tournament_cc.registration_rule
    fill_in "Season", with: @tournament_cc.season
    fill_in "Shortname", with: @tournament_cc.shortname
    fill_in "Starting at", with: @tournament_cc.starting_at
    fill_in "Status", with: @tournament_cc.status
    fill_in "Successor list", with: @tournament_cc.successor_list
    fill_in "Tender", with: @tournament_cc.tender
    fill_in "Tournament end", with: @tournament_cc.tournament_end
    fill_in "Tournament series cc", with: @tournament_cc.tournament_series_cc_id
    fill_in "Tournament start", with: @tournament_cc.tournament_start
    click_on "Update Tournament cc"

    assert_text "Tournament cc was successfully updated"
    assert_selector "h1", text: "Tournament Ccs"
  end

  test "destroying a Tournament cc" do
    visit edit_tournament_cc_url(@tournament_cc)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Tournament cc was successfully destroyed"
  end
end
