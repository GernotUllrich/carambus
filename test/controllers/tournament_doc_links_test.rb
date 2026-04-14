# frozen_string_literal: true

require "test_helper"

# Phase 37 Plan 05 Task 2: end-to-end lock-in for wizard doc-link rendering.
#
# DESIGN DECISION: This is a controller integration test (not a Capybara system
# test) per the plan's permitted fallback path. Reasons:
#
#   1. The canonical `tournaments(:local)` fixture requires FK repair via
#      update_columns before tournament show will render (see
#      TournamentsControllerTest#test "GET show renders reset modal …" for the
#      established repair pattern). A Capybara system test would need the same
#      repair AND a working headless-Chrome/selenium-manager toolchain, which
#      is not guaranteed in every dev environment.
#
#   2. No chromedriver is installed locally at the time of this plan (see
#      Plan 37-05 SUMMARY). Selenium-manager auto-download is unreliable in
#      sandboxed CI contexts — the controller test path is deterministic.
#
#   3. The assertions we care about (response body contains an <a> tag with the
#      correct /docs/... URL, target="_blank", rel="noopener") are fully
#      observable in the rendered ERB response body. No JavaScript interaction
#      is needed to verify LINK-02 / LINK-04.
#
# The plan's acceptance criteria explicitly permit this fallback path and
# require the SUMMARY to document the degrade reason (done in 37-05-SUMMARY.md).
#
# Assertions preserved verbatim per plan:
#   - at least one <a> href matches /docs/managers/tournament-management/
#     (optionally with #anchor) in DE locale
#   - at least one <a> href matches /docs/en/managers/tournament-management/
#     (optionally with #anchor) in EN locale
#   - target="_blank" and rel includes "noopener"
class TournamentDocLinksTest < ActionDispatch::IntegrationTest
  setup do
    @tournament = tournaments(:local)
    # Use club_admin — tournament_director?(user) checks user.club_admin? ||
    # user.system_admin?, NOT the plain `admin: true` flag on the :admin fixture.
    # The wizard_steps_v2 partial is gated on tournament_director? in show.html.erb:34.
    #
    # club_admin is preferred over system_admin here because _left_nav.html.erb:141
    # gates the ClubCloud section on `current_user&.system_admin?` and that section
    # includes `migration_cc_region_path(Region[1])`, which crashes with a routing
    # error when Region[1] is nil in the test DB. club_admin bypasses that sidebar
    # block entirely while still passing the tournament_director? gate.
    @user = users(:club_admin)

    # Save and restore API URL so tests don't bleed into each other.
    @original_api_url = Carambus.config.carambus_api_url

    # Enable local-server mode so TournamentsController#show renders the full
    # wizard path (not the API redirect).
    Carambus.config.carambus_api_url = "http://local.test"

    # Repair fixture association rot (same pattern as the reset-modal regression
    # test in tournaments_controller_test.rb). Without this, show.html.erb
    # crashes on `tournament.organizer.shortname` / `tournament.season.name`
    # before ever rendering the wizard partial.
    @tournament.update_columns(
      organizer_id: regions(:nbv).id,
      organizer_type: "Region",
      season_id: seasons(:current).id
    )
    @tournament.reload

    sign_in @user
  end

  teardown do
    Carambus.config.carambus_api_url = @original_api_url
  end

  test "tournament show renders DE wizard doc link with /docs/managers/tournament-management/ URL shape" do
    I18n.with_locale(:de) do
      get tournament_url(@tournament, locale: :de)
    end

    assert_response :success

    # At least one <a> pointing at the DE doc root path must exist in the body.
    # The wizard partial _wizard_steps_v2.html.erb renders 6 such links (Plan 37-03)
    # inside the collapsible <details> help blocks on show.html.erb.
    assert_match %r{href="/docs/managers/tournament-management/(#[a-z-]+)?"}, response.body,
      "DE show page must render at least one mkdocs_link with /docs/managers/tournament-management/ URL shape"

    # And the rendered anchor must carry target="_blank" and rel="noopener"
    # (enforced by mkdocs_link helper per D-05).
    assert_match %r{target="_blank"[^>]*rel="noopener"|rel="noopener"[^>]*target="_blank"}, response.body,
      "rendered mkdocs_link anchor must carry target=\"_blank\" and rel=\"noopener\""

    # Stable-anchor deep links from Plan 37-02 should appear — we assert at
    # least one to prove LINK-04 coverage end-to-end in DE.
    assert_match %r{/docs/managers/tournament-management/#(seeding-list|participants|mode-selection|start-parameters)},
      response.body,
      "DE show page must contain at least one deep-linked wizard doc anchor"
  end

  test "tournament show renders EN wizard doc link with /docs/en/managers/tournament-management/ URL shape" do
    I18n.with_locale(:en) do
      get tournament_url(@tournament, locale: :en)
    end

    assert_response :success

    # At least one <a> pointing at the EN doc root path must exist in the body.
    assert_match %r{href="/docs/en/managers/tournament-management/(#[a-z-]+)?"}, response.body,
      "EN show page must render at least one mkdocs_link with /docs/en/managers/tournament-management/ URL shape"

    # target="_blank" + rel="noopener" preserved cross-locale.
    assert_match %r{target="_blank"[^>]*rel="noopener"|rel="noopener"[^>]*target="_blank"}, response.body,
      "rendered mkdocs_link anchor must carry target=\"_blank\" and rel=\"noopener\""

    # Stable-anchor deep link from Plan 37-02 present in EN too.
    assert_match %r{/docs/en/managers/tournament-management/#(seeding-list|participants|mode-selection|start-parameters)},
      response.body,
      "EN show page must contain at least one deep-linked wizard doc anchor"
  end
end
