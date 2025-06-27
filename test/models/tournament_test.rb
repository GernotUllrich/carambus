require "test_helper"

class TournamentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end

  test "should protect imported records" do
    imported = tournaments(:imported)
    assert imported.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { imported.update!(title: "New Title") }
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
    
    # Get initial version count
    initial_version_count = tournament.versions.count
    
    # Update only updated_at (should be ignored by PaperTrail)
    tournament.touch
    
    # Update sync_date (should be ignored by PaperTrail)
    tournament.update_columns(sync_date: Time.current)
    
    # Update a meaningful field (should create a version)
    tournament.update!(title: "Updated Tournament Title")
    
    # Check that only the meaningful change created a version
    assert_equal initial_version_count + 1, tournament.versions.count
    
    # Verify the version only contains the title change
    latest_version = tournament.versions.last
    changes = YAML.load(latest_version.object_changes)
    assert_equal ['title'], changes.keys
    assert_equal ['Test Tournament', 'Updated Tournament Title'], changes['title']
  end
end 