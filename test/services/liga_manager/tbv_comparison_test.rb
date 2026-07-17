# frozen_string_literal: true

require "test_helper"

module LigaManager
  # Unit-Tests der REINEN Matching-Logik (ohne DB/HTTP).
  class TbvComparisonTest < ActiveSupport::TestCase
    test "normalize_name strips legal form, punctuation and case" do
      assert_equal TbvComparison.normalize_name("1. PBC Erfurt"),
        TbvComparison.normalize_name("1. PBC Erfurt e.V.")
      assert_equal "bv werratal", TbvComparison.normalize_name("BV Werratal e.V.")
    end

    test "normalize_key is space-insensitive for German compounds" do
      assert_equal TbvComparison.normalize_key("Dreiband Oberliga - Staffel A"),
        TbvComparison.normalize_key("Dreibandoberliga Staffel A")
    end

    test "normalize_key keeps word order (genuine renames stay distinct)" do
      refute_equal TbvComparison.normalize_key("Mehrkampf Oberliga"),
        TbvComparison.normalize_key("Oberliga Mehrkampf")
    end

    test "diff_maps splits matched / only_lm / only_carambus" do
      lm = {1 => "A", 2 => "B", 3 => "C"}
      cb = {2 => "B", 3 => "C", 4 => "D"}
      diff = TbvComparison.diff_maps(lm, cb)

      assert_equal 2, diff[:matched]
      assert_equal ["1 — A"], diff[:only_lm]
      assert_equal ["4 — D"], diff[:only_carambus]
    end

    test "diff_maps flags a name mismatch on a shared key" do
      lm = {1562 => "1. BC BlackPool Eisenach e.V."}
      cb = {1562 => "Stock-Sport Eisenach e.V."}
      diff = TbvComparison.diff_maps(lm, cb)

      assert_equal 1, diff[:matched]
      assert_equal 1, diff[:mismatches].size
      assert_equal 1562, diff[:mismatches].first[:key]
    end
  end
end
