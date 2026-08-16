# frozen_string_literal: true

require "test_helper"

# Der Stempel haelt fest, WOHER ein Turnier oder eine Liga stammt — und muss mitwandern, wenn ein
# Record die Quelle wechselt. Der belegte Fall: die TBV-Ligen der Saison 2025/2026 lagen zuerst in
# der ClubCloud; nach deren Tod wurde DIESELBE Saison aus dem LigaManager neu gescrapt, mit
# geaenderter source_url.
class ProvenanceStampedTest < ActiveSupport::TestCase
  CC_URL = "https://ndbv.de/sb_meisterschaft.php?p=20--2026/2027-46-"
  LM_URL = "https://ligen.billard.center/api/leagues/11"

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
  end

  def tournament(**attrs)
    Tournament.create!(
      {title: "T#{SecureRandom.hex(3)}", shortname: "S#{SecureRandom.hex(3)}",
       season: @season, organizer: @region, region_id: @region.id,
       date: Time.zone.local(2026, 10, 10, 10, 0)}.merge(attrs)
    )
  end

  test "stempelt beim Anlegen aus der source_url" do
    assert_equal "club_cloud", tournament(source_url: CC_URL).source_kind
    assert_equal "liga_manager", tournament(source_url: LM_URL).source_kind
  end

  test "wandert mit, wenn der Record die Quelle wechselt" do
    t = tournament(source_url: CC_URL)
    assert t.source_club_cloud?

    t.update!(source_url: LM_URL)

    assert_equal "liga_manager", t.reload.source_kind,
      "der TBV-Fall: dieselbe Saison, neu gescrapt aus einer anderen Quelle"
  end

  test "ueberschreibt einen gesetzten Wert nicht bei jedem Speichern" do
    t = tournament(source_url: nil)
    t.update!(source_kind: :club_cloud)

    t.update!(title: "Neuer Titel")

    assert_equal "club_cloud", t.reload.source_kind,
      "ohne Wechsel der source_url bleibt der bewusst gesetzte Wert stehen"
  end

  test "ohne jede Spur gilt der Record als in Carambus angelegt" do
    assert_equal "carambus", tournament(source_url: nil, ba_id: nil).source_kind
  end

  test "ohne source_url, aber mit ba_id ist es BillardArea" do
    assert_equal "ba", tournament(source_url: nil, ba_id: 4711).source_kind
  end

  test "ein unbekanntes Muster laesst den alten Wert stehen, statt zu raten" do
    t = tournament(source_url: CC_URL)

    t.update!(source_url: "https://irgendwo.example.org/turniere/17")

    assert_equal "club_cloud", t.reload.source_kind
  end

  # Das Loch, aus dem die 366 Altfaelle stammen: der CC-Scrape legt erst das Turnier an und danach
  # den tournament_cc. Ohne Nachstempel bliebe so ein Turnier dauerhaft als "carambus" markiert —
  # und waere in 34-02 faelschlich CC-los.
  test "ein neu angelegter TournamentCc stempelt sein Turnier auf ClubCloud nach" do
    t = tournament(source_url: nil, ba_id: nil)
    assert t.source_carambus?, "Ausgangslage: keine Spur"

    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 876_001)

    assert_equal "club_cloud", t.reload.source_kind
  end

  test "der Nachstempel fasst ein Turnier mit eigener Quell-URL nicht an" do
    t = tournament(source_url: LM_URL)

    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 876_002)

    assert_equal "liga_manager", t.reload.source_kind, "wo eine Quell-URL steht, gewinnt sie"
  end

  test "der Nachstempel laeuft ins Leere, wenn kein Turnier haengt" do
    assert_nothing_raised do
      TournamentCc.create!(tournament: nil, name: "Waise", cc_id: 876_003)
    end
  end

  test "Ligen tragen denselben Stempel" do
    league = League.create!(name: "Testliga #{SecureRandom.hex(3)}", shortname: "TL#{SecureRandom.hex(2)}",
      season: @season, organizer: @region, region_id: @region.id, source_url: LM_URL)

    assert_equal "liga_manager", league.source_kind

    league.update!(source_url: CC_URL)
    assert_equal "club_cloud", league.reload.source_kind
  end
end
