# frozen_string_literal: true

require "test_helper"

# Plan 39-02 Task 1 (D-39-2): reine Credential-Auswahl-Naht `resolve_login_credentials`.
# Testet NUR die Credential-Quelle (testbar ohne Net::HTTP) — der MD5/checkUser.php-Login-Flow
# in login_to_cc bleibt unberuehrt und wird hier nicht angefasst.
class SettingTest < ActiveSupport::TestCase
  SENTINEL = {username: "region-admin", password: "region-pw"}.freeze

  test "resolve_login_credentials nutzt explizite Override-Creds 1:1 ohne get_cc_credentials zu befragen" do
    Setting.stub(:get_cc_credentials, ->(_ctx) { flunk("get_cc_credentials darf bei vollstaendigem Override NICHT aufgerufen werden") }) do
      result = Setting.resolve_login_credentials("nbv", username: "user@example.com", password: "secret")
      assert_equal({username: "user@example.com", password: "secret"}, result)
    end
  end

  test "resolve_login_credentials faellt ohne Override auf get_cc_credentials zurueck (Region-Admin)" do
    Setting.stub(:get_cc_credentials, ->(ctx) { SENTINEL.merge(context: ctx) }) do
      result = Setting.resolve_login_credentials("nbv")
      assert_equal SENTINEL.merge(context: "nbv"), result
    end
  end

  test "resolve_login_credentials faellt bei nur teilweisem Override (nur username) auf get_cc_credentials zurueck" do
    Setting.stub(:get_cc_credentials, ->(_ctx) { SENTINEL }) do
      result = Setting.resolve_login_credentials("nbv", username: "user@example.com", password: nil)
      assert_equal SENTINEL, result
    end
  end

  # ===========================================================================
  # Plan 35-02: map_game_gname_to_cc_group_name
  #
  # CHARACTERIZATION — die Methode war bis hierher voellig ungetestet, hat aber SIEBEN Aufrufer,
  # davon fuenf im CC-Pfad (find_group_item_id_from_gname, CC-Upload, validate_game_gname_mapping,
  # CC-CSV, GameResultReporter). Diese Tests halten das Bestandsverhalten fest, damit die
  # Erweiterung um die KO-Formen den produktiven CC-Weg nicht still veraendert.
  # ===========================================================================

  def mapped(gname)
    Setting.map_game_gname_to_cc_group_name(gname)
  end

  # --- Bestand: Gruppen -------------------------------------------------------

  test "Gruppen werden aus der gname-Form auf CC-Buchstaben abgebildet" do
    assert_equal "Gruppe A", mapped("group1:1-2")
    assert_equal "Gruppe B", mapped("group2:3-4")
    assert_equal "Gruppe C", mapped("group3:1-2")
    assert_equal "Gruppe D", mapped("group4:1-2")
    assert_equal "Gruppe E", mapped("group5:1-2")
    assert_equal "Gruppe F", mapped("group6:1-2")
  end

  test "Gruppen werden auch aus der Klartext-Form abgebildet" do
    assert_equal "Gruppe A", mapped("Gruppe 1")
    assert_equal "Gruppe B", mapped("Gruppe 2")
    assert_equal "Gruppe C", mapped("Gruppe 3")
  end

  test "Gruppen mit Wiederholungszaehler bleiben abbildbar" do
    assert_equal "Gruppe A", mapped("group1:2-3/2")
  end

  # --- Bestand: KO und Platzierung --------------------------------------------

  test "beide Halbfinals bilden auf denselben Namen ab (viele-zu-eins)" do
    assert_equal "Halbfinale", mapped("hf1")
    assert_equal "Halbfinale", mapped("hf2")
  end

  test "Finale wird abgebildet" do
    assert_equal "Finale", mapped("fin")
    assert_equal "Finale", mapped("Finale")
    assert_equal "Finale", mapped("Endspiel")
  end

  test "Platzierungsspiele werden auf den niedrigeren Platz abgebildet" do
    assert_equal "Spiel um Platz 3", mapped("p<3-4>")
    assert_equal "Spiel um Platz 5", mapped("p<5-6>")
    assert_equal "Spiel um Platz 7", mapped("p<7-8>")
    assert_equal "Spiel um Platz 9", mapped("p<9-10>")
    assert_equal "Spiel um Platz 11", mapped("p<11-12>")
    assert_equal "Spiel um Platz 13", mapped("p<13-14>")
  end

  test "Platzierungsspiele auch in der Klartext-Form" do
    assert_equal "Spiel um Platz 3", mapped("Platz 3-4")
    assert_equal "Spiel um Platz 5", mapped("Platz 5/6")
  end

  test "dynamische Platzierungsextraktion greift ueber die Direkttabelle hinaus" do
    assert_equal "Spiel um Platz 15", mapped("p<15-16>")
    assert_equal "Spiel um Platz 17", mapped("Platz 17-18")
  end

  # --- Bestand: Randfaelle ----------------------------------------------------

  test "leere Eingaben liefern nil" do
    assert_nil mapped(nil)
    assert_nil mapped("")
  end

  test "unbekannte Namen liefern nil" do
    assert_nil mapped("Voellig Unbekannt")
  end

  test "Leerraum wird abgeschnitten" do
    assert_equal "Halbfinale", mapped("  hf1  ")
  end

  # --- Plan 35-02: KO-Stufen (AC-1) -------------------------------------------

  test "Viertelfinale wird aus beiden Kuerzeln abgebildet" do
    assert_equal "Viertelfinale", mapped("qf1")
    assert_equal "Viertelfinale", mapped("qf4")
    assert_equal "Viertelfinale", mapped("vf2")
    assert_equal "Viertelfinale", mapped("Viertelfinale")
  end

  test "Achtelfinale wird aus beiden Kuerzeln abgebildet" do
    assert_equal "Achtelfinale", mapped("8f1")
    assert_equal "Achtelfinale", mapped("af3")
    assert_equal "Achtelfinale", mapped("Achtelfinale")
  end

  test "tiefere KO-Stufen folgen der Repo-Konvention aus RANKING_KEY_PATTERNS" do
    assert_equal "1/16 Finale", mapped("16f1")
    assert_equal "1/32 Finale", mapped("32f5")
    assert_equal "1/64 Finale", mapped("64f12")
  end

  test "KO-Stufen bilden viele-zu-eins ab wie die Halbfinals" do
    assert_equal mapped("qf1"), mapped("qf2")
    assert_equal mapped("8f1"), mapped("8f4")
  end

  test "Doppel-KO-Runden tragen die Rundennummer, nicht die Partie" do
    assert_equal "1. Gewinnerrunde", mapped("w1.1")
    assert_equal "1. Gewinnerrunde", mapped("w1.3")
    assert_equal "2. Verliererrunde", mapped("l2.1")
    assert_equal "3. Verliererrunde", mapped("l3.7")
  end

  # --- Plan 35-02: Gruppen jenseits F (AC-2) ----------------------------------

  test "Gruppen ueber F hinaus werden abgebildet" do
    assert_equal "Gruppe G", mapped("group7:1-2")
    assert_equal "Gruppe H", mapped("group8:1-2")
  end

  test "Gruppen ueber F hinaus auch in der Klartext-Schreibweise" do
    assert_equal "Gruppe G", mapped("Gruppe 7")
    assert_equal "Gruppe H", mapped("Gruppe 8")
  end

  test "die Buchstabengrenze bleibt bei Z" do
    assert_equal "Gruppe Z", mapped("group26:1-2")
    assert_nil mapped("group27:1-2")
  end

  # --- Plan 35-02: Platzierung in Doppelpunkt-Notation ------------------------

  test "Platzierungsspiele in der Doppelpunkt-Notation werden abgebildet" do
    assert_equal "Spiel um Platz 3", mapped("p<3..4>")
    assert_equal "Spiel um Platz 9", mapped("p<9..12>")
  end

  # --- Plan 35-02: Abgrenzung -------------------------------------------------

  test "CC-Namen sind keine gueltige Eingabe und bleiben nil" do
    # Die Methode uebersetzt gname -> CC-Name, nicht CC-Name -> CC-Name. "Gruppe A" hat keine
    # Ziffer und faellt deshalb durch — das ist gewollt und darf sich nicht aendern, sonst wuerde
    # der Ingest doppelt uebersetzte Namen akzeptieren.
    assert_nil mapped("Gruppe A")
  end
end
