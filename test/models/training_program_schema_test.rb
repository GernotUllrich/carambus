# frozen_string_literal: true

require "test_helper"

# Trainingsprogramme (Handoff Claudia 2026-10-02, Pilot Weingartner-Pflichtstossprogramm):
# Wertpunkte, Contre-Kennzeichen und Reihenfolge am TrainingExample-Baum, dazu der
# zone_type diamond_field. Jede Regel gegen Modell UND DB-Check.
class TrainingProgramSchemaTest < ActiveSupport::TestCase
  def program
    @program ||= TrainingExample.create!(title: "Pflichtstossprogramm")
  end

  def group(number = 2)
    TrainingExample.create!(title: "Gruppe #{number}", parent: program, sequence_number: number)
  end

  def assert_db_rejects(sql_set)
    figure = TrainingExample.create!(title: "Figur", parent: program)
    assert_raises(ActiveRecord::StatementInvalid) do
      TrainingExample.where(id: figure.id).update_all(sql_set)
    end
  end

  # --- points / contre_allowed -------------------------------------------------

  test "figure carries points and contre flag; group and program leave them nil" do
    grp = group
    figure = TrainingExample.create!(title: "Figur 5", parent: grp, sequence_number: 1,
      points: 7, contre_allowed: true)

    assert_equal [7, true], figure.reload.values_at(:points, :contre_allowed)
    assert_nil grp.points
    assert_nil program.contre_allowed, "nil heisst: Quelle sagt nichts"
  end

  test "points must be a positive integer" do
    [0, -3, 2.5].each do |value|
      ex = TrainingExample.new(title: "Figur", points: value)
      assert_not ex.valid?, "points=#{value} sollte ungueltig sein"
    end
    assert_db_rejects(points: 0)
  end

  # --- sequence_number ---------------------------------------------------------

  test "sequence_number must be a positive integer" do
    ex = TrainingExample.new(title: "Gruppe", parent: program, sequence_number: 0)
    assert_not ex.valid?
    assert ex.errors.of_kind?(:sequence_number, :greater_than)
    assert_db_rejects(sequence_number: 0)
  end

  test "sequence_number unique under the same parent" do
    group(2)
    dup = TrainingExample.new(title: "noch eine Gruppe 2", parent: program, sequence_number: 2)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:sequence_number, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { dup.save!(validate: false) }
  end

  test "same sequence_number under different parents is allowed" do
    figure_a = TrainingExample.create!(title: "Figur 1 in II", parent: group(2), sequence_number: 1)
    figure_b = TrainingExample.new(title: "Figur 1 in III", parent: group(3), sequence_number: 1)
    assert figure_b.valid?, figure_b.errors.full_messages.inspect
    assert_nothing_raised { figure_b.save! }
    assert_equal 1, figure_a.sequence_number
  end

  test "several children without sequence_number are allowed" do
    TrainingExample.create!(title: "Variante a", parent: program)
    assert_nothing_raised { TrainingExample.create!(title: "Variante b", parent: program) }
  end

  test "children are reachable in program order" do
    group(3)
    group(1)
    group(2)
    assert_equal [1, 2, 3], program.children.order(:sequence_number).map(&:sequence_number)
  end

  # --- diamond_field -----------------------------------------------------------

  test "zone_type diamond_field accepted by enum and DB" do
    assert_includes TableZone.zone_types.keys, "diamond_field"
    zone = TableZone.create!(key: "diamond_field_x3_y1", label: "Diamantfeld x3/y1", zone_type: "diamond_field",
      polygon_normalized: [[0.375, 0.25], [0.5, 0.25], [0.5, 0.5], [0.375, 0.5]])
    assert zone.reload.zone_diamond_field?
  end

  test "DB still rejects unknown zone types" do
    zone = TableZone.create!(key: "pkg_check_zone", label: "Check", zone_type: "custom")
    assert_raises(ActiveRecord::StatementInvalid) do
      TableZone.where(id: zone.id).update_all(zone_type: "diamond")
    end
  end
end
