# frozen_string_literal: true

require "test_helper"

# Die Datenschicht der Kalenderseite: Turniere und Liga-Spieltage einer Region in einem Zeitraum.
class Calendar::QueryTest < ActiveSupport::TestCase
  BASE_ID = 59_000_000

  setup do
    @region = regions(:nbv)
    @season = seasons(:current)
    @dbu = Region.find_or_create_by!(shortname: "DBU") { |r| r.name = "Deutsche Billard-Union" }
    @von = Date.current.beginning_of_month
    @bis = Date.current.end_of_month
    @tag = @von + 10
  end

  def turnier!(id_offset, titel, region:, discipline:, branch_id: nil, tag: @tag)
    Tournament.create!(id: BASE_ID + id_offset, title: titel, season: @season,
      organizer: region, organizer_type: "Region", region_id: region.id,
      discipline: discipline, branch_id: branch_id,
      date: tag.to_time + 11.hours)
  end

  # Der Fall der 43 ungestempelten Ligen auf Produktion.
  #
  # `BranchTaggable#set_branch_id` stempelt beim Speichern automatisch — die ungestempelten sind
  # also ALTBESTAND von vor dem Callback. Genau den bildet `update_columns` nach: es geht an den
  # Callbacks vorbei. Ein `create!(branch_id: nil)` allein reicht nicht, der Stempel kaeme zurueck.
  def liga_ohne_stempel!(id_offset, name, discipline:)
    liga = League.create!(id: BASE_ID + id_offset, name: name, season: @season,
      organizer: @region, organizer_type: "Region", region_id: @region.id,
      discipline: discipline, shortname: name.parameterize.first(12))
    liga.update_columns(branch_id: nil)
    liga.reload
  end

  def spieltag!(id_offset, league, tag: @tag)
    Party.create!(id: BASE_ID + id_offset, league: league, date: tag.to_time + 13.hours)
  end

  def eintraege(**opts)
    Calendar::Query.new(region: @region, from: @von, to: @bis, **opts).call
  end

  def query(**opts)
    Calendar::Query.new(region: @region, from: @von, to: @bis, **opts)
  end

  # Haengt einem Turnier eine Turniergruppe an. Quelle ist der DENORMALISIERTE
  # `championship_type_cc_name` auf dem CC-Zwilling — nicht CategoryCc (siehe Kommentar in
  # query.rb: nur im NBV gepflegt, mischt Serien mit Alters-/Geschlechtsklassen).
  def gruppe!(id_offset, tournament, name)
    TournamentCc.create!(id: BASE_ID + id_offset, tournament: tournament,
      championship_type_cc_name: name, name: tournament.title)
  end

  test "Turniere und Spieltage stehen gemeinsam und nach Datum sortiert" do
    turnier!(1, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    liga = liga_ohne_stempel!(2, "Oberliga Pool", discipline: disciplines(:pool_8ball))
    spieltag!(3, liga)

    e = eintraege
    assert_equal 2, e.size
    assert_equal %i[tournament party], e.map(&:kind).sort_by(&:to_s).reverse
    assert e.each_cons(2).all? { |a, b| a.starts_on <= b.starts_on }, "muss nach Datum sortiert sein"
  end

  # AC-2 — der Test, der die 43 ungestempelten Ligen schuetzt.
  test "der Branch-Filter findet auch eine Liga OHNE branch_id" do
    liga = liga_ohne_stempel!(4, "Bezirksliga Mitte 1", discipline: disciplines(:pool_8ball))
    spieltag!(5, liga)
    assert_nil liga.reload.branch_id, "Vorbedingung: diese Liga traegt keinen Stempel"

    treffer = eintraege(branch: disciplines(:branch_pool))
    assert_equal 1, treffer.size,
      "Ueber die Disziplin-Wurzel gehoert sie zu Pool — ein Filter auf branch_id allein verloere sie"
    assert_equal "Bezirksliga Mitte 1", treffer.first.title
  end

  test "der Branch-Filter schliesst fremde Sparten aus" do
    liga = liga_ohne_stempel!(6, "Oberliga Pool", discipline: disciplines(:pool_8ball))
    spieltag!(7, liga)

    assert_empty eintraege(branch: disciplines(:branch_karambol))
  end

  test "der DBU-Schalter blendet die ueberregionale Ebene aus" do
    turnier!(8, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    turnier!(9, "DBU Grand Prix", region: @dbu, discipline: disciplines(:pool_8ball))

    mit = eintraege(include_dbu: true)
    ohne = eintraege(include_dbu: false)

    assert_equal 2, mit.size
    assert_equal 1, ohne.size
    assert_equal :region, ohne.first.source
    assert_equal [:dbu], (mit.map(&:source) - [:region]).uniq
  end

  test "ein Zeitraum ohne Termine liefert eine leere Liste statt zu werfen" do
    assert_empty eintraege
  end

  test "ein Spieltag traegt Paarung, Uhrzeit und Liga als Gruppierungsachse" do
    liga = liga_ohne_stempel!(10, "Oberliga Snooker", discipline: disciplines(:pool_8ball))
    a = LeagueTeam.create!(id: BASE_ID + 11, name: "BC Wedel 1", league: liga)
    b = LeagueTeam.create!(id: BASE_ID + 12, name: "BG Hamburg 2", league: liga)
    p = spieltag!(13, liga)
    p.update!(league_team_a: a, league_team_b: b)

    e = eintraege.first
    assert_equal "Oberliga Snooker", e.league_name
    assert_equal "BC Wedel 1 – BG Hamburg 2", e.subtitle
    assert_equal "13:00", e.time
  end

  test "ein mehrtaegiges Turnier kennt seine Tage, ein eintaegiges nicht" do
    t = turnier!(14, "Deutsche Meisterschaft", region: @region, discipline: disciplines(:pool_8ball))
    t.update!(end_date: (@tag + 3).to_time + 18.hours)

    e = eintraege.first
    assert e.multi_day?
    assert_equal 4, e.days.size

    t.update!(end_date: nil)
    refute eintraege.first.multi_day?
  end

  # --- AC-4: Einzel/Mannschaft ---------------------------------------------------------------

  test "die Einzel/Mannschaft-Achse trennt Turniere von Spieltagen" do
    turnier!(20, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    liga = liga_ohne_stempel!(21, "Oberliga Pool", discipline: disciplines(:pool_8ball))
    spieltag!(22, liga)

    assert_equal 2, eintraege.size
    assert_equal [:tournament], eintraege(kind: "single").map(&:kind).uniq
    assert_equal [:party], eintraege(kind: "team").map(&:kind).uniq
  end

  # --- AC-5/AC-6: Turniergruppe --------------------------------------------------------------

  # Gemessen 2026-08-27: von 49 Rohwerten unterscheiden sich zwei nur in der Anzahl der
  # Leerzeichen. Ohne Normalisierung staenden zwei optisch gleiche Knoepfe nebeneinander,
  # die je die Haelfte der Turniere zeigen.
  test "Gruppennamen, die sich nur in Leerzeichen unterscheiden, sind EINE Gruppe" do
    a = turnier!(60, "DJM Freie Partie A", region: @region, discipline: disciplines(:pool_8ball))
    b = turnier!(61, "DJM Freie Partie B", region: @region, discipline: disciplines(:pool_8ball))
    gruppe!(62, a, "Deutsche Jugend Meisterschaft (DJM)")
    gruppe!(63, b, "Deutsche Jugend Meisterschaft  (DJM)")   # zwei Leerzeichen

    assert_equal ["Deutsche Jugend Meisterschaft (DJM)"], query.group_options,
      "beide Schreibweisen gehoeren zu EINER Option"
    assert_equal ["DJM Freie Partie A", "DJM Freie Partie B"],
      eintraege(group: "Deutsche Jugend Meisterschaft (DJM)").map(&:title).sort,
      "und der Filter muss beide Schreibweisen fangen"
  end

  test "der Gruppenfilter zeigt nur die Turniere seiner Gruppe" do
    ndm = turnier!(23, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    cup = turnier!(24, "NordCup Dreiband", region: @region, discipline: disciplines(:pool_8ball))
    gruppe!(25, ndm, "NDM")
    gruppe!(26, cup, "NordCup")

    treffer = eintraege(group: "NDM")
    assert_equal ["NDM Freie Partie"], treffer.map(&:title)
  end

  # AC-6 — der CC-lose Fall (TBV #18613/#18614 auf Produktion).
  test "ein Turnier OHNE CC-Zwilling steht ungefiltert da und ist als ohne Zuordnung waehlbar" do
    ndm = turnier!(27, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    gruppe!(28, ndm, "NDM")
    ohne = turnier!(29, "LM Dreiband MB", region: @region, discipline: disciplines(:pool_8ball))
    assert_nil ohne.tournament_cc, "Vorbedingung: dieses Turnier hat keinen CC-Zwilling"

    assert_includes eintraege.map(&:title), "LM Dreiband MB",
      "ohne Gruppenfilter darf ein CC-loses Turnier nicht wegfallen"
    assert_equal ["LM Dreiband MB"],
      eintraege(group: Calendar::Query::GROUP_NONE).map(&:title)
    assert_equal ["NDM Freie Partie"], eintraege(group: "NDM").map(&:title)
  end

  test "die Gruppen-Optionen kommen aus dem Zeitraum, nicht aus allen bekannten Gruppen" do
    ndm = turnier!(30, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    gruppe!(31, ndm, "NDM")
    # Eine Gruppe, die es gibt, im Zeitraum aber nicht vorkommt (Turnier drei Monate spaeter).
    spaeter = turnier!(32, "Grand Prix", region: @region,
      discipline: disciplines(:pool_8ball), tag: @von + 3.months + 5)
    gruppe!(33, spaeter, "Grand Prix")

    assert_equal ["NDM"], query.group_options
    refute_includes query.group_options, "Grand Prix",
      "ein Selektor ueber alle bekannten Gruppen boete an, was der Zeitraum gar nicht hergibt"
  end

  test "die Gruppen-Optionen nennen ohne Zuordnung nur, wenn es solche Turniere gibt" do
    ndm = turnier!(34, "NDM Freie Partie", region: @region, discipline: disciplines(:pool_8ball))
    gruppe!(35, ndm, "NDM")
    refute_includes query.group_options, Calendar::Query::GROUP_NONE

    turnier!(36, "LM Dreiband MB", region: @region, discipline: disciplines(:pool_8ball))
    assert_includes query(**{}).group_options, Calendar::Query::GROUP_NONE
  end

  # --- AC-7: Disziplin -----------------------------------------------------------------------

  test "der Disziplin-Filter wirkt auf Turniere UND Spieltage" do
    turnier!(37, "NDM 8-Ball", region: @region, discipline: disciplines(:pool_8ball))
    turnier!(38, "NDM 9-Ball", region: @region, discipline: disciplines(:pool_9ball))
    liga8 = liga_ohne_stempel!(39, "Oberliga 8-Ball", discipline: disciplines(:pool_8ball))
    spieltag!(40, liga8)
    liga9 = liga_ohne_stempel!(41, "Oberliga 9-Ball", discipline: disciplines(:pool_9ball))
    spieltag!(42, liga9)

    treffer = eintraege(discipline_name: "8-Ball").map(&:title).sort
    assert_equal ["NDM 8-Ball", "Oberliga 8-Ball"], treffer,
      "die Disziplin muss beide Arten filtern — Turnier und Liga fuehren je eine"
  end

  # Betreiber-Befund 2026-08-27: Sparte Pool gewaehlt, Disziplin "Pool" gewaehlt — es kamen nur
  # Spieltage. Ursache: Turniere haengen an BLATT-Disziplinen ("8-Ball"), Ligen am Branch-Record
  # selbst ("Pool"); der Filter verglich exakt auf den Namen.
  test "die Disziplin trifft auch alles unterhalb — Branch-Name faengt die Blatt-Disziplinen" do
    turnier!(45, "NDJM Pool 8-Ball", region: @region, discipline: disciplines(:pool_8ball))
    # Eine Liga, die — wie in echt — den Branch-Record als Disziplin traegt.
    liga = liga_ohne_stempel!(46, "Verbandsliga Pool", discipline: disciplines(:branch_pool))
    spieltag!(47, liga)

    treffer = eintraege(discipline_name: "Pool").map(&:title).sort
    assert_equal ["NDJM Pool 8-Ball", "Verbandsliga Pool"], treffer,
      "\"Pool\" muss das Turnier an der Blatt-Disziplin UND die Liga am Branch-Record fangen"
  end

  test "eine Blatt-Disziplin bleibt eng und zieht nicht den ganzen Branch herein" do
    turnier!(48, "NDM 8-Ball", region: @region, discipline: disciplines(:pool_8ball))
    turnier!(49, "NDM 9-Ball", region: @region, discipline: disciplines(:pool_9ball))

    assert_equal ["NDM 8-Ball"], eintraege(discipline_name: "8-Ball").map(&:title),
      "wer 8-Ball waehlt, will nicht 9-Ball dazu"
  end

  test "die Disziplin-Optionen folgen der Sparte" do
    turnier!(43, "NDM 8-Ball", region: @region, discipline: disciplines(:pool_8ball))
    turnier!(44, "Cadre-Turnier", region: @region, discipline: disciplines(:karambol_cadre_35_2))

    alle = query.discipline_options
    assert_includes alle, "8-Ball"
    assert_includes alle, "Cadre 35/2"

    nur_pool = query(branch: disciplines(:branch_pool)).discipline_options
    assert_equal ["8-Ball"], nur_pool,
      "bei Sparte Pool darf keine Karambol-Disziplin im Selektor stehen"
  end
end
