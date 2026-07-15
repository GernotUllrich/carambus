# frozen_string_literal: true

require "test_helper"

module NuLiga
  class ComparisonTest < ActiveSupport::TestCase
    FakeClub = Struct.new(:cc_id, :ba_id, :name, :shortname)

    # --- Pure Helfer (DB-/HTTP-frei) ---

    test "normalize_name lowercases and strips Rechtsform/punctuation" do
      assert_equal "spc hof", Comparison.normalize_name("SPC Hof e.V.")
      assert_equal "billard club münchen", Comparison.normalize_name("Billard-Club  München GmbH")
    end

    test "normalize_key is space-insensitive" do
      assert_equal Comparison.normalize_key("Bezirksliga Oberfranken"),
        Comparison.normalize_key("Bezirks liga Oberfranken")
    end

    test "diff_maps reports matched, only_* and mismatches" do
      nu = {"a" => "Alpha", "b" => "Beta", "c" => "Gamma"}
      cb = {"a" => "Alpha", "b" => "Beta X", "d" => "Delta"}
      r = Comparison.diff_maps(nu, cb)
      assert_equal 2, r[:matched]                       # keys a, b
      assert_equal ["c — Gamma"], r[:only_nuliga]
      assert_equal ["d — Delta"], r[:only_carambus]
      assert_equal 1, r[:mismatches].size               # b: "Beta" ≠ "Beta X"
      assert_equal "b", r[:mismatches].first[:key]
    end

    # --- compare_clubs: VNr-primär + namensbasiert-Fallback (Logik isoliert) ---

    def build_comparison
      Comparison.new(federation: "BBV", region_id: 3, season_id: 17, scraper: Object.new)
    end

    test "compare_clubs matches by VNr first, then by name" do
      cmp = build_comparison
      def cmp.nuliga_clubs
        [{club_id: 383, name: "Snooker-Pool-Club Hof e.V.", vnr: 1743},
          {club_id: 999, name: "BC Namensverein e.V.", vnr: nil}]
      end

      def cmp.carambus_clubs
        [FakeClub.new(1743, 1743, "Snooker-Pool-Club Hof e.V.", "SPC Hof"),
          FakeClub.new(5000, 5000, "BC Namensverein e.V.", "BC NV")]
      end

      r = cmp.send(:compare_clubs)
      assert_equal 1, r[:matched_by_vnr]    # Hof über VNr 1743
      assert_equal 1, r[:matched_by_name]   # Namensverein über Name
      assert_equal 2, r[:matched]
      assert_empty r[:only_nuliga]
      assert_empty r[:only_carambus]
    end

    test "compare_clubs reports only_nuliga when neither VNr nor name matches" do
      cmp = build_comparison
      def cmp.nuliga_clubs
        [{club_id: 111, name: "Unbekannter BC", vnr: 8888}]
      end

      def cmp.carambus_clubs
        [FakeClub.new(1743, 1743, "Snooker-Pool-Club Hof e.V.", "SPC Hof")]
      end

      r = cmp.send(:compare_clubs)
      assert_equal 0, r[:matched]
      assert_equal ["8888 — Unbekannter BC"], r[:only_nuliga]
      assert_equal 1, r[:only_carambus].size
    end
  end
end
