require "application_system_test_case"

class IonModulesTest < ApplicationSystemTestCase
  setup do
    @ion_module = ion_modules(:one)
  end

  test "visiting the index" do
    visit ion_modules_url
    assert_selector "h1", text: "Ion Modules"
  end

  test "creating a Ion module" do
    visit ion_modules_url
    click_on "New Ion Module"

    fill_in "Data", with: @ion_module.data
    fill_in "Html", with: @ion_module.html
    fill_in "Ion content", with: @ion_module.ion_content_id
    fill_in "Module", with: @ion_module.module_id
    fill_in "Module type", with: @ion_module.module_type
    fill_in "Position", with: @ion_module.position
    click_on "Create Ion module"

    assert_text "Ion module was successfully created"
    assert_selector "h1", text: "Ion Modules"
  end

  test "updating a Ion module" do
    visit ion_module_url(@ion_module)
    click_on "Edit", match: :first

    fill_in "Data", with: @ion_module.data
    fill_in "Html", with: @ion_module.html
    fill_in "Ion content", with: @ion_module.ion_content_id
    fill_in "Module", with: @ion_module.module_id
    fill_in "Module type", with: @ion_module.module_type
    fill_in "Position", with: @ion_module.position
    click_on "Update Ion module"

    assert_text "Ion module was successfully updated"
    assert_selector "h1", text: "Ion Modules"
  end

  test "destroying a Ion module" do
    visit edit_ion_module_url(@ion_module)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Ion module was successfully destroyed"
  end
end
