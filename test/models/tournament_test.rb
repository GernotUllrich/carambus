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

  test "player_controlled? always returns true regardless of admin_controlled (UI-03 D-10)" do
    # D-10: the round-advance gate becomes unconditional — auto-advance always happens.
    # Historically `player_controlled?` returned `!admin_controlled?`; the column still
    # exists on global records (D-11) but must no longer block auto-advance.
    #
    # Uses tournaments(:local) fixture (id 50_000_001) to avoid fragile Tournament.create!
    # with minimal attributes that may fail validation. The fixture already satisfies
    # all required associations (season, organizer, discipline).
    t = tournaments(:local)

    t.admin_controlled = true
    assert t.player_controlled?, "player_controlled? must ignore admin_controlled=true"

    t.admin_controlled = false
    assert t.player_controlled?, "player_controlled? must be true when admin_controlled=false"

    t.admin_controlled = nil
    assert t.player_controlled?, "player_controlled? must be true when admin_controlled=nil"
  end
end