# frozen_string_literal: true

require "test_helper"

# Characterization-Test für die Rollen-/CC-Sichtbarkeits-Helfer des Wizards (Plan 32-06).
# Beweist: CC-Turniere (Region mit region_cc) zeigen beide Lebenszyklen unabhängig von der Rolle
# (Verhaltenserhalt), CC-lose Turniere splitten nach Instanz-Rolle (Region → Melde, Location → Spiel).
# Instanz-Rolle wird über ApplicationRecord.region_server?/.location_server? gestubbt (minitest/mock).
class TournamentWizardHelperTest < ActionView::TestCase
  tests TournamentWizardHelper

  # ECHTE Records statt eines `Struct.new(:organizer)`-Doubles (Plan 34-02, Task 1): ab 34-02 liest
  # der Wizard nicht mehr nur #organizer, sondern die Provenienz am Turnier selbst. Ein Double
  # koennte das nicht abbilden und wuerde die Umstellung an genau der Stelle blind machen, an der
  # sie geprueft gehoert. Inhaltlich aendert sich hier nichts — die Erwartungen bleiben, wie sie waren.
  def tournament_with(organizer, **attrs)
    Tournament.create!(
      {title: "T#{SecureRandom.hex(3)}", shortname: "S#{SecureRandom.hex(3)}",
       season: seasons(:current), organizer: organizer,
       date: Time.zone.local(2026, 10, 10, 10, 0)}.merge(attrs)
    )
  end

  # Eine aus der ClubCloud gescrapte Turnier-URL. Seit 34-02 macht ERST SIE ein Turnier zu einem
  # CC-Turnier — vorher genuegte die Zugehoerigkeit zu einer CC-Region.
  CC_URL = "https://ndbv.de/sb_meisterschaft.php?p=20--2026/2027-46-"

  setup do
    @cc_less_region = regions(:bbv) # keine region_cc → CC-los
    @cc_region = regions(:nbv)
    RegionCc.create!(region: @cc_region, context: "wizard-helper-test", cc_id: 999_001)
    @cc_region.reload
  end

  # Ein Turnier, das wirklich aus der ClubCloud stammt.
  def cc_tournament(organizer = @cc_region)
    tournament_with(organizer, source_url: CC_URL)
  end

  test "wizard_cc_less? = das Turnier stammt nicht aus der ClubCloud" do
    assert wizard_cc_less?(tournament_with(@cc_less_region))
    assert_not wizard_cc_less?(cc_tournament)
  end

  # DIE EINE BEABSICHTIGTE VERHALTENSAENDERUNG (Plan 34-02, AC-4).
  #
  # Vorher entschied die REGION: ein Turnier in NBV galt als CC-Turnier, egal woher es kam. Jetzt
  # entscheidet die Herkunft des Turniers selbst. Ein lokal angelegtes Turnier hat keinen
  # `tournament_cc` — Schritt 1 "Meldeliste von ClubCloud laden" koennte dort ohnehin nichts laden.
  # Die Regionszugehoerigkeit war nie eine Aussage ueber DIESES Turnier.
  test "AC-4: lokal angelegtes Turnier in einer CC-Region gilt als CC-los" do
    t = tournament_with(@cc_region) # keine source_url → source_kind :carambus

    assert_equal "carambus", t.source_kind, "Testvoraussetzung: lokal angelegt"
    assert wizard_cc_less?(t), "kein CC-Zwilling → CC-los, anders als vor 34-02"
    assert_not wizard_region_uses_cc?(t), "kein ClubCloud-Ladeschritt"
  end

  # Der urspruengliche Runbook-C2-Befund: eine migrierte Region (TBV, seit v0.4 LigaManager) traegt
  # noch einen ALT-`region_cc`, ist aber CC-los. Die damalige Logik (`region_cc.blank?`) zeigte dort
  # faelschlich die CC-Setup-Leiste inklusive Scoreboards auf dem Region Server.
  #
  # DIE BEGRUENDUNG HAT SICH ZWEIMAL VERSCHOBEN, das Ergebnis nicht: erst entschied `SHORTNAMES_CC`
  # (Vorab-Fix), dann `source_kind` mit `SHORTNAMES_CC` als Fallback (34-02) — und seit 34-03
  # entscheidet **allein** `source_kind`. Der Test bleibt deshalb gueltig, prueft jetzt aber die
  # Herkunft des TURNIERS; die `SHORTNAMES_CC`-Assertion steht nur noch als Testvoraussetzung da,
  # nicht mehr als wirkende Ursache.
  test "migrierte Region mit Alt-region_cc → CC-los, weil das TURNIER nicht aus einer CC stammt" do
    migrated = Region.create!(name: "Migriert", shortname: "TBV", country: @cc_region.country)
    RegionCc.create!(region: migrated, context: "alt-tbv", cc_id: 999_002)
    migrated.reload

    assert_not Region::SHORTNAMES_CC.include?(migrated.shortname), "Testvoraussetzung: TBV ∉ SHORTNAMES_CC"
    assert migrated.region_cc.present?, "Testvoraussetzung: Alt-region_cc vorhanden"

    t = tournament_with(migrated)
    assert_equal "carambus", t.source_kind, "die wirkende Ursache: die Herkunft des Turniers"
    assert wizard_cc_less?(t), "trotz Alt-region_cc CC-los, weil das Turnier nicht aus einer CC stammt"
    assert_not wizard_region_uses_cc?(t), "kein CC-Meldelisten-Schritt"

    ApplicationRecord.stub(:region_server?, true) do
      ApplicationRecord.stub(:location_server?, false) do
        assert wizard_show_melde_cycle?(t)
        assert_not wizard_show_game_cycle?(t),
          "auf dem Region Server kein Spiel-Zyklus (Modus/Start/Scoreboard)"
      end
    end
  end

  test "AC-1: CC-Turnier zeigt beide Zyklen, Rolle egal (Verhaltenserhalt)" do
    t = cc_tournament

    ApplicationRecord.stub(:region_server?, false) do
      ApplicationRecord.stub(:location_server?, false) do
        assert wizard_show_melde_cycle?(t)
        assert wizard_show_game_cycle?(t)
      end
    end

    ApplicationRecord.stub(:region_server?, true) do
      ApplicationRecord.stub(:location_server?, false) do
        assert wizard_show_melde_cycle?(t)
        assert wizard_show_game_cycle?(t)
      end
    end
  end

  test "AC-2: CC-los auf Region Server → Melde-Zyklus an, Spiel-Zyklus aus" do
    t = tournament_with(@cc_less_region)

    ApplicationRecord.stub(:region_server?, true) do
      ApplicationRecord.stub(:location_server?, false) do
        assert wizard_show_melde_cycle?(t)
        assert_not wizard_show_game_cycle?(t)
      end
    end
  end

  # REVIDIERT 2026-08-05 (Betreiber): Frueher hiess dieses AC "Melde-Zyklus aus". Das war falsch —
  # die Arbeit des Turnierleiters am Spielort ist im CC-losen Fall dieselbe wie im CC-Fall, nur die
  # Quelle der Meldeliste ist eine andere (Region Server statt ClubCloud). Der Melde-Zyklus gehoert
  # deshalb auf JEDEN Location Server; live aufgefallen auf ebc, wo Schritt 2 und 3 fehlten.
  test "CC-los auf Location Server → beide Zyklen (wie im CC-Fall)" do
    t = tournament_with(@cc_less_region)

    ApplicationRecord.stub(:region_server?, false) do
      ApplicationRecord.stub(:location_server?, true) do
        assert wizard_show_melde_cycle?(t),
          "der Turnierleiter am Spielort braucht Meldeliste-Uebernahme und Teilnehmerliste"
        assert wizard_show_game_cycle?(t)
      end
    end
  end

  # CHARACTERIZATION (Plan 34-02, Task 1): Ein Turnier, das ein VEREIN ausrichtet, ist weder CC noch
  # CC-los im Sinne des Wizards — es bekommt die volle Leiste. Beide Helfer haengen an
  # `organizer.is_a?(Region)`, und genau diese Klammer ist beim Umbau auf `source_kind` leicht zu
  # verlieren: ein Vereinsturnier traegt naemlich `source_kind :carambus` und saehe damit CC-los aus.
  test "Verein als Ausrichter: weder CC-los noch CC-Ladeschritt" do
    t = tournament_with(clubs(:bcw))

    assert_not wizard_cc_less?(t), "Vereinsturniere behalten die volle Leiste"
    assert_not wizard_region_uses_cc?(t), "und trotzdem keinen ClubCloud-Ladeschritt"
  end

  # Schritt 1 bleibt die einzige wirklich CC-spezifische Stelle: CC-los gibt es nichts zu laden,
  # die Meldeliste trifft per Sync von der Authority ein. Das Gate dafuer sitzt in der View.
  test "CC-los zeigt keinen ClubCloud-Ladeschritt" do
    t = tournament_with(@cc_less_region)

    assert_not wizard_region_uses_cc?(t)
  end
end
