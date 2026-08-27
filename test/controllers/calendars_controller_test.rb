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

  # Haengt einem Turnier eine Turniergruppe an (championship_type_cc_name, siehe query.rb).
  def gruppe!(offset, tournament, name)
    TournamentCc.create!(id: BASE_ID + offset, tournament: tournament,
      championship_type_cc_name: name, name: tournament.title)
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

  # --- Selektor-Optionen kommen aus dem Ausschnitt, nicht aus dem Zeitfenster ------------------

  # Betreiber-Befund 2026-08-27: "NordCup" waehlen, in einen Monat ohne NordCup blaettern — und
  # die Option verschwand aus der Leiste, obwohl der Filter weiter griff. Man sah nicht mehr,
  # worauf man eingeschraenkt hatte.
  test "eine Gruppe bleibt waehlbar, auch wenn der angezeigte Monat sie nicht hergibt" do
    frueh = Date.current.beginning_of_month + 9
    spaet = (Date.current + 3.months).beginning_of_month + 9

    nordcup = Tournament.create!(id: BASE_ID + 50, title: "NordCup Dreiband", season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: spaet.to_time + 11.hours)
    gruppe!(51, nordcup, "NordCup")
    anderes = Tournament.create!(id: BASE_ID + 52, title: "NDM Freie Partie", season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: frueh.to_time + 11.hours)
    gruppe!(53, anderes, "NDM")

    # Angezeigt wird der Monat OHNE NordCup.
    kalender(scope: {region: @region.id}, month: frueh.strftime("%Y-%m"))
    assert_response :success
    assert_match(/NordCup/, response.body,
      "die Gruppe gehoert weiter in die Leiste — sonst sieht man nicht, worauf man filtern kann")

    # Und mit gesetztem Filter erst recht: sonst waere der aktive Filter unsichtbar.
    kalender(month: frueh.strftime("%Y-%m"), group: "NordCup")
    assert_response :success
    assert_match(/NordCup/, response.body,
      "ein GESETZTER Filter darf nie aus der Leiste verschwinden")
  end

  # Betreiber-Befund 2026-08-27: "Karambol", "Karambol grosses/kleines Billard" standen im
  # Disziplin-Selektor und lieferten nichts. Ursache: die Optionen kamen aus der Ligentabelle
  # ohne Datumsfilter, der NBV hat in 26/27 aber null Spieltage.
  test "eine Liga-Disziplin ohne Spieltage im Zeitraum wird nicht angeboten" do
    # Zwei Turniere verschiedener Disziplin, damit der Selektor ueberhaupt rendert — bei nur
    # EINER Option bleibt er absichtlich weg (Regel aus 42-02).
    turnier!(56, "NDM 8-Ball", discipline: disciplines(:pool_8ball))
    turnier!(57, "NDM 9-Ball", discipline: disciplines(:pool_9ball))

    liga = liga_ohne_stempel!(54, "Verbandsliga Karambol", discipline: disciplines(:karambol_cadre_35_2))
    assert_equal 0, Party.where(league_id: liga.id).count, "Vorbedingung: diese Liga hat keine Spieltage"

    kalender(scope: {region: @region.id}, month: @monat)
    assert_response :success
    assert_match(/8-Ball/, response.body, "Vorbedingung: der Selektor wird ueberhaupt gerendert")
    refute_match(/Cadre 35\/2/, response.body,
      "eine Disziplin, die im Zeitraum nichts hergibt, gehoert nicht in den Selektor")

    # Mit Spieltag taucht sie auf.
    Party.create!(id: BASE_ID + 55, league: liga, date: @tag.to_time + 13.hours)
    kalender(month: @monat)
    assert_match(/Cadre 35\/2/, response.body)
  end

  test "der Anfang-Knopf erscheint nur bei gesetzten Filtern und raeumt sie ab" do
    kalender(scope: {region: @region.id}, month: @monat)
    refute_match(/#{Regexp.escape(I18n.t("calendars.filter.reset"))}/, response.body,
      "ohne gesetzte Filter waere der Knopf Zierde")

    kalender(month: @monat, kind: "single", view: "stream")
    assert_response :success
    assert_match(/#{Regexp.escape(I18n.t("calendars.filter.reset"))}/, response.body)
    # Der Knopf behaelt die Ansicht und wirft nur die Achsen weg.
    assert_match(%r{/calendar\?view=stream"}, response.body,
      "zurueck zur Anfangssicht — Ansicht bleibt, Achsen und Monat fallen weg")
  end

  # --- Monatsraster: Wochenstruktur (42-03) ---------------------------------------------------

  # Erster Tag des angezeigten Monats mit dem gesuchten Wochentag.
  def erster_wochentag(wday)
    tag = Date.current.beginning_of_month
    tag += 1 while tag.wday != wday
    tag
  end

  # Alle Spur-Definitionen im Raster — es MUESSEN zwei sein (Kopfzeile und Zellen) und sie
  # muessen gleich lauten, sonst stehen die Wochentagsnamen ueber den falschen Spalten.
  # Die Obergrenze des Stroms — dieselbe Rechnung wie im Helper, hier unabhaengig nachgezogen,
  # damit der Test nicht die Implementierung gegen sich selbst prueft.
  def calendar_month_bounds_fuer_test
    startjahr = Season.current_season.name.split("/").first.to_i
    [Date.new(2009, 7, 1), Date.new(startjahr + 3, 6, 1)]
  end

  def raster_spur_definitionen
    response.body.scan(/grid-template-columns:\s*([^;]+);/).flatten
  end

  def raster_spuren
    defs = raster_spur_definitionen
    assert_equal 2, defs.size, "Kopfzeile und Zellen brauchen je eine Spur-Definition"
    assert_equal defs.first, defs.last,
      "Kopfzeile und Zellen muessen dieselben Spuren tragen, sonst laufen sie auseinander"
    defs.first.scan(/minmax\([^)]*\)|[\d.]+rem/)
  end

  # AC-1 — die Kopfzeile im gerenderten Raster.
  test "das Monatsraster beginnt die Woche am Samstag" do
    turnier!(30, "NDM Freie Partie")
    kalender(scope: {region: @region.id}, month: @monat, view: "grid")
    assert_response :success

    reihenfolge = response.body.scan(/tracking-wide text-gray-500 dark:text-gray-400">\s*(\w{2})\s*</).flatten.first(7)
    assert_equal %w[Sa So Mo Di Mi Do Fr], reihenfolge
  end

  # AC-2 / AC-3 — die Spaltenbreite folgt den Terminen DIESES Monats.
  test "das Raster schrumpft leere Wochentage und laesst belegte breit" do
    samstag = erster_wochentag(6)
    mittwoch = erster_wochentag(3)

    # Nur ein Samstagstermin: alle Wochentage schrumpfen.
    Tournament.create!(id: BASE_ID + 31, title: "NDM Samstag", season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: samstag.to_time + 11.hours)

    kalender(scope: {region: @region.id}, month: @monat, view: "grid")
    assert_response :success
    # Reihenfolge ist [Sa, So, Mo, Di, Mi, Do, Fr] — Mittwoch steht an Position 4.
    assert_equal CalendarsHelper::SPUR_BELEGT, raster_spuren[0], "Samstag ist belegt"
    assert_equal CalendarsHelper::SPUR_LEER, raster_spuren[4], "Mittwoch ist leer und schrumpft"

    # Jetzt der BVNR-/DBU-Fall: ein Termin unter der Woche.
    Tournament.create!(id: BASE_ID + 32, title: "DBU Mittwoch", season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: mittwoch.to_time + 11.hours)

    kalender(month: @monat, view: "grid")
    assert_response :success
    assert_equal CalendarsHelper::SPUR_BELEGT, raster_spuren[4],
      "ein Mittwoch mit Terminen darf nicht auf Zahlenbreite gequetscht werden"
    assert_match(/DBU Mittwoch/, response.body, "und der Termin muss im Raster stehen")
  end

  # --- Kalender-Strom (42-04) -----------------------------------------------------------------

  # AC-1 / AC-6 — die Erstladung steht serverseitig im HTML.
  test "die Stromansicht zeigt mehrere Monatskacheln ohne JavaScript" do
    turnier!(40, "NDM Freie Partie")

    kalender(scope: {region: @region.id}, month: @monat, view: "stream")
    assert_response :success

    kacheln = response.body.scan(/data-month="(\d{4}-\d{2})"/).flatten
    assert_operator kacheln.size, :>, 1, "der Strom zeigt mehr als einen Monat"
    assert_includes kacheln, @monat, "der Einstiegsmonat gehoert dazu"
    assert_equal kacheln.sort, kacheln, "die Kacheln stehen chronologisch"
    assert_match(/NDM Freie Partie/, response.body)
    # Ein leerer Monat bekommt einen Hinweis, keine leere Kachel.
    assert_match(/#{Regexp.escape(I18n.t("calendars.stream.empty_month"))}/, response.body)
  end

  # Der Seitenkopf muss im Strom erreichbar bleiben. Automatisches Nachladen nach oben haelt die
  # Leseposition — damit kaeme man beim Hochscrollen NIE an Scope-Band und Filterleiste an.
  # Deshalb: Filterleiste klebt oben, und fruehere Monate kommen per Knopf.
  test "im Strom klebt die Filterleiste oben und frueheres kommt per Knopf" do
    kalender(scope: {region: @region.id}, month: @monat, view: "stream")
    assert_response :success
    assert_match(/data-action="calendar-stream#loadEarlier"/, response.body,
      "nach oben wird per Knopf geladen, nicht automatisch")
    assert_match(/#{Regexp.escape(I18n.t("calendars.stream.load_earlier"))}/, response.body)
    assert_match(/border-gray-700 sticky top-0/, response.body,
      "die Filterleiste muss im Strom kleben, sonst scrollen die Selektoren weg")
  end

  test "ausserhalb des Stroms klebt die Filterleiste nicht" do
    kalender(scope: {region: @region.id}, month: @monat, view: "agenda")
    assert_response :success
    # Auf die FILTERLEISTE eingegrenzt: "sticky top-0" kommt im Layout auch anderswo vor.
    refute_match(/border-gray-700 sticky top-0/, response.body,
      "in Agenda und Monatsraster erreicht man den Kopf durch normales Scrollen")
    refute_match(/calendar-stream#loadEarlier/, response.body)
  end

  test "der Nachschub-Endpoint liefert spaetere und fruehere Monate" do
    kalender(scope: {region: @region.id}, month: @monat, view: "stream")

    get calendar_months_url(from: "2026-11", count: 3)
    assert_response :success
    assert_equal %w[2026-12 2027-01 2027-02], response.body.scan(/data-month="([\d-]+)"/).flatten

    get calendar_months_url(from: "2026-11", count: -3)
    assert_response :success
    assert_equal %w[2026-08 2026-09 2026-10], response.body.scan(/data-month="([\d-]+)"/).flatten,
      "rueckwaerts aufsteigend, damit sich die Kacheln am Stueck davorsetzen lassen"
  end

  test "der Nachschub-Endpoint antwortet ohne Layout" do
    kalender(scope: {region: @region.id}, view: "stream")
    get calendar_months_url(from: "2026-11", count: 1)
    assert_response :success
    refute_match(/<html|scope-band/, response.body,
      "das Fragment darf weder Layout noch Scope-Band mitbringen")
  end

  # AC-4 — der Strom endet an den Saisongrenzen statt ins Leere zu laufen.
  test "der Nachschub-Endpoint liefert an den Grenzen nichts" do
    kalender(scope: {region: @region.id}, view: "stream")

    get calendar_months_url(from: "2009-07", count: -6)
    assert_response :success
    assert_empty response.body.scan("data-month="), "vor Juli 2009 gibt es nichts"

    _, obergrenze = calendar_month_bounds_fuer_test
    get calendar_months_url(from: obergrenze.strftime("%Y-%m"), count: 6)
    assert_response :success
    assert_empty response.body.scan("data-month="), "hinter der Obergrenze gibt es nichts"
  end

  # AC-5 — nachgeladene Kacheln tragen denselben Ausschnitt und dieselben Achsen.
  test "nachgeladene Kacheln tragen Ausschnitt und Achsen der ersten Ladung" do
    tag = Date.new(2027, 1, 9)
    Tournament.create!(id: BASE_ID + 41, title: "Strom Turnier", season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: disciplines(:pool_8ball), date: tag.to_time + 11.hours)
    liga = liga_ohne_stempel!(42, "Strom Liga")
    Party.create!(id: BASE_ID + 43, league: liga, date: tag.to_time + 13.hours)

    kalender(scope: {region: @region.id}, view: "stream")

    get calendar_months_url(from: "2026-12", count: 1)
    assert_match(/Strom Turnier/, response.body)
    assert_match(/Strom Liga/, response.body)

    # Achse "Einzel" muss auch im Nachschub greifen.
    get calendar_months_url(from: "2026-12", count: 1, kind: "single")
    assert_match(/Strom Turnier/, response.body)
    refute_match(/Strom Liga/, response.body,
      "die Achse aus dem URL muss auch fuer nachgeladene Kacheln gelten")

    # Und der Ausschnitt (Sparte) aus der Session ebenso.
    kalender(scope: {branch: disciplines(:branch_karambol).id}, view: "stream")
    get calendar_months_url(from: "2026-12", count: 1)
    refute_match(/Strom Turnier/, response.body,
      "die Sparte aus dem Scope-Band muss auch fuer nachgeladene Kacheln gelten")
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
