# frozen_string_literal: true

require "test_helper"
require "rake"

# Task-Test fuer disciplines:backfill_from_title (Plan 03-02). Weist unbranchten Turnieren
# (discipline_id nil ODER "Unknown Discipline") die exakte Disziplin aus dem Titel zu.
# PaperTrail-Versionen entstehen nur auf dem API-Server -> skip_unless_api_server.
class DisciplinesBackfillTest < ActiveSupport::TestCase
  BASE = 53_100_000

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    ENV.delete("ARMED")

    @region = Region.create!(id: BASE + 900, shortname: "BFT", name: "Backfill Test", region_id: nil)
    @pool = Branch.create!(id: BASE + 23, name: "Pool")
    @ten = Discipline.create!(id: BASE + 51, name: "10-Ball", synonyms: "10er Ball\n10 Ball", super_discipline_id: @pool.id)
    @unknown = Discipline.find_by(name: "Unknown Discipline") || Discipline.create!(id: BASE + 102, name: "Unknown Discipline")
    Discipline.reset_classify_index!
  end

  teardown do
    ENV.delete("ARMED")
    Rake::Task.clear
    Discipline.reset_classify_index!
  end

  def backfill(armed: false)
    ENV["ARMED"] = "1" if armed
    Rake::Task["disciplines:backfill_from_title"].reenable
    capture_io { Rake::Task["disciplines:backfill_from_title"].invoke }
  ensure
    ENV.delete("ARMED")
  end

  def tournament(offset, title, discipline_id: nil)
    Tournament.create!(
      id: BASE + offset, title: title, season: seasons(:current), organizer: @region,
      single_or_league: "single", date: 1.week.from_now, region_id: nil, discipline_id: discipline_id
    )
  end

  test "ARMED assigns exact discipline to a derivable unbranched tournament and creates a version" do
    skip_unless_api_server
    t = tournament(1, "Landesmeisterschaft 10er Ball Herren", discipline_id: nil)
    before = t.versions.count

    _out, = backfill(armed: true)

    assert_equal @ten.id, t.reload.discipline_id, "10er Ball -> 10-Ball zugewiesen"
    assert_operator t.versions.reload.count, :>, before, "update! muss eine PaperTrail-Version erzeugen (Sync)"
  end

  test "tournament with an existing real discipline is not touched" do
    skip_unless_api_server
    t = tournament(2, "Irgendein 10er Ball Turnier", discipline_id: @ten.id)
    before = t.versions.count

    backfill(armed: true)

    assert_equal @ten.id, t.reload.discipline_id
    assert_equal before, t.versions.reload.count, "bereits echte Disziplin -> nicht selektiert, keine neue Version"
  end

  test "non-derivable title stays unchanged and appears in triage output" do
    skip_unless_api_server
    t = tournament(3, "UMB General Assembly", discipline_id: nil)

    out, = backfill(armed: true)

    assert_nil t.reload.discipline_id, "nicht ableitbar -> unveraendert"
    assert_match(/UMB General Assembly/, out, "muss in der Triage-Ausgabe erscheinen")
  end

  test "dry-run does not mutate" do
    skip_unless_api_server
    t = tournament(4, "Landesmeisterschaft 10er Ball Herren", discipline_id: nil)

    backfill(armed: false)

    assert_nil t.reload.discipline_id, "DRY-RUN darf nicht schreiben"
  end

  test "branch-ergebender Titel wird zugewiesen (kein Triage, Plan 03-03)" do
    skip_unless_api_server
    t = tournament(6, "Friday for Pool (PBF Blieskastel)", discipline_id: nil)

    backfill(armed: true)

    assert_equal @pool.id, t.reload.discipline_id, "Pool-Branch ist eine gueltige Zuweisung"
  end

  test "second armed run is a no-op (already assigned, not reselected)" do
    skip_unless_api_server
    t = tournament(5, "Landesmeisterschaft 10er Ball Herren", discipline_id: nil)

    backfill(armed: true)
    assigned_versions = t.reload.versions.count

    backfill(armed: true)

    assert_equal @ten.id, t.reload.discipline_id
    assert_equal assigned_versions, t.versions.reload.count, "zweiter Lauf: nicht mehr nil/Unknown -> No-op"
  end
end
