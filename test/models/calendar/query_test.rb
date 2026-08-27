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

    treffer = eintraege(branch_name: "Pool")
    assert_equal 1, treffer.size,
      "Ueber die Disziplin-Wurzel gehoert sie zu Pool — ein Filter auf branch_id allein verloere sie"
    assert_equal "Bezirksliga Mitte 1", treffer.first.title
  end

  test "der Branch-Filter schliesst fremde Sparten aus" do
    liga = liga_ohne_stempel!(6, "Oberliga Pool", discipline: disciplines(:pool_8ball))
    spieltag!(7, liga)

    assert_empty eintraege(branch_name: "Karambol")
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
end
