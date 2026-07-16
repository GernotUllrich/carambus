# frozen_string_literal: true

require "test_helper"

module LigaManager
  # Unit-Tests der REINEN Begegnungs-/Ergebnis-Logik (ohne DB/HTTP).
  class ResultComparisonTest < ActiveSupport::TestCase
    test "normalize_team_name strips the discipline token (LM) to match Carambus" do
      assert_equal ResultComparison.normalize_team_name("Sparta Ilmenau 1"),
        ResultComparison.normalize_team_name("Sparta Ilmenau Dreiband 1")
      assert_equal "sparta ilmenau 1",
        ResultComparison.normalize_team_name("Sparta Ilmenau Dreiband 1")
    end

    test "compare_encounters splits matched / only_lm / only_carambus" do
      lm = {"d|a|b" => "2:4", "d|c|d" => "3:3"}
      cb = {"d|c|d" => "3:3", "d|e|f" => "1:5"}
      cmp = ResultComparison.compare_encounters(lm, cb)

      assert_equal 1, cmp[:matched]
      assert_equal ["d|a|b"], cmp[:only_lm]
      assert_equal ["d|e|f"], cmp[:only_carambus]
      assert_empty cmp[:result_mismatches]
    end

    test "compare_encounters flags a result mismatch on a shared encounter" do
      lm = {"d|a|b" => "2:4"}
      cb = {"d|a|b" => "3:3"}
      cmp = ResultComparison.compare_encounters(lm, cb)

      assert_equal 1, cmp[:matched]
      assert_equal 1, cmp[:result_mismatches].size
      assert_equal({key: "d|a|b", lm: "2:4", cb: "3:3"}, cmp[:result_mismatches].first)
    end
  end
end
