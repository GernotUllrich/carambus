require "test_helper"

class IonContentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ion_content = ion_contents(:one)
  end

  test "should get index" do
    get ion_contents_url
    assert_response :success
  end

  test "should get new" do
    get new_ion_content_url
    assert_response :success
  end

  test "should create ion_content" do
    assert_difference('IonContent.count') do
      post ion_contents_url, params: { ion_content: { data: @ion_content.data, deep_scraped_at: @ion_content.deep_scraped_at, html: @ion_content.html, ion_content_id: @ion_content.ion_content_id, level: @ion_content.level, page_id: @ion_content.page_id, position: @ion_content.position, scraped_at: @ion_content.scraped_at, title: @ion_content.title } }
    end

    assert_redirected_to ion_content_url(IonContent.last)
  end

  test "should show ion_content" do
    get ion_content_url(@ion_content)
    assert_response :success
  end

  test "should get edit" do
    get edit_ion_content_url(@ion_content)
    assert_response :success
  end

  test "should update ion_content" do
    patch ion_content_url(@ion_content), params: { ion_content: { data: @ion_content.data, deep_scraped_at: @ion_content.deep_scraped_at, html: @ion_content.html, ion_content_id: @ion_content.ion_content_id, level: @ion_content.level, page_id: @ion_content.page_id, position: @ion_content.position, scraped_at: @ion_content.scraped_at, title: @ion_content.title } }
    assert_redirected_to ion_content_url(@ion_content)
  end

  test "should destroy ion_content" do
    assert_difference('IonContent.count', -1) do
      delete ion_content_url(@ion_content)
    end

    assert_redirected_to ion_contents_url
  end
end
