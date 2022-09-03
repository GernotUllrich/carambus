require "application_system_test_case"

class IonContentsTest < ApplicationSystemTestCase
  setup do
    @ion_content = ion_contents(:one)
  end

  test "visiting the index" do
    visit ion_contents_url
    assert_selector "h1", text: "Ion Contents"
  end

  test "creating a Ion content" do
    visit ion_contents_url
    click_on "New Ion Content"

    fill_in "Data", with: @ion_content.data
    fill_in "Deep scraped at", with: @ion_content.deep_scraped_at
    fill_in "Html", with: @ion_content.html
    fill_in "Ion content", with: @ion_content.ion_content_id
    fill_in "Level", with: @ion_content.level
    fill_in "Page", with: @ion_content.page_id
    fill_in "Position", with: @ion_content.position
    fill_in "Scraped at", with: @ion_content.scraped_at
    fill_in "Title", with: @ion_content.title
    click_on "Create Ion content"

    assert_text "Ion content was successfully created"
    assert_selector "h1", text: "Ion Contents"
  end

  test "updating a Ion content" do
    visit ion_content_url(@ion_content)
    click_on "Edit", match: :first

    fill_in "Data", with: @ion_content.data
    fill_in "Deep scraped at", with: @ion_content.deep_scraped_at
    fill_in "Html", with: @ion_content.html
    fill_in "Ion content", with: @ion_content.ion_content_id
    fill_in "Level", with: @ion_content.level
    fill_in "Page", with: @ion_content.page_id
    fill_in "Position", with: @ion_content.position
    fill_in "Scraped at", with: @ion_content.scraped_at
    fill_in "Title", with: @ion_content.title
    click_on "Update Ion content"

    assert_text "Ion content was successfully updated"
    assert_selector "h1", text: "Ion Contents"
  end

  test "destroying a Ion content" do
    visit edit_ion_content_url(@ion_content)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Ion content was successfully destroyed"
  end
end
