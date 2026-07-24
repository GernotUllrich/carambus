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

  test "wizard_cc_less? = Region ohne region_cc" do
    assert wizard_cc_less?(tournament_with(@cc_less_region))
    assert_not wizard_cc_less?(tournament_with(@cc_region))
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

  test "AC-2: CC-los auf Location Server → Spiel-Zyklus an, Melde-Zyklus aus" do
    t = tournament_with(@cc_less_region)

    ApplicationRecord.stub(:region_server?, false) do
      ApplicationRecord.stub(:location_server?, true) do
        assert_not wizard_show_melde_cycle?(t)
        assert wizard_show_game_cycle?(t)
      end
    end
  end
end
