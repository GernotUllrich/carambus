# frozen_string_literal: true

require "test_helper"

class League::SeriesUnifierTest < ActiveSupport::TestCase
  BASE = 50_000_000 + 87_000

  setup do
    @region = regions(:bbl)
    @pool = disciplines(:branch_pool)
    @n = 0
  end

  def league(name, season, staffel: nil)
    @n += 1
    League.create!(id: BASE + @n, name: name, staffel_text: staffel, shortname: "SU#{@n}",
      organizer: @region, season: seasons(season), discipline: @pool)
  end

  def unify(armed: true) = League::SeriesUnifier.new(region: @region, armed: armed).call

  test "Schlüssel ignorieren Disziplinwort, Trenner und Staffel-Präfix" do
    keys = ["Bezirksliga Pool", "Bezirksliga - Pool", "Pool Bezirksliga", "Bezirksliga"].map { |n| League.series_name_key(n, "Pool") }
    assert_equal ["bezirksliga"], keys.uniq
    assert_equal League.series_name_key("Ersatzbank - Pool", "Pool"), League.series_name_key("Ersatzbank Ligen Pool", "Pool")
    assert_equal "landesligen x", League.series_name_key("Landesligen X", "Pool"), "nur das ganze Wort"
    assert_equal "a", League.staffel_key("Staffel A")
    assert_equal "schwaben süd", League.staffel_key("Schwaben-Süd")
    assert_nil League.staffel_key(" ")
  end

  test "alle Ligen der Reihe bekommen den jüngsten Namen, frühere als Synonyme" do
    old = league("Bezirksliga Pool", :season_2024)
    mid = league("Bezirksliga", :previous)
    new = league("Bezirksliga - Pool", :current)

    unify

    [old, mid, new].each(&:reload)
    assert_equal ["Bezirksliga - Pool"], [old, mid, new].map { |l| l.read_attribute(:name) }.uniq
    assert_equal "Bezirksliga Pool", old.synonym_list.first, "eigener Ursprungsname zuerst"
    assert_equal ["Bezirksliga", "Bezirksliga - Pool", "Bezirksliga Pool"], old.synonym_list.sort
    assert_equal "Bezirksliga", mid.synonym_list.first
  end

  test "Wiederholung ändert nichts" do
    league("Bezirksliga Pool", :previous)
    league("Bezirksliga - Pool", :current)
    unify

    assert_empty League::SeriesUnifier.new(region: @region).call.changes
  end

  test "Dry-Run schreibt nicht" do
    old = league("Bezirksliga Pool", :previous)
    league("Bezirksliga - Pool", :current)

    result = unify(armed: false)

    assert_equal "Bezirksliga Pool", old.reload.read_attribute(:name)
    assert_includes result.changes.map(&:league), old
  end

  test "Staffel-Schreibweise der jüngsten Saison gewinnt" do
    old = league("Kreisklasse Pool", :previous, staffel: "Staffel A")
    league("Kreisklasse - Pool", :current, staffel: "A")

    unify

    old.reload
    assert_equal "Kreisklasse - Pool", old.read_attribute(:name)
    assert_equal "A", old.staffel_text
  end

  test "verschiedene Staffeln (Nord vs. A) bleiben verschieden" do
    old = league("Kreisklasse", :season_2024, staffel: "Nord")
    league("Kreisklasse - Pool", :current, staffel: "A")

    unify

    assert_equal "Nord", old.reload.staffel_text
  end

  test "Staffel im Namen wird zu staffel_text" do
    old = league("Verbandsliga - Mitte", :previous)
    league("Verbandsliga", :current, staffel: "Mitte")

    unify

    old.reload
    assert_equal "Verbandsliga", old.read_attribute(:name)
    assert_equal "Mitte", old.staffel_text
  end

  test "1 OH entspricht OH, 2 OH bleibt eigene Staffel" do
    assert_equal "oh", League.staffel_key("1 OH")
    assert_equal "2 oh", League.staffel_key("2 OH")
    assert_equal "1", League.staffel_key("1")

    old = league("Pool Kreisliga", :previous, staffel: "OH")
    newest = league("Kreisliga", :current, staffel: "1 OH")
    unify

    assert_equal ["OH", "OH"], [old, newest].map { |l| l.reload.staffel_text }, "Form ohne 1 gewinnt"
  end

  test "Doppelanlage mit Staffel im Namen wird als Dublette gemeldet" do
    ba = league("Pool Verbandsliga", :previous, staffel: "West")
    cc = league("Verbandsliga West", :previous)
    league("Verbandsliga", :current, staffel: "West")

    result = unify

    assert_equal [ba, cc].sort_by(&:id), result.series.flat_map(&:duplicates).map(&:league).sort_by(&:id)
  end

  test "BLVN-Bezirkskürzel entsprechen der Langform" do
    assert_equal League.staffel_key("Weser / Ems West", "BLVN"), League.staffel_key("WE West", "BLVN")
    assert_equal League.staffel_key("Osnabrück / Huntegau", "BLVN"), League.staffel_key("1 OH", "BLVN")
    assert_equal League.staffel_key("Weserbergland Nord", "BLVN"), League.staffel_key("WB Nord", "BLVN")
    refute_equal League.staffel_key("Weser / Ems", "NBV"), League.staffel_key("WE", "NBV"), "nur für BLVN"
  end

  test "Staffel im Namen wandert nicht, wenn die Reihe sie in derselben Saison schon hat" do
    own = league("Pool Kreisliga", :previous, staffel: "1 OH")
    second = league("Kreisliga OH", :previous)
    league("Kreisliga OH", :current, staffel: "2 OH")
    league("Kreisliga", :season_2024, staffel: "OH")
    league("Kreisliga", :current, staffel: "1 OH")
    unify

    assert_equal "OH", own.reload.staffel_text
    second.reload
    assert_equal ["Kreisliga OH", nil], [second.read_attribute(:name), second.staffel_text]
  end

  test "jüngste Saison mit eingebetteter Staffel liefert den Basisnamen" do
    league("Landesliga", :previous, staffel: "West")
    newest = league("Landesliga Staffel West", :current)

    unify

    newest.reload
    assert_equal "Landesliga", newest.read_attribute(:name)
    assert_equal "West", newest.staffel_text
  end

  test "Reihenname nur als Basis: ein Lauf genügt" do
    old = league("Pool Bezirksliga", :season_2024, staffel: "A")
    league("Bezirksliga A", :current)
    league("Bezirksliga B", :current)
    league("Pool Bezirksliga", :season_2024, staffel: "B")

    unify

    assert_includes old.reload.synonym_list, "Bezirksliga"
    assert_empty League::SeriesUnifier.new(region: @region).call.changes
  end

  test "Ligenname im Staffelfeld wird entfernt, Disziplinwort ignoriert" do
    a = league("Bezirksliga", :previous, staffel: "Bezirksliga A")
    s = league("Oberliga Pool", :season_2024, staffel: "Oberliga A Pool")
    pokal = league("Saarlandpokal Dreiband (TB)", :previous, staffel: "Saarlandpokal Dreiband Gruppe A")

    unify

    assert_equal "A", a.reload.staffel_text
    assert_equal ["Oberliga Pool", "A"], [s.reload.read_attribute(:name), s.staffel_text]
    assert_equal "Saarlandpokal Dreiband Gruppe A", pokal.reload.staffel_text, "nur bei ganzem Namen"
  end

  test "Staffel im Namen: längstes Ziel, das die Staffel führt (ein Lauf genügt)" do
    nw = league("Verbandsliga Nord-West", :previous)
    league("Verbandsliga Nord", :season_2024)
    league("Verbandsliga", :current, staffel: "Nord")
    league("Verbandsliga", :season_2024, staffel: "Nord-West")

    unify

    nw.reload
    assert_equal ["Verbandsliga", "Nord-West"], [nw.read_attribute(:name), nw.staffel_text]
    assert_empty League::SeriesUnifier.new(region: @region).call.changes
  end

  test "Dubletten derselben Saison bleiben unangetastet" do
    a = league("Oberliga Pool", :previous)
    b = league("Oberliga", :previous)
    league("Oberliga - Pool", :current)

    result = unify

    assert_equal ["Oberliga Pool", "Oberliga"], [a, b].map { |l| l.reload.read_attribute(:name) }
    assert_equal [a, b].sort_by(&:id), result.series.flat_map(&:duplicates).map(&:league).sort_by(&:id)
  end

  test "expand_staffel schreibt BLVN-Kürzel aus und stellt den Bezirk nach vorn" do
    {"OH" => "Osnabrück / Huntegau", "1 OH" => "Osnabrück / Huntegau", "2 OH" => "Osnabrück / Huntegau 2",
     "OH / A" => "Osnabrück / Huntegau A", "WB Mitte" => "Weserbergland Mitte",
     "Nord  Weserbergland" => "Weserbergland Nord", "West  Weser / Ems" => "Weser / Ems West",
     "Weser / Ems Ost" => "Weser / Ems Ost"}.each do |raw, expanded|
      assert_equal expanded, League.expand_staffel(raw, "BLVN"), raw
    end
    assert_equal "WE", League.expand_staffel("WE", "NBV"), "nur für BLVN"
    assert_nil League.expand_staffel("Neue Staffel"), "BA-Platzhalter"
  end

  def blvn
    @blvn ||= Region.create!(id: BASE + 900, shortname: "BLVN", name: "Billard-Landesverband Niedersachsen")
  end

  def blvn_league(name, season, staffel: nil, discipline: @pool, **attrs)
    @n += 1
    League.create!(id: BASE + @n, name: name, staffel_text: staffel, shortname: "SU#{@n}",
      organizer: blvn, season: seasons(season), discipline: discipline, **attrs)
  end

  def unify_blvn(armed: true, overrides: {}) = League::SeriesUnifier.new(region: blvn, armed: armed, overrides: overrides).call

  test "BLVN: Kürzel-Präfix im Namen wird Staffel, Staffeln in Langform, CC-Doppelanlage wird Dublette" do
    ba = blvn_league("Pool Kreisliga", :previous, staffel: "OH")
    cc = blvn_league("OH - Kreisliga", :previous, cc_id: 19)
    wb = blvn_league("WB - Bezirksliga", :previous, staffel: "Nord  Weserbergland")
    old_wb = blvn_league("Bezirksliga", :season_2024, staffel: "WB Nord")
    blvn_league("Kreisliga", :current, staffel: "Osnabrück / Huntegau")
    blvn_league("Bezirksliga", :current, staffel: "Weserbergland Nord")

    result = unify_blvn

    assert_equal [ba, cc].sort_by(&:id), result.series.flat_map(&:duplicates).map(&:league).sort_by(&:id)
    assert_equal ["Bezirksliga", "Weserbergland Nord"], [wb.reload.read_attribute(:name), wb.staffel_text]
    assert_equal "Weserbergland Nord", old_wb.reload.staffel_text
    assert_includes wb.synonym_list, "WB - Bezirksliga"
    assert_empty unify_blvn(armed: false).changes, "ein Lauf genügt"
  end

  test "BLVN: Kürzel ohne Langform in der Reihe werden trotzdem ausgeschrieben" do
    a = blvn_league("Kreisklasse", :previous, staffel: "WB Mitte")
    blvn_league("Kreisklasse", :current, staffel: "WB Mitte")

    unify_blvn

    assert_equal "Weserbergland Mitte", a.reload.staffel_text
  end

  test "Overrides setzen Name und Staffel einzelner Ligen" do
    oh = blvn_league("Kreisliga OH", :previous, staffel: "Pool Kreisliga 1")
    blvn_league("Kreisliga", :current, staffel: "Osnabrück / Huntegau")

    unify_blvn(overrides: {oh.id => ["Kreisliga", "Osnabrück / Huntegau"]})

    oh.reload
    assert_equal ["Kreisliga", "Osnabrück / Huntegau"], [oh.read_attribute(:name), oh.staffel_text]
    assert_includes oh.synonym_list, "Kreisliga OH"
  end

  test "Oberdisziplin-Liga schließt sich der einzigen Unterdisziplin-Reihe an, Regionskürzel zählt nicht" do
    karambol = disciplines(:branch_karambol)
    gross = Discipline.create!(id: BASE + 950, name: "Karambol großes Billard", super_discipline: karambol)
    ba = blvn_league("BLVN Oberliga Dreiband", :season_2024, discipline: gross)
    ba21 = blvn_league("Oberliga Dreiband", :previous, discipline: gross)
    cc21 = blvn_league("Oberliga Dreiband", :previous, discipline: karambol, cc_id: 27)
    blvn_league("Oberliga Dreiband", :current, discipline: karambol)

    result = unify_blvn

    assert_equal "Oberliga Dreiband", ba.reload.read_attribute(:name)
    assert_equal gross, ba.discipline, "Disziplin bleibt"
    assert_equal [ba21, cc21].sort_by(&:id), result.series.flat_map(&:duplicates).map(&:league).sort_by(&:id)
  end

  test "zwei Unterdisziplinen mit gleichem Namen bleiben getrennt" do
    karambol = disciplines(:branch_karambol)
    gross = Discipline.create!(id: BASE + 951, name: "Karambol großes Billard", super_discipline: karambol)
    klein = Discipline.create!(id: BASE + 952, name: "Karambol kleines Billard", super_discipline: karambol)
    blvn_league("Landesliga", :previous, discipline: gross)
    blvn_league("Landesliga", :previous, discipline: klein)
    blvn_league("Landesliga", :current, discipline: karambol)

    assert_empty unify_blvn(armed: false).series.flat_map(&:duplicates)
  end

  test "Staffel „Neue Staffel“ ist ein Platzhalter und fällt weg" do
    real = blvn_league("BLVN Oberliga Dreiband", :season_2024, staffel: "Neue Staffel")
    blvn_league("Oberliga Dreiband", :current)

    unify_blvn

    assert_equal ["Oberliga Dreiband", nil], [real.reload.read_attribute(:name), real.staffel_text]
  end

  test "with_name_or_synonym findet umbenannte Ligen über den alten Namen" do
    old = league("Bezirksliga Pool", :previous)
    league("Bezirksliga - Pool", :current)
    unify

    found = League.where(season: seasons(:previous), organizer: @region).with_name_or_synonym("Bezirksliga Pool")
    assert_equal [old], found
    assert_empty League.where(organizer: @region).with_name_or_synonym("Bezirksliga")
  end
end
