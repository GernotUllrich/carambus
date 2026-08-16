# frozen_string_literal: true

require "test_helper"

# Der Klassifikator ist die EINZIGE Stelle, an der Carambus entscheidet, woher ein Turnier oder
# eine Liga stammt — Abdeckungsreport und die Spalte `source_kind` fragen beide hier.
# Die Kaskade `source_url` > `ba_id` > `*_cc` ist eine Betreiber-Entscheidung (2026-08-16), keine
# Geschmacksfrage: sie folgt der Messung im Bestand.
class Provenance::ClassifierTest < ActiveSupport::TestCase
  def classify(url, ba_id: nil, cc_present: false)
    Provenance::Classifier.call(source_url: url, ba_id: ba_id, cc_present: cc_present)
  end

  # Jeder Landesverband betreibt seine ClubCloud unter eigenem Namen, liefert aber dieselben
  # Skripte aus. Eine Domain-Liste waere schon beim naechsten Umzug falsch — und Umzuege gab es.
  test "erkennt die Quelle am URL-Muster, nicht an der Domain" do
    assert_equal :club_cloud, classify("https://ndbv.de/sb_meisterschaft.php?p=20--2026/2027-46-")
    assert_equal :club_cloud, classify("https://www.blv-sa.de/sb_spielplan.php?p=21--2026/2027-2-")
    assert_equal :club_cloud, classify("https://westfalenbillard.net/sb_meisterschaft.php?p=1")
    assert_equal :nu_liga, classify("https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/x")
    assert_equal :liga_manager, classify("https://ligen.billard.center/api/leagues/11")
    assert_equal :umb, classify("https://files.umb-carom.org/public/TournametDetails.aspx?ID=373")
    assert_equal :carambus, classify("https://tbv.carambus.de/tournaments/50000021")
  end

  test "die source_url gewinnt gegen jede aeltere Spur" do
    assert_equal :club_cloud,
      classify("https://ndbv.de/sb_meisterschaft.php?p=1", ba_id: 4711, cc_present: true),
      "ein spaeter aus der CC nachgescrapter Datensatz gehoert zur CC"
  end

  test "ohne source_url ist die ba_id die einzige Spur" do
    assert_equal :ba, classify(nil, ba_id: 4711)
    assert_equal :ba, classify("", ba_id: 4711)
  end

  # Der `tournament_cc` ist ein Migrationsartefakt BillardArea->ClubCloud. Er zaehlt erst, wenn
  # weder URL noch ba_id etwas sagen — sonst wuerden die 376 BA-Turniere mit CC-Zwilling als
  # ClubCloud durchgehen.
  test "ein tournament_cc zaehlt erst als dritte Stufe" do
    assert_equal :ba, classify(nil, ba_id: 4711, cc_present: true)
    assert_equal :club_cloud, classify(nil, ba_id: nil, cc_present: true)
  end

  test "ohne jede Spur meldet call :none, die Spalte bekommt :carambus" do
    assert_equal :none, classify(nil)
    assert_equal :carambus, Provenance::Classifier.source_kind_for(source_url: nil)
  end

  # Lieber eine sichtbare Luecke als ein falscher Wert: eine unbekannte Quelle ist eine Anomalie,
  # die im Backfill-Bericht auffallen soll.
  test "ein unbekanntes URL-Muster wird nicht geraten" do
    assert_nil classify("https://irgendwo.example.org/turniere/17")
    assert_nil Provenance::Classifier.source_kind_for(source_url: "https://irgendwo.example.org/x")
  end

  test "jeder gelieferte Enum-Wert existiert auch als Spaltenwert" do
    erlaubt = ProvenanceStamped::SOURCE_KINDS.keys
    Provenance::Classifier::SOURCE_PATTERNS.each_key do |kind|
      assert_includes erlaubt, kind, "#{kind} fehlt in ProvenanceStamped::SOURCE_KINDS"
    end
    assert_includes erlaubt, :ba
    assert_includes erlaubt, :carambus
  end
end
