# frozen_string_literal: true

require "test_helper"

class ScrapeFingerprintTest < ActiveSupport::TestCase
  setup do
    @record = regions(:nbv)
    @scope = "standings"
  end

  test "deep? true für neuen Fingerprint (noch nie gesehen)" do
    assert ScrapeFingerprint.deep?(@record, @scope, "content-A", armed: true)
  end

  test "deep? false + checked_at fortgeschrieben bei unverändertem content" do
    ScrapeFingerprint.for(@record, @scope).commit!("content-A")
    before = ScrapeFingerprint.for(@record, @scope)
    old_changed_at = before.changed_at
    old_checked_at = before.checked_at

    refute ScrapeFingerprint.deep?(@record, @scope, "content-A", armed: true)

    after = ScrapeFingerprint.for(@record, @scope)
    assert_operator after.checked_at, :>=, old_checked_at, "checked_at muss fortgeschrieben sein"
    assert_equal old_changed_at.to_i, after.changed_at.to_i, "changed_at darf nicht kippen (keine Änderung)"
  end

  test "deep? true bei geändertem content" do
    ScrapeFingerprint.for(@record, @scope).commit!("content-A")
    assert ScrapeFingerprint.deep?(@record, @scope, "content-B", armed: true)
  end

  test "deep? erzeugt keine PaperTrail-Versionen (server-lokal)" do
    ScrapeFingerprint.for(@record, @scope).commit!("content-A")
    assert_no_difference -> { PaperTrail::Version.where(item_type: "ScrapeFingerprint").count } do
      ScrapeFingerprint.deep?(@record, @scope, "content-A", armed: true)
    end
  end

  test "deep? armed:false schreibt im fresh-Fall nicht" do
    ScrapeFingerprint.for(@record, @scope).commit!("content-A")
    old_checked_at = ScrapeFingerprint.for(@record, @scope).checked_at

    refute ScrapeFingerprint.deep?(@record, @scope, "content-A", armed: false)

    assert_equal old_checked_at.to_i, ScrapeFingerprint.for(@record, @scope).checked_at.to_i,
      "armed:false darf checked_at nicht fortschreiben"
  end
end
