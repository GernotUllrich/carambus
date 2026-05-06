# frozen_string_literal: true

require "test_helper"

# Phase 39 (DTP-backed parameter ranges) — Konstanten- und Signaturvertrag.
#
# Diese Datei pinnt drei strukturelle Aussagen aus Plan 39-02, die bisher nur
# durch statisches Grep + Plan-Acceptance-Criteria geprüft waren:
#
#   GAP-1: TournamentsController::UI_07_FIELDS == %i[balls_goal innings_goal]
#          (frozen). Plan 02 D-12 hat 5 Operator-Eingabe-Felder entfernt
#          (timeout, time_out_warm_up_first_min, time_out_warm_up_follow_up_min,
#          sets_to_play, sets_to_win) — ein Re-Add muss diesen Test fail-en.
#
#   GAP-2: TournamentsController::UI_07_SENTINEL_VALUES darf NICHT existieren.
#          Plan 02 D-13 hat die Konstante als toten Code gelöscht (UI_07_FIELDS
#          enthält nach D-12 keine Felder mehr, deren Sentinels jemals greifen
#          könnten). Eine Wiedereinführung muss diesen Test fail-en.
#
#   GAP-3: Discipline#parameter_ranges hat genau einen required keyword arg
#          :tournament. Plan 01 D-01 hat die alte no-arg / positionale Signatur
#          ersetzt. Ein Revert auf no-arg oder positional muss fail-en.
#
# Technical notes:
#   - ActiveSupport::TestCase reicht — kein HTTP, keine Fixtures, keine DB.
#   - Method#parameters liefert [[:keyreq, :tournament]] für `def m(tournament:)`.
#   - const_defined?(name, false) verhindert Vererbungs-Lookup; für Konstanten
#     direkt am Controller-Singleton ist das hier zwingend, sonst würde z.B.
#     eine zufällig im Object-Namespace definierte Konstante false-positive geben.
class Phase39ConstantsContractTest < ActiveSupport::TestCase
  # GAP-1: UI_07_FIELDS Inhalt + Reihenfolge + frozen.
  test "TournamentsController::UI_07_FIELDS equals exactly %i[balls_goal innings_goal] and is frozen" do
    assert TournamentsController.const_defined?(:UI_07_FIELDS, false),
      "UI_07_FIELDS must be defined directly on TournamentsController (Phase 39 D-12)"

    fields = TournamentsController::UI_07_FIELDS

    assert_equal %i[balls_goal innings_goal], fields,
      "Phase 39 D-12: UI_07_FIELDS must be exactly [:balls_goal, :innings_goal]. " \
      "If timeout / time_out_warm_up_* / sets_to_* re-appear, the verification modal " \
      "would fire on operator-input fields again — that path was deliberately removed."

    assert_predicate fields, :frozen?,
      "UI_07_FIELDS must be frozen (mutable constants are a foot-gun)"
  end

  # GAP-2: UI_07_SENTINEL_VALUES darf NICHT existieren.
  test "TournamentsController must NOT define UI_07_SENTINEL_VALUES (Phase 39 D-13)" do
    refute TournamentsController.const_defined?(:UI_07_SENTINEL_VALUES, false),
      "Phase 39 D-13: UI_07_SENTINEL_VALUES was deleted as dead code. " \
      "After D-12 narrowed UI_07_FIELDS to [:balls_goal, :innings_goal], the sentinel " \
      "exemption logic is unreachable. Re-introducing the constant resurrects 13 LOC of " \
      "dead branching plus the deleted `next if (UI_07_SENTINEL_VALUES[field] || []).include?(value)` " \
      "guard line in #verify_tournament_start_parameters."
  end

  # GAP-3: Signatur — required keyword arg :tournament.
  test "Discipline#parameter_ranges has signature parameter_ranges(tournament:) — one required keyword arg" do
    params = Discipline.instance_method(:parameter_ranges).parameters

    assert_equal [[:keyreq, :tournament]], params,
      "Phase 39 D-01: Discipline#parameter_ranges must take exactly one required keyword arg :tournament. " \
      "Got #{params.inspect}. A revert to no-arg ([]) or positional ([[:req, :tournament]]) " \
      "would silently break the controller call site (tournaments_controller.rb#verify_tournament_start_parameters) " \
      "with ArgumentError at runtime."
  end
end
