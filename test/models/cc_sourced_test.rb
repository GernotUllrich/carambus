# frozen_string_literal: true

require "test_helper"

# `cc_sourced?` ist seit Plan 34-02 der EINZIGE CC-los-Indikator im System. Vorher beantworteten
# Wizard und Ergebnisweg dieselbe Frage verschieden — die Region gegen den CC-Zwilling.
class CcSourcedTest < ActiveSupport::TestCase
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

  def league(**attrs)
    League.create!(
      {name: "L#{SecureRandom.hex(3)}", shortname: "L#{SecureRandom.hex(2)}",
       season: @season, organizer: @region, region_id: @region.id}.merge(attrs)
    )
  end

  # AC-1

  test "nur ClubCloud-Herkunft ist cc_sourced" do
    assert tournament(source_url: CC_URL).cc_sourced?

    assert_not tournament(source_url: LM_URL).cc_sourced?, "LigaManager"
    assert_not tournament(source_url: "https://bbv.liga.nu/x").cc_sourced?, "NuLiga"
    assert_not tournament(source_url: "https://files.umb-carom.org/x").cc_sourced?, "UMB"
    assert_not tournament(source_url: "https://tbv.carambus.de/tournaments/1").cc_sourced?, "Carambus"
    assert_not tournament(source_url: nil, ba_id: 4711).cc_sourced?, "BillardArea"
  end

  test "Ligen folgen denselben Regeln" do
    assert league(source_url: CC_URL).cc_sourced?
    assert_not league(source_url: LM_URL).cc_sourced?
  end

  # AC-2 — der Uebergangs-Fallback
  #
  # `source_kind` ist auf der Authority gefuellt, erreicht die Region- und Location-Server aber erst
  # mit dem naechsten Version-Sync. In diesem Fenster steht dort `nil` — ohne Fallback saehe jeder
  # Server jedes Turnier als CC-los und NBV verloere schlagartig seine CC-Schritte.

  test "ohne source_kind antwortet der tournament_cc wie vor 34-02" do
    t = tournament(source_url: CC_URL)
    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 771_001)
    t.update_column(:source_kind, nil) # Server vor dem Sync

    assert t.reload.cc_sourced?, "der CC-Zwilling traegt die Antwort, solange die Spalte leer ist"
  end

  test "ohne source_kind und ohne tournament_cc ist es CC-los" do
    t = tournament(source_url: nil)
    t.update_column(:source_kind, nil)

    assert_not t.reload.cc_sourced?
  end

  test "ohne source_kind antwortet bei Ligen der league_cc" do
    l = league(source_url: CC_URL)
    l.update_column(:source_kind, nil)

    assert_not l.reload.cc_sourced?, "ohne league_cc CC-los"
  end

  # Sobald der Wert eintrifft, gewinnt er — ohne Deploy, ohne Neustart.
  test "der Fallback tritt zurueck, sobald source_kind da ist" do
    t = tournament(source_url: CC_URL)
    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 771_002)

    t.update_column(:source_kind, nil)
    assert t.reload.cc_sourced?, "Fallback aktiv"

    t.update_column(:source_kind, "liga_manager")
    assert_not t.reload.cc_sourced?, "die Spalte schlaegt den Zwilling"
  end

  # Der einzige Fall, in dem sich `cc_sourced?` und das alte `tournament_cc.present?` im Bestand
  # unterscheiden: 376 BillardArea-Turniere mit CC-Zwilling (gemessen auf Produktion 2026-08-16).
  # Sie sind auf allen Ergebnisweg-Flaechen unerreichbar, weil die alle eine `source_url` verlangen
  # — und `:ba` heisst gerade, dass keine da ist.
  test "BillardArea-Turnier mit CC-Zwilling ist nicht cc_sourced, aber auch nirgends erreichbar" do
    t = tournament(source_url: nil, ba_id: 4712)
    TournamentCc.create!(tournament: t, name: "Migrations-Zwilling", cc_id: 771_003)

    assert_equal "ba", t.reload.source_kind
    assert_not t.cc_sourced?
    assert_nil t.source_url, "ohne source_url erreicht der Ergebnisweg dieses Turnier nie"
  end
end
