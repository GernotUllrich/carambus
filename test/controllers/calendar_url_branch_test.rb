# frozen_string_literal: true

require "test_helper"

# Die Sparten duerfen aus dem URL kommen (`/calendar?branch=Karambol,Kegel`).
#
# Anlass: der Kalender-Link auf der Scoreboard-Welcome-Page. An einem Karambol-Ort sind Pool-
# und Snooker-Termine Rauschen, aber ein Link kann die Session-Sparte nicht setzen, ohne sie
# jedem stillschweigend umzustellen — genau das verbietet die Entscheidung aus 42-02.
#
# MEHRERE Sparten, weil eine Tischart mehrere traegt: auf kleinem und Match Billard wird
# Karambol UND Kegel gespielt. Das Scope-Band kann das nicht — es fuehrt genau eine Sparte.
#
# Deshalb: lesend aus dem URL, das Scope-Band bleibt unberuehrt. Damit daraus kein
# UNSICHTBARER Filter wird (der Fehler, den 42-02 beseitigt hat), zeigt die Filterleiste
# einen eigenen Chip — das Band darueber zeigt ja weiter den Session-Wert.
class CalendarUrlBranchTest < ActionDispatch::IntegrationTest
  BASE_ID = 59_700_000

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @tag = Date.current.beginning_of_month + 9
    @monat = @tag.strftime("%Y-%m")
  end

  def kalender(scope: nil, **params)
    params[:scope] = scope if scope
    get calendar_url(**params)
  end

  def turnier!(offset, titel, discipline)
    Tournament.create!(id: BASE_ID + offset, title: titel, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: discipline, date: @tag.to_time + 11.hours)
  end

  def zwei_turniere!
    turnier!(1, "NDM Cadre 35 zwei", disciplines(:karambol_cadre_35_2))
    turnier!(2, "NDM 8-Ball zwei", disciplines(:pool_8ball))
  end

  # Eine Kegel-Disziplin unter der Branch "Kegel" — im Fixture-Bestand gibt es keine.
  def kegel_turnier!
    kegel = Branch.find_or_create_by!(name: "Kegel") { |b| b.type = "Branch" }
    bk = Discipline.find_or_create_by!(name: "BK50", super_discipline_id: kegel.id)
    turnier!(3, "NDM Billard-Kegeln", bk)
  end

  # AC — der Kern: einschraenken, ohne das Band anzufassen.
  test "branch im URL schraenkt ein, obwohl das Band keine Sparte traegt" do
    zwei_turniere!

    kalender(scope: {region: @region.id}, month: @monat)
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body)
    assert_match(/NDM 8-Ball zwei/, response.body, "ohne Filter sind beide Sparten da")

    kalender(month: @monat, branch: "Karambol")
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body)
    refute_match(/NDM 8-Ball zwei/, response.body, "die fremde Sparte muss wegfallen")
  end

  test "die URL-Sparte laesst das Scope-Band unveraendert" do
    zwei_turniere!

    kalender(scope: {region: @region.id}, month: @monat)
    kalender(month: @monat, branch: "Karambol")
    assert_response :success

    # Ohne den Parameter ist die Einschraenkung sofort wieder weg — waere sie ins Band
    # geschrieben worden, bliebe sie kleben.
    kalender(month: @monat)
    assert_response :success
    assert_match(/NDM 8-Ball zwei/, response.body,
      "das Band darf die Sparte nicht uebernommen haben")
  end

  test "eine gesetzte Band-Sparte gewinnt nicht gegen den URL" do
    zwei_turniere!

    kalender(scope: {region: @region.id, branch: disciplines(:branch_pool).id},
      month: @monat, branch: "Karambol")
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body, "der URL entscheidet fuer dieses Blatt")
    refute_match(/NDM 8-Ball zwei/, response.body)
  end

  test "ein unbekannter Spartenname faellt still auf das Band zurueck" do
    zwei_turniere!

    kalender(scope: {region: @region.id}, month: @monat, branch: "Weltraumbillard")
    assert_response :success, "ein kaputter Link soll eine Seite zeigen, keinen Fehler"
    assert_match(/NDM Cadre 35 zwei/, response.body)
    assert_match(/NDM 8-Ball zwei/, response.body, "ohne gueltige Sparte wird nicht gefiltert")
  end

  # Ohne Chip waere es ein unsichtbarer Filter — das Scope-Band zeigt weiter den Session-Wert.
  test "die Filterleiste macht die URL-Sparte sichtbar und wieder abwaehlbar" do
    zwei_turniere!

    kalender(scope: {region: @region.id}, month: @monat)
    refute_match(/Sparte: Karambol/, response.body, "ohne Parameter kein Chip")

    kalender(month: @monat, branch: "Karambol")
    assert_response :success
    assert_match(/Sparte: Karambol/, response.body)
    assert_select "a[href=?]", calendar_path(month: @monat),
      {minimum: 1}, "das × muss auf dieselbe Seite ohne branch fuehren"
  end

  # Sonst traegt die erste Kachel den Filter und jede nachgeladene nicht.
  test "die URL-Sparte haengt an den Filter-Links und am Nachschub des Stroms" do
    zwei_turniere!

    kalender(month: @monat, branch: "Karambol")
    assert_response :success
    assert_select "a[href*=?]", "branch=Karambol",
      {minimum: 1}, "die Monatsnavigation muss die Sparte mitnehmen"
    assert_match(/branch=Karambol|branch&quot;:&quot;Karambol/, response.body)

    get calendar_months_url(from: @monat, count: 1, branch: "Karambol")
    assert_response :success
    refute_match(/NDM 8-Ball zwei/, response.body,
      "auch nachgeladene Kacheln bleiben eingeschraenkt")
  end

  # Sonst schriebe der erste Klick die Band-Sparte in den URL und liesse sie dort kleben.
  test "eine Band-Sparte wandert nicht von selbst in die Filter-Links" do
    zwei_turniere!

    kalender(scope: {region: @region.id, branch: disciplines(:branch_karambol).id}, month: @monat)
    assert_response :success
    refute_match(/branch=Karambol/, response.body,
      "die Band-Sparte gehoert der Session, nicht dem URL")
  end

  # AC — der Kern der Nachbesserung: BC Wedel braucht Karambol UND Kegel.
  test "mehrere Sparten kommagetrennt schraenken auf ihre Vereinigung ein" do
    zwei_turniere!
    kegel_turnier!

    kalender(scope: {region: @region.id}, month: @monat, branch: "Karambol,Kegel")
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body)
    assert_match(/NDM Billard-Kegeln/, response.body, "Kegel gehoert zum Karambol-Ort dazu")
    refute_match(/NDM 8-Ball zwei/, response.body, "Pool bleibt draussen")
  end

  test "eine einzelne Sparte laesst die zweite weiterhin draussen" do
    zwei_turniere!
    kegel_turnier!

    kalender(scope: {region: @region.id}, month: @monat, branch: "Karambol")
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body)
    refute_match(/NDM Billard-Kegeln/, response.body)
  end

  test "unbekannte Namen fallen einzeln weg, die gueltigen greifen weiter" do
    zwei_turniere!
    kegel_turnier!

    kalender(scope: {region: @region.id}, month: @monat, branch: "Karambol,Weltraumbillard")
    assert_response :success
    assert_match(/NDM Cadre 35 zwei/, response.body)
    refute_match(/NDM 8-Ball zwei/, response.body,
      "ein Tippfehler darf den gueltigen Teil nicht entwerten")
  end

  test "der Chip nennt alle gewaehlten Sparten" do
    zwei_turniere!
    kegel_turnier!

    kalender(scope: {region: @region.id}, month: @monat, branch: "Karambol,Kegel")
    assert_response :success
    assert_match(/Sparte: Karambol \+ Kegel/, response.body)
  end

  test "mehrere Sparten haengen auch am Nachschub des Stroms" do
    zwei_turniere!
    kegel_turnier!

    kalender(month: @monat, branch: "Karambol,Kegel")
    assert_response :success

    get calendar_months_url(from: @monat, count: 1, branch: "Karambol,Kegel")
    assert_response :success
    refute_match(/NDM 8-Ball zwei/, response.body,
      "auch nachgeladene Kacheln bleiben eingeschraenkt")
  end
end
