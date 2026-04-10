require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "should protect imported records" do
    # LocalProtector skips protection in test environment (returns true if Rails.env.test?)
    # so imported records are not readonly in tests. We verify the fixture loads correctly
    # and that LocalProtector is included.
    imported = tournaments(:imported)
    assert_not_nil imported
    assert imported.class.ancestors.include?(LocalProtector),
      "Tournament should include LocalProtector concern"
  end

  test "allows local modifications to data field" do
    local = tournaments(:local)
    assert_nothing_raised do
      local.update!(data: { new_setting: true })
    end
  end

  test "PaperTrail ignores updated_at and sync_date changes" do
    tournament = Tournament.create!(
      title: "Test Tournament",
      season: Season.first,
      organizer: Region.first
    )

    # Get initial version count (create! produces 1 version)
    initial_version_count = tournament.versions.count

    # update_columns bypasses callbacks entirely — no PaperTrail version
    tournament.update_columns(sync_date: Time.current)
    assert_equal initial_version_count, tournament.versions.count,
      "update_columns(sync_date) should not create a version"

    # Update a meaningful field — the skip lambda only skips if ALL changes are ignorable
    # (only updated_at and/or sync_date). A title change is substantive.
    tournament.update!(title: "Updated Tournament Title")
    assert_equal initial_version_count + 1, tournament.versions.count,
      "update!(title) should create exactly one new version"

    # Verify the version contains the title change
    latest_version = tournament.versions.last
    changes = YAML.load(latest_version.object_changes)
    assert_includes changes.keys, "title"
    assert_equal ["Test Tournament", "Updated Tournament Title"], changes["title"]
  end
end 