# frozen_string_literal: true

require "test_helper"

# Regression guard for the Layer 3 fix landed alongside this file:
# `app/views/application/_left_nav.html.erb` previously had:
#
#     <li><%= link_to "Migration", migration_cc_region_path(Region[1]), ... %></li>
#
# When Region[1] was nil (test fixtures, fresh dev DBs, mid-migration), the
# call raised `ActionController::UrlGenerationError` and crashed the entire
# sidebar render for system_admin users.
#
# The original revision attempt wrapped the link in `if Region[1].present?`
# — REJECTED by the user: hiding the link doesn't let the admin pick which
# Region to migrate, and defaulting to a different Region would silently
# migrate the wrong data.
#
# The actual fix expands the single link into a nested Region-picker submenu:
# clicking "Migration" opens a sub-list of all Regions; each entry links to
# its own per-Region migration URL. These tests pin both the absence-of-crash
# property and the presence-of-per-Region-links property.
class LeftNavSystemAdminTest < ActionDispatch::IntegrationTest
  test "root_path renders 200 under system_admin without raising UrlGenerationError" do
    assert_nil Region.find_by(id: 1),
      "fixture invariant: Region[1] must be absent (NBV is at 50_000_001). " \
      "If this assertion fails, somebody added a Region at id=1 to the " \
      "fixtures — which is fine, but update the test accordingly."

    sign_in users(:system_admin)

    assert_nothing_raised do
      get root_path
    end
    assert_response :success

    # Sibling Club Cloud submenu links still render — the Migration block
    # didn't crash the layout.
    assert_match(/Meta Maps/, response.body,
      "Club Cloud submenu must still render even when Region[1] is absent")
  end

  test "Migration submenu emits one link per Region using migration_cc_region_path(region)" do
    sign_in users(:system_admin)

    get root_path
    assert_response :success

    # The NBV fixture at id 50_000_001 must appear as a real per-Region link.
    # The path helper renders id=50_000_001 as `50000001` (no underscore in URL).
    assert_match(%r{/regions/50000001/migration_cc}, response.body,
      "Migration submenu must emit a link to NBV's migration_cc URL")

    # The label must use Region#shortname (preferred) — `NBV` for the NBV fixture.
    # Match the literal `>NBV<` substring inside an anchor to avoid false
    # positives from class names / data attributes.
    assert_match(/>NBV</, response.body,
      "Migration submenu must use region.shortname as the link label")

    # The Migration submenu button itself must be present.
    assert_match(/Migration/, response.body,
      "Migration submenu button must render")
  end

  test "no broken /regions//migration_cc URL appears in rendered sidebar" do
    sign_in users(:system_admin)

    get root_path
    assert_response :success

    # Guard against any future regression that re-introduces a nil Region
    # lookup — even if the path helper somehow doesn't crash, an empty :id
    # segment in the URL is a smell that THIS test catches.
    assert_no_match(%r{/regions//migration_cc}, response.body,
      "URL with empty :id segment indicates a nil Region was passed " \
      "to migration_cc_region_path — regression to the original bug.")
  end
end
