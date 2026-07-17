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

  # ARMED + REDELIVER_CHILDREN: zusätzlich Games/GameParticipations/Player redelivern.
  def run_task_children
    ENV["ARMED"] = "1"
    ENV["REDELIVER_CHILDREN"] = "1"
    Rake::Task["region_taggings:fix_international_organizer_context"].reenable
    Rake::Task["region_taggings:fix_international_organizer_context"].invoke
  ensure
    ENV.delete("ARMED")
    ENV.delete("REDELIVER_CHILDREN")
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

  # --- REDELIVER_CHILDREN: Games/GameParticipations/Player ---

  # Erzeugt eine int. Organizer-Region + Turnier + Game + Player + GameParticipation (ids >= MIN_ID).
  # Player region_id bleibt nil (irrelevant fürs Verhalten: der Task flippt global_context auf JEDEM
  # noch nicht globalen Player) — real sind viele dieser Player region-scoped und replizieren sonst nicht.
  def create_intl_with_children(base, shortname)
    region_intl = Region.create!(id: base, shortname: shortname, name: "Task #{shortname}", global_context: false, region_id: nil)
    tournament = Tournament.create!(
      id: base + 1, title: "Task #{shortname} Intl", season: seasons(:current),
      organizer: region_intl, single_or_league: "single", date: 1.week.from_now, region_id: nil
    )
    player = Player.create!(id: base + 2, lastname: "Child#{shortname}", firstname: "One", global_context: false)
    game = Game.create!(id: base + 3, tournament: tournament, tournament_type: "Tournament", seqno: 1, gname: "R1", region_id: nil, global_context: false)
    gp = GameParticipation.create!(id: base + 4, game: game, player: player, role: "player_a", global_context: false)
    [region_intl, tournament, player, game, gp]
  end

  test "children run redelivers games + participations and flips player global_context in apply order" do
    skip_unless_api_server

    _region, _tournament, player, game, gp = create_intl_with_children(REGION_BASE_ID + 10, "TSKC")
    game_versions_before = game.versions.count
    gp_versions_before = gp.versions.count

    capture_io { run_task_children }

    assert_equal true, player.reload.global_context, "Player muss global_context=true bekommen (region-scoped Player repliziert sonst nicht)"
    player_version = player.versions.reload.last
    assert_equal true, player_version.global_context

    assert_operator game.versions.reload.count, :>, game_versions_before, "Game muss eine frische Version bekommen"
    assert_operator gp.versions.reload.count, :>, gp_versions_before, "GameParticipation muss eine frische Version bekommen"

    # Apply-Reihenfolge: Player-Version < Game-Version < GameParticipation-Version
    assert_operator gp.versions.last.id, :>, player_version.id, "GP-Version muss NACH der Player-Version geordnet sein"
    assert_operator gp.versions.last.id, :>, game.versions.last.id, "GP-Version muss NACH der Game-Version geordnet sein"
  end

  test "second children run does not re-flip already-global players or regions" do
    skip_unless_api_server

    region_intl, _tournament, player, _game, _gp = create_intl_with_children(REGION_BASE_ID + 20, "TSKC2")

    capture_io { run_task_children } # erster Lauf: flippt Player-gc + Region-gc

    player_version_count = player.reload.versions.count
    region_version_count = region_intl.reload.versions.count

    capture_io { run_task_children } # zweiter Lauf

    assert_equal player_version_count, player.reload.versions.count, "Player bereits global_context=true -> nicht erneut getaggt"
    assert_equal region_version_count, region_intl.reload.versions.count, "Region bereits global_context=true -> nicht erneut getaggt"
  end

  test "dry-run reports child counts without mutating players" do
    skip_unless_api_server

    _region, _tournament, player, = create_intl_with_children(REGION_BASE_ID + 30, "TSKC3")

    ENV.delete("ARMED")
    ENV.delete("REDELIVER_CHILDREN")
    out, = capture_io do
      Rake::Task["region_taggings:fix_international_organizer_context"].reenable
      Rake::Task["region_taggings:fix_international_organizer_context"].invoke
    end

    assert_match(/Kinder-Umfang/, out, "DRY-RUN muss die Kinder-Zählungen ausgeben")
    assert_equal false, player.reload.global_context, "DRY-RUN darf Player nicht mutieren"
  end
end
