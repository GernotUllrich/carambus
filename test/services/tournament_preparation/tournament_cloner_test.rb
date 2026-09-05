# frozen_string_literal: true

require "test_helper"

module TournamentPreparation
  # Regression zur Klon-Welle vom August 2026: 36 NBV-Karambol-Turniere entstanden ohne
  # Turnierplan, weil tpid aus dem lokalen `tournament_plan_cc_id` (bei NBV durchweg 1)
  # statt aus der CC-ID gebildet wurde. Die ClubCloud verwarf die unbekannte ID still.
  # In der CC ist das nachträglich nicht korrigierbar — das Turnier muss neu angelegt
  # werden. Deshalb bricht der Klon lieber ab, als eine ungeprüfte tpid zu senden.
  class TournamentClonerTest < ActiveSupport::TestCase
    PlanDouble = Struct.new(:name, :context, :cc_id)
    TournamentCcDouble = Struct.new(:tournament_plan_cc)

    def cloner(opts: {})
      TournamentCloner.new(source_tournament: nil, opts: opts)
    end

    test "sendet die CC-ID des Turnierplans, nicht den lokalen Fremdschluessel" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", 1000))

      assert_equal 1000, cloner.send(:resolve_tpid, tc)
    end

    test "bricht ab, wenn der Turnierplan keine CC-ID hat" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", nil))

      error = assert_raises(RuntimeError) { cloner.send(:resolve_tpid, tc) }
      assert_match(/CC-ID/, error.message)
      assert_match(/CC: UNIVERSAL/, error.message)
    end

    test "bricht ab, wenn das Quell-Turnier gar keinen Turnierplan hat" do
      tc = TournamentCcDouble.new(nil)

      error = assert_raises(RuntimeError) { cloner.send(:resolve_tpid, tc) }
      assert_match(/keinen Turnierplan/, error.message)
    end

    test "bricht ab, wenn gar kein tournament_cc vorliegt" do
      assert_raises(RuntimeError) { cloner.send(:resolve_tpid, nil) }
    end

    test "opts tpid uebersteuert den Guard bewusst" do
      tc = TournamentCcDouble.new(PlanDouble.new("CC: UNIVERSAL", "nbv", nil))

      assert_equal 1234, cloner(opts: {tpid: 1234}).send(:resolve_tpid, tc)
    end
  end
end
