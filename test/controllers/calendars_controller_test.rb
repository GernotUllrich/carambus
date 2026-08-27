# frozen_string_literal: true

require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  BASE_ID = 59_500_000

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @dbu = Region.find_or_create_by!(shortname: "DBU") { |r| r.name = "Deutsche Billard-Union" }
    @tag = Date.current.beginning_of_month + 9
    @monat = @tag.strftime("%Y-%m")
  end

  def turnier!(offset, titel, region: @region)
    Tournament.create!(id: BASE_ID + offset, title: titel, season: @season,
      organizer: region, organizer_type: "Region", region_id: region.id,
      discipline: disciplines(:pool_8ball), date: @tag.to_time + 11.hours)
  end

  # Ohne branch_id — der Altbestand-Fall (BranchTaggable stempelt beim Speichern, deshalb
  # `update_columns` daran vorbei).
  def liga_ohne_stempel!(offset, name)
    liga = League.create!(id: BASE_ID + offset, name: name, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), shortname: name.parameterize.first(12))
    liga.update_columns(branch_id: nil)
    liga.reload
  end

  test "die Kalenderseite ist ohne Login erreichbar" do
    get region_calendar_url(@region, month: @monat)
    assert_response :success
  end

  test "Turniere und Spieltage erscheinen gemeinsam" do
    turnier!(1, "NDM Freie Partie")
    liga = liga_ohne_stempel!(2, "Oberliga Pool")
    Party.create!(id: BASE_ID + 3, league: liga, date: @tag.to_time + 13.hours)

    get region_calendar_url(@region, month: @monat)
    assert_response :success
    assert_select "body", text: /NDM Freie Partie/
    assert_select "body", text: /Oberliga Pool/
  end

  # AC-2 — der Filter darf die ungestempelten Ligen nicht verlieren.
  test "der Branch-Filter behaelt eine Liga ohne branch_id" do
    liga = liga_ohne_stempel!(4, "Bezirksliga Mitte 1")
    Party.create!(id: BASE_ID + 5, league: liga, date: @tag.to_time + 13.hours)

    get region_calendar_url(@region, month: @monat, branch: "Pool")
    assert_response :success
    assert_select "body", text: /Bezirksliga Mitte 1/
  end

  test "der DBU-Schalter wirkt und steht im URL" do
    turnier!(6, "NDM Freie Partie")
    turnier!(7, "DBU Grand Prix", region: @dbu)

    get region_calendar_url(@region, month: @monat)
    assert_select "body", text: /DBU Grand Prix/

    get region_calendar_url(@region, month: @monat, dbu: "0")
    assert_response :success
    assert_select "body", text: /NDM Freie Partie/
    refute_match(/DBU Grand Prix/, response.body)
  end

  # AC-4 — beide Ansichten zeigen dieselbe Menge.
  test "Agenda und Monatsraster zeigen dieselben Termine" do
    turnier!(8, "NDM Freie Partie")
    liga = liga_ohne_stempel!(9, "Oberliga Pool")
    Party.create!(id: BASE_ID + 10, league: liga, date: @tag.to_time + 13.hours)

    # `assigns` braucht ein Extra-Gem — geprueft wird deshalb am gerenderten HTML: beide
    # Ansichten muessen dieselben Termine NENNEN.
    get region_calendar_url(@region, month: @monat, view: "agenda")
    assert_response :success
    assert_match(/NDM Freie Partie/, response.body)
    assert_match(/Oberliga Pool/, response.body)

    get region_calendar_url(@region, month: @monat, view: "grid")
    assert_response :success
    assert_match(/NDM Freie Partie/, response.body, "das Raster muss dieselben Turniere zeigen")
    assert_match(/Oberliga Pool/, response.body, "das Raster muss dieselben Ligen zeigen")
  end

  test "ein leerer Monat zeigt einen Hinweis statt einer leeren Flaeche" do
    get region_calendar_url(@region, month: (Date.current + 8.months).strftime("%Y-%m"))
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(I18n.t("calendars.show.empty_heading"))}/
  end

  test "ein unsinniger Monat faellt auf den laufenden zurueck statt zu werfen" do
    get region_calendar_url(@region, month: "kaputt")
    assert_response :success
    # Der Kopf nennt den Monat — bei Unsinn muss dort der laufende stehen, keine Fehlerseite.
    assert_match(/#{Regexp.escape(I18n.l(Date.current.beginning_of_month, format: "%B %Y"))}/, response.body)
  end
end
