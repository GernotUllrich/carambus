# frozen_string_literal: true

require "test_helper"
require "rake"

# clubs:set_home — Heimat eines Doppelmitglieds (ClubCcEntry) von Hand festlegen.
class ClubsSetHomeTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    @bvrp = Region.create!(name: "Rheinland-Pfalz e.V.", shortname: "TRLP", cc_id: 17, public_cc_url_base: "https://rlp-cc.example/")
    @bvs = Region.create!(name: "Saar e.V.", shortname: "TSAR", cc_id: 23, public_cc_url_base: "https://saar-cc.example/")
    @club = Club.create!(name: "Amateur Billardgemeinschaft Mosel", shortname: "ABG Trier-Mosel", region: @bvs,
      cc_id: 3163, source_url: "https://saar-cc.example/cbdet.php?a=3163&f=23")
    ClubCcEntry.record!(@club, @bvs, 3163)
  end

  teardown do
    ENV.delete("HOMES")
    ENV.delete("ARMED")
  end

  def run_task(homes, armed: false)
    ENV["HOMES"] = homes
    ENV["ARMED"] = "true" if armed
    Rake::Task["clubs:set_home"].reenable
    out, = capture_io { Rake::Task["clubs:set_home"].invoke }
    ENV.delete("ARMED")
    out
  end

  test "Probelauf schreibt nichts" do
    out = run_task("#{@club.id}:TRLP:2754")

    assert_match "TSAR cc_id 3163 → TRLP cc_id 2754", out
    assert_equal @bvs.id, @club.reload.region_id
    assert_nil ClubCcEntry.club_for(@bvrp.id, 2754)
  end

  test "ARMED setzt Heimat, Listung und source_url; die alte Listung bleibt als Fremdlistung" do
    run_task("#{@club.id}:TRLP:2754", armed: true)

    @club.reload
    assert_equal [@bvrp.id, 2754], [@club.region_id, @club.cc_id]
    assert_equal "https://rlp-cc.example/cbdet.php?a=2754&f=17", @club.source_url
    assert_equal @club, ClubCcEntry.club_for(@bvrp.id, 2754)
    assert ClubCcEntry.home_elsewhere?(@club, @bvs), "Saar-Listung gilt jetzt als fremd"
  end

  test "zweiter Lauf ändert nichts" do
    run_task("#{@club.id}:TRLP:2754", armed: true)

    assert_no_changes -> { @club.reload.updated_at } do
      assert_match "bereits TRLP", run_task("#{@club.id}:TRLP:2754", armed: true)
    end
  end

  test "belegte cc_id eines anderen Vereins wird nicht übernommen" do
    other = Club.create!(name: "BIG Trier", shortname: "BIG Trier", region: @bvrp, cc_id: 2754)

    out = run_task("#{@club.id}:TRLP:2754", armed: true)

    assert_match "gehört Verein #{other.id}", out
    assert_equal @bvs.id, @club.reload.region_id
  end
end
