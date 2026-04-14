# frozen_string_literal: true

require "test_helper"

# Phase 37 Plan 05: Lock-in tests for ApplicationHelper#mkdocs_link / #mkdocs_url
# after Plans 37-01..37-04 landed. These tests characterize the helper contract
# (LINK-01) so regressions in locale handling, anchor appending, index trailing
# slashes, or the required-text guard will fail loudly.
class ApplicationHelperTest < ActionView::TestCase
  # --- mkdocs_url: URL-Struktur pro Locale ---

  test "mkdocs_url returns /docs/<path>/ for DE locale (no de/ prefix)" do
    assert_equal "/docs/managers/tournament-management/",
      mkdocs_url("managers/tournament-management", locale: "de")
  end

  test "mkdocs_url returns /docs/en/<path>/ for EN locale" do
    assert_equal "/docs/en/managers/tournament-management/",
      mkdocs_url("managers/tournament-management", locale: "en")
  end

  test "mkdocs_url uses I18n.locale when locale argument is nil" do
    I18n.with_locale(:en) do
      assert_equal "/docs/en/managers/tournament-management/",
        mkdocs_url("managers/tournament-management")
    end
    I18n.with_locale(:de) do
      assert_equal "/docs/managers/tournament-management/",
        mkdocs_url("managers/tournament-management")
    end
  end

  # --- mkdocs_url: Anchor-Handling ---

  test "mkdocs_url appends #anchor when anchor given" do
    assert_equal "/docs/managers/tournament-management/#seeding-list",
      mkdocs_url("managers/tournament-management", locale: "de", anchor: "seeding-list")
  end

  test "mkdocs_url appends #anchor on EN locale too" do
    assert_equal "/docs/en/managers/tournament-management/#mode-selection",
      mkdocs_url("managers/tournament-management", locale: "en", anchor: "mode-selection")
  end

  test "mkdocs_url handles nil anchor as no fragment" do
    refute_includes mkdocs_url("managers/tournament-management", locale: "de", anchor: nil), "#"
  end

  test "mkdocs_url handles empty-string anchor as no fragment" do
    refute_includes mkdocs_url("managers/tournament-management", locale: "de", anchor: ""), "#"
  end

  # --- mkdocs_url: Index-File Trailing-Slash-Handling (D-02) ---

  test "mkdocs_url does not append trailing slash for 'index' root" do
    assert_equal "/docs/index", mkdocs_url("index", locale: "de")
    assert_equal "/docs/en/index", mkdocs_url("index", locale: "en")
  end

  test "mkdocs_url does not append trailing slash for 'managers/index'" do
    assert_equal "/docs/managers/index", mkdocs_url("managers/index", locale: "de")
    assert_equal "/docs/en/managers/index", mkdocs_url("managers/index", locale: "en")
  end

  # --- mkdocs_link: link_to Wrapper ---

  test "mkdocs_link raises ArgumentError when text: is missing" do
    assert_raises(ArgumentError) do
      mkdocs_link("managers/tournament-management")
    end
  end

  test "mkdocs_link raises ArgumentError when text: is blank" do
    assert_raises(ArgumentError) do
      mkdocs_link("managers/tournament-management", text: "")
    end
    assert_raises(ArgumentError) do
      mkdocs_link("managers/tournament-management", text: "   ")
    end
  end

  test "mkdocs_link produces <a> with target=_blank and rel=noopener" do
    html = mkdocs_link("managers/tournament-management", locale: "de", text: "Handbuch")
    assert_includes html, 'target="_blank"'
    assert_includes html, 'rel="noopener"'
    assert_includes html, 'href="/docs/managers/tournament-management/"'
    assert_includes html, ">Handbuch</a>"
  end

  test "mkdocs_link includes anchor fragment in rendered href" do
    html = mkdocs_link("managers/tournament-management", locale: "en",
      anchor: "participants", text: "Handbook")
    assert_includes html, 'href="/docs/en/managers/tournament-management/#participants"'
  end
end
