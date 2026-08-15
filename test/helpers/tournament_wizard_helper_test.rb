# frozen_string_literal: true

require "test_helper"

# Characterization-Test für die Rollen-/CC-Sichtbarkeits-Helfer des Wizards (Plan 32-06).
# Beweist: CC-Turniere (Region mit region_cc) zeigen beide Lebenszyklen unabhängig von der Rolle
# (Verhaltenserhalt), CC-lose Turniere splitten nach Instanz-Rolle (Region → Melde, Location → Spiel).
# Instanz-Rolle wird über ApplicationRecord.region_server?/.location_server? gestubbt (minitest/mock).
class TournamentWizardHelperTest < ActionView::TestCase
  tests TournamentWizardHelper

  # Leichtes Tournament-Double: die Helfer lesen ausschließlich #organizer.
  def tournament_with(organizer)
    Struct.new(:organizer).new(organizer)
  end

  setup do
    @cc_less_region = regions(:bbv) # keine region_cc → CC-los
    @cc_region = regions(:nbv)
    RegionCc.create!(region: @cc_region, context: "wizard-helper-test", cc_id: 999_001)
    @cc_region.reload
  end

  test "wizard_cc_less? = Region nicht in SHORTNAMES_CC" do
    assert wizard_cc_less?(tournament_with(@cc_less_region))
    assert_not wizard_cc_less?(tournament_with(@cc_region))
  end

  # Der Grund für die Umstellung von region_cc auf SHORTNAMES_CC (Vorab-Fix vor Phase 34):
  # eine migrierte Region (z.B. TBV, seit v0.4 LigaManager) trägt noch einen ALT-region_cc, ist aber
  # CC-los. Die alte Logik (region_cc.blank?) läge hier falsch und zeigte die CC-Setup-Leiste inkl.
  # Scoreboards auf dem Region Server — genau der Runbook-C2-Befund.
  test "migrierte Region mit Alt-region_cc, aber nicht in SHORTNAMES_CC → CC-los" do
    migrated = Region.create!(name: "Migriert", shortname: "TBV", country: @cc_region.country)
    RegionCc.create!(region: migrated, context: "alt-tbv", cc_id: 999_002)
    migrated.reload

    assert_not Region::SHORTNAMES_CC.include?(migrated.shortname), "Testvoraussetzung: TBV ∉ SHORTNAMES_CC"
    assert migrated.region_cc.present?, "Testvoraussetzung: Alt-region_cc vorhanden"

    t = tournament_with(migrated)
    assert wizard_cc_less?(t), "trotz Alt-region_cc CC-los, weil nicht in SHORTNAMES_CC"
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
    t = tournament_with(@cc_region)

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

  # Schritt 1 bleibt die einzige wirklich CC-spezifische Stelle: CC-los gibt es nichts zu laden,
  # die Meldeliste trifft per Sync von der Authority ein. Das Gate dafuer sitzt in der View.
  test "CC-los zeigt keinen ClubCloud-Ladeschritt" do
    t = tournament_with(@cc_less_region)

    assert_not wizard_region_uses_cc?(t)
  end
end
