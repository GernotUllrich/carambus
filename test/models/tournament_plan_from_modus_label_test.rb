# frozen_string_literal: true

require "test_helper"

# TournamentPlan.from_modus_label — loest das Modus-Label einer Turniereinladung zum Plan auf.
#
# Hintergrund: Die ClubCloud schreibt einstellige Modi OHNE fuehrende Null ("T7 - Jeder gegen
# jeden"), die TournamentPlans heissen aber T01..T29. Der vorherige exakte Namensvergleich
# fand bei T1-T9 deshalb nichts; der Vorschlag im Turnier-Assistenten blieb still leer.
# Zweistellige Modi (T18, T21) waren nie betroffen — deshalb fiel es lange nicht auf.
class TournamentPlanFromModusLabelTest < ActiveSupport::TestCase
  setup do
    # Die Fixtures liefern T04 und T06; fuer die Namensaufloesung zaehlt nur der Name.
    @t04 = tournament_plans(:t04_5)
    @t06 = tournament_plans(:t06_6)
  end

  test "einstelliger Modus der ClubCloud findet den Plan mit fuehrender Null" do
    assert_equal @t04, TournamentPlan.from_modus_label("T4 - Jeder gegen jeden")
  end

  test "bereits zweistellige Schreibweise funktioniert unveraendert" do
    assert_equal @t06, TournamentPlan.from_modus_label("T06 - Jeder gegen jeden")
  end

  test "fuehrende Null im Label aendert nichts" do
    assert_equal @t04, TournamentPlan.from_modus_label("T04 - Jeder gegen jeden")
  end

  test "T0 und T00 bedeuten: Turnier findet nicht statt" do
    assert_nil TournamentPlan.from_modus_label("T0")
    assert_nil TournamentPlan.from_modus_label("T00 - faellt aus")
  end

  test "leeres oder unpassendes Label ergibt keinen Plan" do
    assert_nil TournamentPlan.from_modus_label(nil)
    assert_nil TournamentPlan.from_modus_label("")
    assert_nil TournamentPlan.from_modus_label("Jeder gegen jeden")
  end

  test "ein nicht existierender Modus ergibt keinen Plan statt eines Fehlers" do
    assert_nil TournamentPlan.from_modus_label("T99 - gibt es nicht")
  end
end
