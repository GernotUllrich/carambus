# frozen_string_literal: true

require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  test "LocalProtectorTestOverride allows saving global records in test env" do
    # In production, LocalProtector blocks saves of records with id < MIN_ID.
    # In test env, LocalProtectorTestOverride disables the guard so test data
    # can be freely manipulated. Verify the override is active.
    imported = tournaments(:imported)
    assert_equal false, imported.readonly?,
      "Global records must NOT be AR-readonly — LocalProtector uses after_save, not readonly?"

    # Update succeeds because LocalProtectorTestOverride returns true early
    assert_nothing_raised do
      imported.update!(title: "Updated In Test")
    end
    imported.reload
    assert_equal "Updated In Test", imported.title,
      "Title must be persisted — LocalProtectorTestOverride allows saves in test env"
  end

  test "allows local modifications to data field" do
    local = tournaments(:local)
    assert_nothing_raised do
      local.update!(data: { "test_key" => "test_value" })
    end
    local.reload
    assert_equal({ "test_key" => "test_value" }, local.data,
      "Data must be persisted after update")
  end

  test "PaperTrail tracks title change but skips update_columns" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: Season.first,
      organizer: Region.first
    )

    # Get initial version count (create event = 1 version)
    initial_version_count = tournament.versions.count

    # touch updates updated_at only — PaperTrail still creates a version
    # because the skip lambda in LocalProtector does not suppress updated_at-only
    # changes from touch (touch fires after_save callbacks)
    tournament.touch

    # update_columns bypasses ActiveRecord callbacks entirely — no version created
    tournament.update_columns(sync_date: Time.current)

    # Update a meaningful field — creates one more version
    tournament.update!(title: "Updated Tournament Title")

    # After touch (1) + update! (1) = initial + 2
    assert_equal initial_version_count + 2, tournament.versions.count,
      "Expected touch + update! to create 2 new versions"

    # Verify the latest version records the title change (plus updated_at side-effect)
    latest_version = tournament.versions.last
    changes = YAML.load(latest_version.object_changes)
    assert_includes changes.keys, "title",
      "Latest version must track the title change"
    assert_equal ["Test Tournament", "Updated Tournament Title"], changes["title"]
  end
end
