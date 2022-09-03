require "test_helper"

class IonModulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @ion_module = ion_modules(:one)
  end

  test "should get index" do
    get ion_modules_url
    assert_response :success
  end

  test "should get new" do
    get new_ion_module_url
    assert_response :success
  end

  test "should create ion_module" do
    assert_difference('IonModule.count') do
      post ion_modules_url, params: { ion_module: { data: @ion_module.data, html: @ion_module.html, ion_content_id: @ion_module.ion_content_id, module_id: @ion_module.module_id, module_type: @ion_module.module_type, position: @ion_module.position } }
    end

    assert_redirected_to ion_module_url(IonModule.last)
  end

  test "should show ion_module" do
    get ion_module_url(@ion_module)
    assert_response :success
  end

  test "should get edit" do
    get edit_ion_module_url(@ion_module)
    assert_response :success
  end

  test "should update ion_module" do
    patch ion_module_url(@ion_module), params: { ion_module: { data: @ion_module.data, html: @ion_module.html, ion_content_id: @ion_module.ion_content_id, module_id: @ion_module.module_id, module_type: @ion_module.module_type, position: @ion_module.position } }
    assert_redirected_to ion_module_url(@ion_module)
  end

  test "should destroy ion_module" do
    assert_difference('IonModule.count', -1) do
      delete ion_module_url(@ion_module)
    end

    assert_redirected_to ion_modules_url
  end
end
