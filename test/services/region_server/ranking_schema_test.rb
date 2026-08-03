# frozen_string_literal: true

require "test_helper"

# Plan 36-01: Der Spaltensatz der Gesamtrangliste je Disziplin.
#
# Die Saetze sind empirisch erhoben (dominanter CC-Satz je Disziplin). Die Tests halten fest, was
# gemessen wurde — nicht, was plausibel schien. Der wichtigste Block ist "Typen": ein Integer statt
# eines Float bei GD/BED schneidet in carambus.rake:765 still ab, und das faellt erst Monate spaeter
# in einer falschen Regionalrangliste auf.
class RegionServer::RankingSchemaTest < ActiveSupport::TestCase
  # --- AC-1: Spaltensatz folgt der Disziplin ----------------------------------

  test "Karambol traegt den gemessenen CC-Satz" do
    keys = RegionServer::RankingSchema.new("Karambol").fields.map(&:key)

    assert_equal %w[Rang Bälle Aufn GD HS BED Punkte], keys
  end

  test "Pool traegt den gemessenen CC-Satz" do
    keys = RegionServer::RankingSchema.new("Pool").fields.map(&:key)

    assert_equal ["Rang", "G", "V", "Quote", "Sp.G", "Sp.V", "Sp.Quote"], keys
  end

  test "Snooker traegt den gemessenen CC-Satz" do
    keys = RegionServer::RankingSchema.new("Snooker").fields.map(&:key)

    assert_equal %w[Rang G V Quote Frames HB Punkte], keys
  end

  test "Kegel traegt den gemessenen CC-Satz" do
    keys = RegionServer::RankingSchema.new("Kegel").fields.map(&:key)

    assert_equal %w[Rang Kegel GD Partiepunkte Satzpunkte], keys
  end

  test "jede Disziplin fuehrt Rang als erstes Feld" do
    RegionServer::RankingSchema::SETS.each_key do |root|
      assert_equal "Rang", RegionServer::RankingSchema.new(root).fields.first.key,
        "#{root} fuehrt Rang nicht an erster Stelle"
    end
  end

  test "Name und Verein sind keine Formularfelder" do
    RegionServer::RankingSchema::SETS.each_key do |root|
      keys = RegionServer::RankingSchema.new(root).fields.map(&:key)

      assert_not_includes keys, "Name", "#{root}: Name gehoert aus dem Seeding, nicht ins Formular"
      assert_not_includes keys, "Verein", "#{root}: Verein gehoert aus dem Seeding, nicht ins Formular"
    end
  end

  # --- Berechnete Felder erscheinen nicht im Formular -------------------------

  test "GD ist bei Karambol berechnet, bei Kegel Eingabe" do
    karambol = RegionServer::RankingSchema.new("Karambol")
    kegel = RegionServer::RankingSchema.new("Kegel")

    assert_not_includes karambol.input_fields.map(&:key), "GD"
    # Der Kegel-Satz fuehrt keinen Baelle/Aufn-Zaehler, aus dem sich GD ergeben koennte.
    assert_includes kegel.input_fields.map(&:key), "GD"
  end

  test "Quoten sind berechnet und nie Eingabe" do
    %w[Pool Snooker].each do |root|
      schema = RegionServer::RankingSchema.new(root)

      assert_not_includes schema.input_fields.map(&:key), "Quote", "#{root}: Quote darf nicht eingetippt werden"
    end
    assert_not_includes RegionServer::RankingSchema.new("Pool").input_fields.map(&:key), "Sp.Quote"
  end

  test "Rang und Punkte werden nie vorbelegt" do
    RegionServer::RankingSchema::SETS.each_key do |root|
      prefillable = RegionServer::RankingSchema.new(root).prefillable_fields.map(&:key)

      assert_not_includes prefillable, "Rang", "#{root}: Rang traegt die Turnierlogik"
      assert_not_includes prefillable, "Punkte", "#{root}: Punkte tragen die Serienlogik"
    end
  end

  # --- AC-5: Typen-Treue ------------------------------------------------------

  test "GD und BED werden als Float gecastet" do
    schema = RegionServer::RankingSchema.new("Karambol")

    assert_instance_of Float, schema.cast("BED", "0,750")
    # Ohne tr(",", ".") laese to_f aus "1,132" die Zahl 1.0.
    assert_in_delta 1.132, schema.cast("BED", "1,132"), 0.0001
  end

  test "Zaehlwerte werden als Integer gecastet" do
    schema = RegionServer::RankingSchema.new("Karambol")

    assert_instance_of Integer, schema.cast("Bälle", "44")
    assert_equal 105, schema.cast("Aufn", "105")
    assert_equal 2, schema.cast("Rang", "2")
  end

  test "leere Eingaben erzeugen keinen Wert" do
    schema = RegionServer::RankingSchema.new("Karambol")

    assert_nil schema.cast("Bälle", "")
    assert_nil schema.cast("Bälle", "   ")
    assert_nil schema.cast("Bälle", nil)
  end

  test "unbekannte Schluessel werden nicht gecastet" do
    assert_nil RegionServer::RankingSchema.new("Karambol").cast("Frames", "3")
  end

  # --- Berechnung -------------------------------------------------------------

  test "GD ergibt sich als Float aus Baellen und Aufnahmen" do
    entry = RegionServer::RankingSchema.new("Karambol").apply_computed({"Bälle" => 44, "Aufn" => 105})

    assert_instance_of Float, entry["GD"]
    assert_in_delta 0.419, entry["GD"], 0.0001
  end

  test "Quote entsteht in CC-Form mit Komma und Prozentzeichen" do
    entry = RegionServer::RankingSchema.new("Pool").apply_computed({"G" => 2, "V" => 2})

    assert_equal "50,00 %", entry["Quote"]
  end

  test "ohne Operanden entsteht kein berechnetes Feld" do
    entry = RegionServer::RankingSchema.new("Karambol").apply_computed({"Bälle" => 44})

    assert_not entry.key?("GD"), "GD ohne Aufnahmen waere eine erfundene Zahl"
  end

  test "Division durch null erzeugt kein Feld" do
    entry = RegionServer::RankingSchema.new("Pool").apply_computed({"G" => 0, "V" => 0})

    assert_not entry.key?("Quote")
  end

  test "apply_computed veraendert die uebergebene Struktur nicht" do
    original = {"Bälle" => 44, "Aufn" => 105}
    RegionServer::RankingSchema.new("Karambol").apply_computed(original)

    assert_equal({"Bälle" => 44, "Aufn" => 105}, original)
  end

  # --- Fallback ---------------------------------------------------------------

  test "unbekannte Disziplin faellt auf Karambol zurueck und zeigt es an" do
    schema = RegionServer::RankingSchema.new("Billard-Kaiser")

    assert_equal "Karambol", schema.root
    assert schema.fallback?, "Der Rueckfall muss benennbar sein"
  end

  test "fehlende Disziplin faellt ebenfalls zurueck" do
    assert RegionServer::RankingSchema.new(nil).fallback?
  end

  test "eine bekannte Disziplin ist kein Rueckfall" do
    assert_not RegionServer::RankingSchema.new("Pool").fallback?
  end

  test "for leitet die Disziplin aus dem Turnier ab" do
    schema = RegionServer::RankingSchema.for(tournaments(:local))

    assert_includes RegionServer::RankingSchema::SETS.keys, schema.root
  end

  test "for ohne Turnier faellt zurueck statt zu brechen" do
    assert_equal "Karambol", RegionServer::RankingSchema.for(nil).root
  end
end
