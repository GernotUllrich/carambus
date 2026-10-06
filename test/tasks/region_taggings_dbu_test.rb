# frozen_string_literal: true

require "test_helper"
require "rake"

# Task-Test für region_taggings:redeliver_dbu_context (2026-10-06).
# Aufbau wie test/tasks/region_taggings_test.rb (load_tasks/invoke/reenable/teardown).
class RegionTaggingsDbuTaskTest < ActiveSupport::TestCase
  TASK = "region_taggings:redeliver_dbu_context"

  setup do
    skip_unless_api_server
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @pt_was_enabled = PaperTrail.request.enabled?
    PaperTrail.request.enabled = true

    @dbu_tournament = create_tournament(regions(:dbu))
    @player = Player.create!(lastname: "ZZDBU", firstname: "Spieler #{SecureRandom.hex(3)}")
    @club = Club.create!(name: "ZZDBU Verein #{SecureRandom.hex(3)}", shortname: "ZZDBU#{SecureRandom.hex(2)}", region: regions(:nbv))
    @participation = SeasonParticipation.create!(season: seasons(:current), player: @player, club: @club)
    @seeding = Seeding.create!(tournament: @dbu_tournament, player: @player, position: 1)
    @nbv_tournament = create_tournament(regions(:nbv))
    # Bestand wie auf der Authority vor dem 2026-10-06: Spalte und Versionen false (der
    # Seeding-Callback hat sie beim Anlegen gerade global gemacht — zuruecksetzen)
    [@dbu_tournament, @seeding, @player, @participation, @club].each do |rec|
      rec.update_column(:global_context, false)
      rec.versions.update_all(global_context: false)
    end
  end

  teardown do
    PaperTrail.request.enabled = @pt_was_enabled unless @pt_was_enabled.nil?
    Rake::Task.clear
  end

  test "armed run tags DBU tournament, its seeding and player and writes global versions" do
    t_before = @dbu_tournament.versions.count

    capture_io { run_task(armed: true) }

    assert @dbu_tournament.reload.global_context
    assert @seeding.reload.global_context
    assert @player.reload.global_context, "Spieler braucht die Spalte, sonst bleibt seine Version regional"
    assert_equal t_before + 1, @dbu_tournament.versions.count
    [@dbu_tournament, @seeding, @player].each do |rec|
      assert_equal true, rec.versions.last.global_context, "#{rec.class.name}: neue Version muss global sein"
    end
    assert_operator @player.versions.last.id, :<, @seeding.versions.last.id,
      "Apply-Reihenfolge: Spieler vor Seeding"
  end

  test "armed run globalizes the player's season participation and its club" do
    capture_io { run_task(armed: true) }

    assert @participation.reload.global_context, "ohne Zugehoerigkeit fehlt der Verein (Player#club)"
    assert @club.reload.global_context
    assert_operator @club.versions.last.id, :<, @participation.versions.last.id,
      "Apply-Reihenfolge: Verein vor Zugehoerigkeit"
  end

  test "armed run leaves tournaments of other regions alone" do
    nbv_before = @nbv_tournament.versions.count

    capture_io { run_task(armed: true) }

    assert_not @nbv_tournament.reload.global_context
    assert_equal nbv_before, @nbv_tournament.versions.count
  end

  test "second armed run is a no-op" do
    capture_io { run_task(armed: true) }
    count_after_first = PaperTrail::Version.count

    capture_io { run_task(armed: true) }

    assert_equal count_after_first, PaperTrail::Version.count
  end

  test "dry-run does not mutate" do
    count_before = PaperTrail::Version.count

    out, = capture_io { run_task(armed: false) }

    assert_match "DRY-RUN", out
    assert_not @dbu_tournament.reload.global_context
    assert_equal count_before, PaperTrail::Version.count
  end

  private

  def run_task(armed:)
    ENV["ARMED"] = "1" if armed
    Rake::Task[TASK].reenable
    Rake::Task[TASK].invoke
  ensure
    ENV.delete("ARMED")
  end

  def create_tournament(organizer)
    Tournament.create!(
      title: "ZZDBU Turnier #{SecureRandom.hex(3)}",
      season: seasons(:current),
      organizer: organizer,
      date: 1.week.from_now
    )
  end
end
