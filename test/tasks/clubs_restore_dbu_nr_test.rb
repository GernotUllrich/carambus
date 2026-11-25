# frozen_string_literal: true

require "test_helper"
require "rake"

# clubs:restore_dbu_nr — vom DBU-Rescrape 2026-11-25 gelöschte dbu_nr aus den Club-Versionen zurückholen.
class ClubsRestoreDbuNrTest < ActiveSupport::TestCase
  BASE_ID = 53_960_000

  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @n = 0
    @from = (PaperTrail::Version.maximum(:id) || 0) + 1
  end

  teardown { %w[FROM_VERSION TO_VERSION ARMED].each { |k| ENV.delete(k) } }

  def nid = BASE_ID + (@n += 1)

  # Club ohne dbu_nr samt der Version, die sie gelöscht hat (so wie auf Prod)
  def wiped_club(old_nr, current: nil)
    club = Club.create!(id: nid, name: "BC Test #{@n}", shortname: "BC Test #{@n}", region: regions(:nbv), dbu_nr: current)
    version = PaperTrail::Version.create!(item_type: "Club", item_id: club.id, event: "update",
      object_changes: {"dbu_nr" => [old_nr, nil]}.to_yaml)
    [club, version]
  end

  def restore(armed: false, to: nil)
    ENV["FROM_VERSION"] = @from.to_s
    ENV["TO_VERSION"] = to.to_s if to
    ENV["ARMED"] = "true" if armed
    Rake::Task["clubs:restore_dbu_nr"].reenable
    capture_io { Rake::Task["clubs:restore_dbu_nr"].invoke }.first
  end

  test "Probelauf schreibt nichts" do
    club, _ = wiped_club(1851)
    out = restore
    assert_match "würde zurückschreiben: 1", out
    assert_nil club.reload.dbu_nr
  end

  test "ARMED schreibt die gelöschte dbu_nr zurück" do
    club, _ = wiped_club(1851)
    restore(armed: true)
    assert_equal 1851, club.reload.dbu_nr
  end

  test "lässt Vereine mit neuer dbu_nr und doppelte Nummern in Ruhe" do
    refilled, _ = wiped_club(2091, current: 2092)
    Club.create!(id: nid, name: "BC Träger", shortname: "BC Träger", region: regions(:nbv), dbu_nr: 1296)
    taken, _ = wiped_club(1296)

    out = restore(armed: true)

    assert_equal 2092, refilled.reload.dbu_nr
    assert_nil taken.reload.dbu_nr
    assert_match "übersprungen: 2", out
  end

  test "TO_VERSION begrenzt den Bereich" do
    first, version = wiped_club(1851)
    second, _ = wiped_club(1852)
    restore(armed: true, to: version.id)
    assert_equal 1851, first.reload.dbu_nr
    assert_nil second.reload.dbu_nr
  end
end
