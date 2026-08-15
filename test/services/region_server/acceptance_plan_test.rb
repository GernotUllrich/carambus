# frozen_string_literal: true

require "test_helper"

# Plan 35-02: Der universelle Karambol-Akzeptanzplan.
#
# Der wichtigste Test ist der letzte (AC-6): er prueft die KETTE Sender -> Empfaenger. Alles, was
# Setting.map_game_gname_to_cc_group_name erzeugen kann, muss hier akzeptiert werden — sonst
# koennte der Location Server ein Ergebnis melden, das der Region Server prinzipiell ablehnt.
class RegionServer::AcceptancePlanTest < ActiveSupport::TestCase
  # --- AC-3: ohne Turnierkontext bildbar --------------------------------------

  test "der Namensraum ist ohne Tournament und ohne TournamentPlan bildbar" do
    assert RegionServer::AcceptancePlan.accepts?("Gruppe A")
    assert RegionServer::AcceptancePlan.fixed_names.any?
  end

  test "der Namensraum deckt Gruppen, KO-Stufen, Runden und Platzierungen ab" do
    assert RegionServer::AcceptancePlan.accepts?("Gruppe A"), "Gruppen fehlen"
    assert RegionServer::AcceptancePlan.accepts?("Halbfinale"), "KO-Stufen fehlen"
    assert RegionServer::AcceptancePlan.accepts?("Hauptrunde"), "Runden fehlen"
    assert RegionServer::AcceptancePlan.accepts?("Spiel um Platz 3"), "Platzierungen fehlen"
  end

  # --- Gezaehlte Formen -------------------------------------------------------

  test "Gruppen werden bis Z akzeptiert" do
    assert RegionServer::AcceptancePlan.accepts?("Gruppe A")
    assert RegionServer::AcceptancePlan.accepts?("Gruppe H")
    assert RegionServer::AcceptancePlan.accepts?("Gruppe Z")
  end

  test "offene Zaehler werden nicht kuenstlich begrenzt" do
    assert RegionServer::AcceptancePlan.accepts?("Runde 1")
    assert RegionServer::AcceptancePlan.accepts?("Runde 12")
    assert RegionServer::AcceptancePlan.accepts?("Spiel um Platz 15")
    assert RegionServer::AcceptancePlan.accepts?("3. Gewinnerrunde")
    assert RegionServer::AcceptancePlan.accepts?("2. Verliererrunde")
  end

  # --- AC-5: Tippfehler-Schutz bleibt wirksam ---------------------------------

  test "Tippfehler und Unsinn werden abgewiesen" do
    refute RegionServer::AcceptancePlan.accepts?("Halbfinaie")
    refute RegionServer::AcceptancePlan.accepts?("Gruppe Z9")
    refute RegionServer::AcceptancePlan.accepts?("Voellig Unbekannt")
    refute RegionServer::AcceptancePlan.accepts?("Gruppe")
    refute RegionServer::AcceptancePlan.accepts?("Platz 3-4"), "das ist die Carambus-Normalform, nicht die Sender-Form"
  end

  test "leere Eingaben werden abgewiesen" do
    refute RegionServer::AcceptancePlan.accepts?(nil)
    refute RegionServer::AcceptancePlan.accepts?("")
    refute RegionServer::AcceptancePlan.accepts?("   ")
  end

  test "Leerraum am Rand ist unschaedlich" do
    assert RegionServer::AcceptancePlan.accepts?("  Finale  ")
  end

  # --- Plan 35-03: Auswahlliste (AC-3) ----------------------------------------

  # DIE ZENTRALE ZUSICHERUNG: Was das Formular anbietet, muss der Ingest annehmen. Andernfalls
  # koennte der LSW ein Ergebnis erfassen, das ueber die API nicht einlieferbar waere.
  test "jeder waehlbare Name wird auch akzeptiert" do
    rejected = RegionServer::AcceptancePlan.selectable_names.reject do |name|
      RegionServer::AcceptancePlan.accepts?(name)
    end

    assert_empty rejected, "waehlbar, aber nicht akzeptiert"
  end

  test "die Auswahlliste deckt die gebraeuchlichen Formen ab" do
    names = RegionServer::AcceptancePlan.selectable_names

    assert_includes names, "Gruppe A"
    assert_includes names, "Gruppe H"
    assert_includes names, "Halbfinale"
    assert_includes names, "Finale"
    assert_includes names, "Hauptrunde"
    assert_includes names, "Runde 1"
    assert_includes names, "Spiel um Platz 3"
  end

  test "die Auswahlliste ist eine Teilmenge des Akzeptierten, nicht deckungsgleich" do
    # Gruppe Z ist akzeptiert, aber bewusst nicht waehlbar — die Liste bleibt bedienbar.
    assert RegionServer::AcceptancePlan.accepts?("Gruppe Z")
    refute_includes RegionServer::AcceptancePlan.selectable_names, "Gruppe Z"
  end

  test "die Auswahlliste ist dublettenfrei" do
    names = RegionServer::AcceptancePlan.selectable_names

    assert_equal names.uniq.size, names.size
  end

  # --- AC-6: Konsistenz Sender -> Empfaenger -----------------------------------

  # Alle Spielnamen-Formen, die in ExecutorParams real vorkommen (Gruppen, KO-Stufen,
  # Doppel-KO-Runden, Platzierungsspiele) — plus die Formen, die der TableMonitor als gname
  # schreibt. Das ist die Eingabemenge der Senderseite.
  SENDER_INPUTS = [
    # Gruppen (table_populator.rb:735 schreibt "group<n>:<a>-<b>", ExecutorParams fuehren "g<n>")
    "group1:1-2", "group2:3-4", "group6:1-2", "group7:1-2", "group8:1-2", "group26:1-2",
    "group1:2-3/2",
    # KO-Stufen (ExecutorParams-Keys, direkt als gname uebernommen — table_populator.rb:382)
    "hf1", "hf2", "fin",
    "qf1", "qf2", "qf3", "qf4",
    "vf1", "vf2",
    "8f1", "8f8", "af1",
    "16f1", "32f1", "64f1",
    # Doppel-KO
    "w1.1", "w2.3", "l1.1", "l3.7",
    # Platzierungsspiele
    "p<3-4>", "p<5-6>", "p<7-8>", "p<9-10>", "p<11-12>", "p<13-14>", "p<15-16>",
    "p<3..4>"
  ].freeze

  test "jeder Name, den der Sender erzeugen kann, wird akzeptiert" do
    unmapped = []
    rejected = []

    SENDER_INPUTS.each do |gname|
      simplified = Setting.map_game_gname_to_cc_group_name(gname)

      if simplified.nil?
        unmapped << gname
        next
      end

      rejected << "#{gname} -> #{simplified}" unless RegionServer::AcceptancePlan.accepts?(simplified)
    end

    assert_empty unmapped,
      "Diese Spielnamen sind nicht abbildbar — der Sender wuerde sie stillschweigend verschlucken"
    assert_empty rejected,
      "Diese Namen erzeugt der Sender, der Empfaenger lehnt sie aber ab"
  end
end
