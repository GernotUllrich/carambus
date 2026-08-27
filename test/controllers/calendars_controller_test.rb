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

  # Der Ausschnitt kommt aus dem globalen Scope-Band, nicht aus dem Pfad. `Scopable#capture_scope`
  # liest `params[:scope]` und legt es in der Session ab — genau so setzt ihn auch das Band
  # (GET-Submit). Danach gilt er fuer alle weiteren Requests dieser Test-Session.
  def kalender(scope: nil, **params)
    params[:scope] = scope if scope
    get calendar_url(**params)
  end

  def turnier!(offset, titel, region: @region, discipline: disciplines(:pool_8ball))
    Tournament.create!(id: BASE_ID + offset, title: titel, season: @season,
      organizer: region, organizer_type: "Region", region_id: region.id,
      discipline: discipline, date: @tag.to_time + 11.hours)
  end

  # Ohne branch_id — der Altbestand-Fall (BranchTaggable stempelt beim Speichern, deshalb
  # `update_columns` daran vorbei).
  def liga_ohne_stempel!(offset, name, discipline: disciplines(:pool_8ball))
    liga = League.create!(id: BASE_ID + offset, name: name, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: discipline, shortname: name.parameterize.first(12))
    liga.update_columns(branch_id: nil)
    liga.reload
  end

  test "die Kalenderseite ist ohne Login erreichbar" do
    kalender(month: @monat)
    assert_response :success
  end

  # AC-1 — die Region kommt aus dem Band, nicht aus dem Pfad.
  test "die Region kommt aus dem Scope-Band und der Pfad traegt keine region_id" do
    turnier!(20, "NBV Landesmeisterschaft")
    andere = Region.find_or_create_by!(shortname: "BBV") { |r| r.name = "Badischer Billard-Verband" }
    Tournament.create!(id: BASE_ID + 22, title: "BBV Landesmeisterschaft", season: @season,
      organizer: andere, organizer_type: "Region", region_id: andere.id,
      discipline: disciplines(:pool_8ball), date: @tag.to_time + 11.hours)

    refute_match(/region_id/, calendar_path(month: @monat), "die Route fuehrt keine region_id mehr")

    kalender(scope: {region: @region.id}, month: @monat)
    assert_response :success
    assert_match(/NBV Landesmeisterschaft/, response.body)
    refute_match(/BBV Landesmeisterschaft/, response.body)

    kalender(scope: {region: andere.id}, month: @monat)
    assert_response :success
    assert_match(/BBV Landesmeisterschaft/, response.body,
      "eine Umschaltung im Band muss dieselbe Seite umstellen")
    refute_match(/NBV Landesmeisterschaft/, response.body)
  end

  test "Turniere und Spieltage erscheinen gemeinsam" do
    turnier!(1, "NDM Freie Partie")
    liga = liga_ohne_stempel!(2, "Oberliga Pool")
    Party.create!(id: BASE_ID + 3, league: liga, date: @tag.to_time + 13.hours)

    kalender(scope: {region: @region.id}, month: @monat)
    assert_response :success
    assert_select "body", text: /NDM Freie Partie/
    assert_select "body", text: /Oberliga Pool/
  end

  # AC-2 — die Sparte kommt aus dem Band und verliert die ungestempelten Ligen nicht.
  test "die Sparte aus dem Scope-Band behaelt eine Liga ohne branch_id" do
    liga = liga_ohne_stempel!(4, "Bezirksliga Mitte 1")
    Party.create!(id: BASE_ID + 5, league: liga, date: @tag.to_time + 13.hours)

    kalender(scope: {region: @region.id, branch: disciplines(:branch_pool).id}, month: @monat)
    assert_response :success
    assert_select "body", text: /Bezirksliga Mitte 1/

    kalender(scope: {branch: disciplines(:branch_karambol).id}, month: @monat)
    assert_response :success
    refute_match(/Bezirksliga Mitte 1/, response.body, "die fremde Sparte muss sie ausschliessen")
  end

  # AC-3 — die Saison setzt den Einstiegsmonat; der Kopf nennt die Saison des MONATS.
  test "ohne Monat startet der Kalender in der Saison des Ausschnitts" do
    vorsaison = seasons(:previous)
    startjahr = vorsaison.name.split("/").first.to_i

    kalender(scope: {region: @region.id, season: vorsaison.id})
    assert_response :success
    assert_match(/#{Regexp.escape(I18n.l(Date.new(startjahr, 7, 1), format: "%B %Y"))}/, response.body,
      "ohne expliziten Monat gehoert der Einstieg in die Saison des Bands")
  end

  test "der Kopf nennt die aus dem Monat abgeleitete Saison" do
    kalender(scope: {region: @region.id}, month: @monat)
    abgeleitet = Season.season_from_date(Date.parse("#{@monat}-01"))
    assert_match(/#{Regexp.escape(I18n.t("calendars.show.season", season: abgeleitet.name))}/,
      response.body,
      "die Monatsnavigation ist frei — der Kopf muss sagen, zu welcher Saison der Monat gehoert")
  end

  test "der DBU-Schalter wirkt und steht im URL" do
    turnier!(6, "NDM Freie Partie")
    turnier!(7, "DBU Grand Prix", region: @dbu)

    kalender(scope: {region: @region.id}, month: @monat)
    assert_select "body", text: /DBU Grand Prix/

    kalender(month: @monat, dbu: "0")
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
    kalender(scope: {region: @region.id}, month: @monat, view: "agenda")
    assert_response :success
    assert_match(/NDM Freie Partie/, response.body)
    assert_match(/Oberliga Pool/, response.body)

    kalender(month: @monat, view: "grid")
    assert_response :success
    assert_match(/NDM Freie Partie/, response.body, "das Raster muss dieselben Turniere zeigen")
    assert_match(/Oberliga Pool/, response.body, "das Raster muss dieselben Ligen zeigen")
  end

  # AC-4 — Einzel/Mannschaft ist bedienbar und steht im URL.
  test "der Einzel-Mannschaft-Schalter trennt die beiden Arten" do
    turnier!(11, "NDM Freie Partie")
    liga = liga_ohne_stempel!(12, "Oberliga Pool")
    Party.create!(id: BASE_ID + 13, league: liga, date: @tag.to_time + 13.hours)

    kalender(scope: {region: @region.id}, month: @monat, kind: "single")
    assert_response :success
    assert_match(/NDM Freie Partie/, response.body)
    refute_match(/Oberliga Pool/, response.body)

    kalender(month: @monat, kind: "team")
    assert_response :success
    assert_match(/Oberliga Pool/, response.body)
    refute_match(/NDM Freie Partie/, response.body)
  end

  # AC-5 — ohne gepflegte Kategorien darf kein Gruppen-Selektor erscheinen.
  test "ohne Turniergruppen im Ausschnitt wird kein Gruppen-Selektor gerendert" do
    turnier!(14, "NDM Freie Partie")

    kalender(scope: {region: @region.id}, month: @monat)
    assert_response :success
    refute_match(/#{Regexp.escape(I18n.t("calendars.filter.group_all"))}/, response.body,
      "ausserhalb des NBV ist category_cc_id durchgaengig nil — ein leerer Selektor waere Ballast")
  end

  test "ein leerer Monat zeigt einen Hinweis statt einer leeren Flaeche" do
    kalender(scope: {region: @region.id}, month: (Date.current + 8.months).strftime("%Y-%m"))
    assert_response :success
    assert_select "body", text: /#{Regexp.escape(I18n.t("calendars.show.empty_heading"))}/
  end

  test "ein unsinniger Monat faellt auf den laufenden zurueck statt zu werfen" do
    kalender(scope: {region: @region.id}, month: "kaputt")
    assert_response :success
    # Der Kopf nennt den Monat — bei Unsinn muss dort der laufende stehen, keine Fehlerseite.
    assert_match(/#{Regexp.escape(I18n.l(Date.current.beginning_of_month, format: "%B %Y"))}/, response.body)
  end
end
