require "application_system_test_case"

class WordlesTest < ApplicationSystemTestCase
  setup do
    @wordle = wordles(:one)
  end

  test "visiting the index" do
    visit wordles_url
    assert_selector "h1", text: "Wordles"
  end

  test "creating a Wordle" do
    visit wordles_url
    click_on "New Wordle"

    fill_in "Data", with: @wordle.data
    fill_in "Hints", with: @wordle.hints
    fill_in "Seqno", with: @wordle.seqno
    fill_in "Words", with: @wordle.words
    click_on "Create Wordle"

    assert_text "Wordle was successfully created"
    assert_selector "h1", text: "Wordles"
  end

  test "updating a Wordle" do
    visit wordle_url(@wordle)
    click_on "Edit", match: :first

    fill_in "Data", with: @wordle.data
    fill_in "Hints", with: @wordle.hints
    fill_in "Seqno", with: @wordle.seqno
    fill_in "Words", with: @wordle.words
    click_on "Update Wordle"

    assert_text "Wordle was successfully updated"
    assert_selector "h1", text: "Wordles"
  end

  test "destroying a Wordle" do
    visit edit_wordle_url(@wordle)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Wordle was successfully destroyed"
  end
end
