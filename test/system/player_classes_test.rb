require "application_system_test_case"

class PlayerClassesTest < ApplicationSystemTestCase
  setup do
    @player_class = player_classes(:one)
  end

  test "visiting the index" do
    visit player_classes_url
    assert_selector "h1", text: "Player Classes"
  end

  test "creating a Player class" do
    visit player_classes_url
    click_on "New Player Class"

    fill_in "Discipline", with: @player_class.discipline_id
    fill_in "Shortname", with: @player_class.shortname
    click_on "Create Player class"

    assert_text "Player class was successfully created"
    assert_selector "h1", text: "Player Classes"
  end

  test "updating a Player class" do
    visit player_class_url(@player_class)
    click_on "Edit", match: :first

    fill_in "Discipline", with: @player_class.discipline_id
    fill_in "Shortname", with: @player_class.shortname
    click_on "Update Player class"

    assert_text "Player class was successfully updated"
    assert_selector "h1", text: "Player Classes"
  end

  test "destroying a Player class" do
    visit edit_player_class_url(@player_class)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Player class was successfully destroyed"
  end
end
