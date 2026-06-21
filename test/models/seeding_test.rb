# frozen_string_literal: true

require "test_helper"

# Seeding#final_rank — erspielte End-Platzierung aus data["result"]["Gesamtrangliste"].
# Der Platzierungs-Key ist disziplinabhaengig: "Rang" (Karambol regional, dt.) |
# "Rank" (Snooker/Pool, engl.) | "#". Diese robuste Extraktion behebt u.a. den
# CC-Ranglisten-Upload fuer Karambol-Turniere (TournamentCc, importRangliste2), der
# vorher hart ["Rank"]/["#"] las → fuer Karambol nil → 0.
class SeedingTest < ActiveSupport::TestCase
  def seeding_with(gr: nil, rank: nil)
    data = gr ? {"result" => {"Gesamtrangliste" => gr}} : {}
    Seeding.new(data: data, rank: rank)
  end

  test "final_rank: Karambol-Key 'Rang' (deutsch)" do
    assert_equal 5, seeding_with(gr: {"Rang" => 5, "Punkte" => 38}).final_rank
  end

  test "final_rank: Snooker/Pool-Key 'Rank' (englisch)" do
    assert_equal 19, seeding_with(gr: {"Rank" => 19}).final_rank
  end

  test "final_rank: Fallback-Key '#' (String → Integer)" do
    assert_equal 2, seeding_with(gr: {"#" => "2"}).final_rank
  end

  test "final_rank: ohne Gesamtrangliste → Fallback auf DB-Spalte rank (Monitor-Turnier)" do
    assert_equal 3, seeding_with(rank: 3).final_rank
  end

  test "final_rank: keine Ergebnisdaten → nil (noch nicht gespielt)" do
    assert_nil seeding_with.final_rank
  end
end
