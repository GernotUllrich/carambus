# frozen_string_literal: true

require "test_helper"
require "rake"

# Task-Test für region_taggings:fix_international_organizer_context (Plan 41-02).
# Modelliert auf test/tasks/auto_reserve_tables_test.rb (load_tasks/invoke/reenable/teardown).
# Die Version-Erzeugung ist nur auf dem API-Server relevant (PaperTrail aktiv, siehe
# test_helper.rb skip_unless_api_server) — genau der Task, den dieser Test prüft.
class RegionTaggingsTaskTest < ActiveSupport::TestCase
  # IDs >= MIN_ID (50_000_000), eigener Offset-Bereich getrennt von Plan 01
  # (test/models/region_taggable_sync_test.rb nutzt REGION_BASE_ID = 52_000_200)
  # um id-Kollisionen über Dateien hinweg zu vermeiden.
  REGION_BASE_ID = 52_000_210

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  teardown do
    Rake::Task.clear
  end

  def run_task_armed
    ENV["ARMED"] = "1"
    Rake::Task["region_taggings:fix_international_organizer_context"].reenable
    Rake::Task["region_taggings:fix_international_organizer_context"].invoke
  ensure
    ENV.delete("ARMED")
  end

  test "armed run tags the international organizer region and redelivers its stuck tournament end-to-end" do
    skip_unless_api_server

    region_intl = Region.create!(id: REGION_BASE_ID + 1, shortname: "TSKI", name: "Task Intl", global_context: false, region_id: nil)
    tournament = Tournament.create!(
      id: REGION_BASE_ID + 2,
      title: "Task Stuck Intl",
      season: seasons(:current),
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )
    t_versions_before = tournament.versions.count

    capture_io { run_task_armed }

    region_intl.reload
    assert_equal true, region_intl.global_context

    region_version = region_intl.versions.reload.last
    assert_equal true, region_version.global_context

    tournament.reload
    assert_equal t_versions_before + 1, tournament.versions.count, "Turnier muss redelivered werden (frische Version)"
    assert tournament.versions.reload.last.id > region_version.id, "Turnier-Version muss NACH der Region-Version geordnet sein"
  end

  test "second armed run is a no-op: no new versions" do
    skip_unless_api_server

    region_intl = Region.create!(id: REGION_BASE_ID + 3, shortname: "TSKN", name: "Task NoOp Intl", global_context: false, region_id: nil)
    tournament = Tournament.create!(
      id: REGION_BASE_ID + 4,
      title: "Task NoOp Stuck Intl",
      season: seasons(:current),
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    capture_io { run_task_armed } # erster Lauf — fixt + redelivert

    region_version_count = region_intl.reload.versions.count
    tournament_version_count = tournament.reload.versions.count

    capture_io { run_task_armed } # zweiter Lauf — muss No-op sein

    assert_equal region_version_count, region_intl.reload.versions.count, "Region bereits global_context=true -> nicht mehr selektiert -> keine neue Version"
    assert_equal tournament_version_count, tournament.reload.versions.count, "Turnier-Version postdatiert bereits den Region-Fix -> nicht erneut getoucht"
  end

  test "dry-run default does not mutate" do
    skip_unless_api_server

    region_intl = Region.create!(id: REGION_BASE_ID + 5, shortname: "TSKD", name: "Task DryRun", global_context: false, region_id: nil)
    Tournament.create!(
      id: REGION_BASE_ID + 6,
      title: "Task DryRun Stuck Intl",
      season: seasons(:current),
      organizer: region_intl,
      single_or_league: "single",
      date: 1.week.from_now,
      region_id: nil
    )

    ENV.delete("ARMED")
    capture_io do
      Rake::Task["region_taggings:fix_international_organizer_context"].reenable
      Rake::Task["region_taggings:fix_international_organizer_context"].invoke
    end

    assert_equal false, region_intl.reload.global_context, "DRY-RUN darf nicht mutieren"
  end
end
