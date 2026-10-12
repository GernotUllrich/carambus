# frozen_string_literal: true

require "test_helper"

# Plan 03-01 (§4.4.2 NBV-Ordnung): TournamentMonitor.ranking mit BED/Höchstserie als
# Tiebreak-Stufen 3+4. TournamentMonitor.ranking ist ein reiner Klassenmethoden-Sortierer
# (Hash → sortiertes Array) — kein Tournament/TournamentMonitor-Fixture nötig.
class TournamentMonitorRankingTest < ActiveSupport::TestCase
  test "ranking with bed as tiebreaker: equal points and gd, higher bed wins" do
    hash = {
      "p1" => {"points" => 4, "gd" => 2.0, "bed" => 2.5, "hs" => 10},
      "p2" => {"points" => 4, "gd" => 2.0, "bed" => 3.0, "hs" => 10}
    }
    result = TournamentMonitor.ranking(hash, order: %i[points gd bed hs])
    assert_equal "p2", result.first[0],
      "Höheres BED muss bei gleichen Punkten und gleichem GD vorne stehen"
  end

  test "ranking with hs as tiebreaker: equal points, gd and bed, higher hs wins" do
    hash = {
      "p1" => {"points" => 4, "gd" => 2.0, "bed" => 2.5, "hs" => 8},
      "p2" => {"points" => 4, "gd" => 2.0, "bed" => 2.5, "hs" => 15}
    }
    result = TournamentMonitor.ranking(hash, order: %i[points gd bed hs])
    assert_equal "p2", result.first[0],
      "Höhere Höchstserie muss bei gleichen Punkten, GD und BED vorne stehen"
  end

  test "ranking still decides by points before bed/hs are ever consulted (regression)" do
    hash = {
      "p1" => {"points" => 4, "gd" => 1.0, "bed" => 5.0, "hs" => 50},
      "p2" => {"points" => 6, "gd" => 0.5, "bed" => 0.1, "hs" => 1}
    }
    result = TournamentMonitor.ranking(hash, order: %i[points gd bed hs])
    assert_equal "p2", result.first[0],
      "Mehr Punkte gewinnt weiterhin unabhängig von GD/BED/HS — bestehendes Verhalten"
  end

  test "ranking still decides by gd before bed/hs when points are equal (regression)" do
    hash = {
      "p1" => {"points" => 4, "gd" => 1.0, "bed" => 5.0, "hs" => 50},
      "p2" => {"points" => 4, "gd" => 2.0, "bed" => 0.1, "hs" => 1}
    }
    result = TournamentMonitor.ranking(hash, order: %i[points gd bed hs])
    assert_equal "p2", result.first[0],
      "Höheres GD gewinnt bei gleichen Punkten weiterhin unabhängig von BED/HS"
  end
end
