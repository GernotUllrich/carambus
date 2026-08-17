# frozen_string_literal: true

require "test_helper"

# `cc_sourced?` ist seit Plan 34-02 der EINZIGE CC-los-Indikator im System. Vorher beantworteten
# Wizard und Ergebnisweg dieselbe Frage verschieden — die Region gegen den CC-Zwilling.
#
# Seit 34-03 ohne Uebergangs-Fallback: `source_kind` ist die alleinige Quelle, und ein Record ohne
# Wert wird GEMELDET statt still ueber ein Altsignal beantwortet.
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

  # Muster aus test/models/version_test.rb (37-01): die Meldung ist der Kanal, den im Betrieb jemand
  # liest — also wird sie geprueft, nicht ein Interna-Zaehler.
  def capture_log
    io = StringIO.new
    previous = Rails.logger
    Rails.logger = ActiveSupport::Logger.new(io)
    yield
    io.string
  ensure
    Rails.logger = previous
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

  # 34-03: Der Uebergangs-Fallback ist weg. Bis dahin sprang bei leerer Spalte das Altsignal ein —
  # STILL. Genau diese Bauart war der Fehler von Phase 37: was lautlos kompensiert wird, faellt nie
  # auf, und deshalb schloss sich das Uebergangsfenster nie. Jetzt gilt: CC-los UND gemeldet.
  test "ohne source_kind ist es CC-los UND wird gemeldet" do
    t = tournament(source_url: CC_URL)
    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 771_001)
    t.update_column(:source_kind, nil) # Server vor dem Sync / unbekanntes Muster

    logged = capture_log { assert_not t.reload.cc_sourced?, "der CC-Zwilling redet nicht mehr mit" }

    assert_match(/ohne source_kind/, logged, "der Fall muss sichtbar sein, nicht kompensiert")
    assert_match(/Tournament\[#{t.id}\]/, logged, "die Meldung nennt Modell und ID")
  end

  test "ohne source_kind gilt dasselbe fuer Ligen — der league_cc redet nicht mehr mit" do
    l = league(source_url: CC_URL)
    l.update_column(:source_kind, nil)

    logged = capture_log { assert_not l.reload.cc_sourced? }

    assert_match(/League\[#{l.id}\]/, logged)
  end

  # Die Gegenprobe zum entfernten Fallback: ein Record, der BEIDE Signale traegt und bei dem sie sich
  # widersprechen. Frueher gewann im nil-Fall der Zwilling; jetzt gibt es keinen nil-Fall mehr, in dem
  # er gewinnen koennte. Wer den Fallback wieder einbaut, laesst diesen Test fallen.
  test "source_kind ist die einzige Quelle — der CC-Zwilling kann sie nie ueberstimmen" do
    t = tournament(source_url: CC_URL)
    TournamentCc.create!(tournament: t, name: "CC-Zwilling", cc_id: 771_002)

    t.update_column(:source_kind, "liga_manager")
    assert_not t.reload.cc_sourced?, "die Spalte schlaegt den Zwilling"

    t.update_column(:source_kind, nil)
    assert_not t.reload.cc_sourced?, "und ohne Spalte springt der Zwilling NICHT mehr ein"
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
