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

  test "Dubletten derselben Saison bleiben unangetastet" do
    a = league("Oberliga Pool", :previous)
    b = league("Oberliga", :previous)
    league("Oberliga - Pool", :current)

    result = unify

    assert_equal ["Oberliga Pool", "Oberliga"], [a, b].map { |l| l.reload.read_attribute(:name) }
    assert_equal [a, b].sort_by(&:id), result.series.flat_map(&:duplicates).map(&:league).sort_by(&:id)
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
