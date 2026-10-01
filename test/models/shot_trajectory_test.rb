# frozen_string_literal: true

require "test_helper"

# v0.10: Lauflinien (Design-Doc 2026-04-25_shot_trajectory_design.md §8 Punkt 1).
# Gespeicherte Linie hat Vorrang; sonst konstruiert Shot#trajectory_for sie aus
# Start -> Kollisionen/Events -> Ende.
class ShotTrajectoryTest < ActiveSupport::TestCase
  def config(b1, b2, b3)
    BallConfiguration.create!(b1_x: b1[0], b1_y: b1[1], b2_x: b2[0], b2_y: b2[1], b3_x: b3[0], b3_y: b3[1],
      table_variant: "match", gather_state: "pre_gather", position_type: "exact")
  end

  def start_config
    @start_config ||= config([0.1, 0.1], [0.3, 0.3], [0.9, 0.9])
  end

  def shot
    @shot ||= begin
      example = TrainingExample.create!(title: "Lauflinien-Beispiel")
      example.create_start_position!(ball_configuration: start_config, description_text: "Start")
      example.shots.create!(shot_type: "ideal", sequence_number: 1, title: "Stoss", source_language: "de",
        end_ball_configuration: config([0.8, 0.2], [0.4, 0.9], [0.9, 0.9]))
    end
  end

  # --- Validierung -----------------------------------------------------------

  test "trajectory_polylines defaults to an empty object" do
    assert_equal({}, shot.reload.trajectory_polylines)
  end

  test "accepts normalized polylines, single balls may be missing" do
    shot.trajectory_polylines = {"b1" => [[0.1, 0.1], [0.5, 0.0], [1, 1]], "b3" => []}
    assert shot.valid?, shot.errors.full_messages.inspect
  end

  test "rejects unknown balls" do
    shot.trajectory_polylines = {"b4" => [[0.1, 0.1]]}
    assert_not shot.valid?
    assert_match(/b4/, shot.errors[:trajectory_polylines].join)
  end

  test "rejects points outside 0..1, wrong arity and non-numbers" do
    [[[1.2, 0.5]], [[0.5]], [[0.5, 0.5, 0.5]], [["0.5", 0.5]], [{"x" => 0.5, "y" => 0.5}], "0.5,0.5"].each do |points|
      shot.trajectory_polylines = {"b1" => points}
      assert_not shot.valid?, "#{points.inspect} sollte ungueltig sein"
    end
  end

  test "rejects a non-object value" do
    shot.trajectory_polylines = [[0.1, 0.1]]
    assert_not shot.valid?
  end

  # --- Lauflinie --------------------------------------------------------------

  test "stored polyline wins over the fallback" do
    shot.update!(trajectory_polylines: {"b1" => [[0.1, 0.1], [0.5, 0.5]]})
    assert_equal [[0.1, 0.1], [0.5, 0.5]], shot.reload.trajectory_for(:b1)
  end

  test "fallback without collisions or events is start -> end" do
    assert_equal [[0.1, 0.1], [0.8, 0.2]], shot.trajectory_for("b1")
  end

  test "fallback orders attacker collisions after own events with lower numbers" do
    shot.ball_collisions.create!(sequence_number: 1, collision_type: "primary_impact", ball_attacker: "b1",
      ball_target: "b2", contact_coords_normalized: {"x" => 0.28, "y" => 0.28})
    shot.shot_events.create!(sequence_number: 2, event_type: "cushion_contact", ball_involved: "b1",
      cushion_involved: "long_near", contact_coords_normalized: [0.6, 0.0])
    shot.ball_collisions.create!(sequence_number: 3, collision_type: "carambolage", ball_attacker: "b1",
      ball_target: "b3", contact_coords_normalized: {"x" => 0.88, "y" => 0.88}, scored: true)

    assert_equal [[0.1, 0.1], [0.28, 0.28], [0.6, 0.0], [0.88, 0.88], [0.8, 0.2]],
      shot.reload.trajectory_for("b1")
  end

  test "fallback starts the target ball's line at the collision, then its own events" do
    shot.ball_collisions.create!(sequence_number: 1, collision_type: "primary_impact", ball_attacker: "b1",
      ball_target: "b2", contact_coords_normalized: {"x" => 0.28, "y" => 0.28})
    shot.shot_events.create!(sequence_number: 1, event_type: "cushion_contact", ball_involved: "b2",
      contact_coords_normalized: {"x" => 0.0, "y" => 0.6})

    assert_equal [[0.3, 0.3], [0.28, 0.28], [0.0, 0.6], [0.4, 0.9]], shot.reload.trajectory_for("b2")
  end

  test "fallback skips points without coordinates and missing configurations" do
    shot.ball_collisions.create!(sequence_number: 1, collision_type: "primary_impact", ball_attacker: "b1",
      ball_target: "b2")
    assert_equal [[0.1, 0.1], [0.8, 0.2]], shot.reload.trajectory_for("b1")

    shot.update!(end_ball_configuration: nil)
    assert_equal [[0.1, 0.1]], shot.reload.trajectory_for("b1")
  end

  test "point accepts both coordinate forms and rejects garbage" do
    assert_equal [0.2, 0.3], Shot.point({"x" => 0.2, "y" => 0.3})
    assert_equal [0.2, 0.3], Shot.point({x: 0.2, y: 0.3})
    assert_equal [0.2, 0.3], Shot.point([0.2, 0.3])
    assert_nil Shot.point(nil)
    assert_nil Shot.point({"x" => 0.2})
    assert_nil Shot.point([0.2])
  end
end
