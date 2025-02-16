require "application_system_test_case"

class SlotsTest < ApplicationSystemTestCase
  setup do
    @slot = slots(:one)
  end

  test "visiting the index" do
    visit slots_url
    assert_selector "h1", text: "Slots"
  end

  test "creating a Slot" do
    visit slots_url
    click_on "New Slot"

    fill_in "Dayofweek", with: @slot.dayofweek
    fill_in "Hourofday end", with: @slot.hourofday_end
    fill_in "Hourofday start", with: @slot.hourofday_start
    fill_in "Minuteofhour end", with: @slot.minuteofhour_end
    fill_in "Minuteofhour start", with: @slot.minuteofhour_start
    fill_in "Next end", with: @slot.next_end
    fill_in "Next start", with: @slot.next_start
    check "Recurring" if @slot.recurring
    fill_in "Table", with: @slot.table_id
    click_on "Create Slot"

    assert_text "Slot was successfully created"
    assert_selector "h1", text: "Slots"
  end

  test "updating a Slot" do
    visit slot_url(@slot)
    click_on "Edit", match: :first

    fill_in "Dayofweek", with: @slot.dayofweek
    fill_in "Hourofday end", with: @slot.hourofday_end
    fill_in "Hourofday start", with: @slot.hourofday_start
    fill_in "Minuteofhour end", with: @slot.minuteofhour_end
    fill_in "Minuteofhour start", with: @slot.minuteofhour_start
    fill_in "Next end", with: @slot.next_end
    fill_in "Next start", with: @slot.next_start
    check "Recurring" if @slot.recurring
    fill_in "Table", with: @slot.table_id
    click_on "Update Slot"

    assert_text "Slot was successfully updated"
    assert_selector "h1", text: "Slots"
  end

  test "destroying a Slot" do
    visit edit_slot_url(@slot)
    click_on "Delete", match: :first
    click_on "Confirm"

    assert_text "Slot was successfully destroyed"
  end
end
