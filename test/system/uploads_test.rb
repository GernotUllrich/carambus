require "application_system_test_case"

class UploadsTest < ApplicationSystemTestCase
  setup do
    @upload = uploads(:one)
  end

  test "visiting the index" do
    visit uploads_url
    assert_selector "h1", text: "Uploads"
  end

  test "creating a Upload" do
    visit uploads_url
    click_on "New Upload"

    fill_in "Filename", with: @upload.filename
    fill_in "Position", with: @upload.position
    fill_in "User", with: @upload.user_id
    click_on "Create Upload"

    assert_text "Upload was successfully created"
    assert_selector "h1", text: "Uploads"
  end

  test "updating a Upload" do
    visit upload_url(@upload)
    click_on "Edit", match: :first

    fill_in "Filename", with: @upload.filename
    fill_in "Position", with: @upload.position
    fill_in "User", with: @upload.user_id
    click_on "Update Upload"

    assert_text "Upload was successfully updated"
    assert_selector "h1", text: "Uploads"
  end

  test "destroying a Upload" do
    visit edit_upload_url(@upload)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Upload was successfully destroyed"
  end
end
