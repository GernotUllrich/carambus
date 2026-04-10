# frozen_string_literal: true

require "test_helper"

# UploadsController tests — the create action uses file I/O and mailers so is not
# tested here. Index, show, edit, update, and destroy are covered.
class UploadsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @upload = uploads(:one)
    @user = users(:admin)
    sign_in @user
  end

  test "should get index" do
    get uploads_url
    assert_response :success
  end

  test "should show upload" do
    get upload_url(@upload)
    assert_response :success
  end

  test "should get edit" do
    get edit_upload_url(@upload)
    assert_response :success
  end

  test "should update upload" do
    patch upload_url(@upload), params: { upload: { position: 2 } }
    assert_redirected_to upload_url(@upload)
  end

  test "should destroy upload" do
    assert_difference("Upload.count", -1) do
      delete upload_url(@upload)
    end

    assert_redirected_to uploads_url
  end

  test "edit requires login" do
    sign_out @user
    get edit_upload_url(@upload)
    assert_redirected_to root_path
  end
end
