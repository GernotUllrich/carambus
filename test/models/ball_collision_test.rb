# frozen_string_literal: true

require "test_helper"

# v0.10: Ball-Ball-Treffpunkte (Design-Doc 2026-04-25_shot_trajectory_design.md §6/§8).
# Jede Regel ist doppelt abgesichert — Modell-Validierung und Check-Constraint —,
# weil Seeds und das Trainingspaket auch an der Validierung vorbei schreiben koennen.
class BallCollisionTest < ActiveSupport::TestCase
  def shot
    @shot ||= begin
      example = TrainingExample.create!(title: "v0.10 Beispiel")
      example.shots.create!(shot_type: "ideal", sequence_number: 1, title: "Stoss", source_language: "de")
    end
  end

  def valid_attrs(**overrides)
    {shot: shot, sequence_number: 1, collision_type: "primary_impact", ball_attacker: "b1", ball_target: "b2"}
      .merge(overrides)
  end

  def assert_invalid(attribute, kind, **overrides)
    c = BallCollision.new(valid_attrs(**overrides))
    assert_not c.valid?, "#{overrides.inspect} sollte ungueltig sein"
    assert c.errors.of_kind?(attribute, kind), c.errors.details.inspect
  end

  def assert_db_rejects(**overrides)
    assert_raises(ActiveRecord::StatementInvalid) do
      BallCollision.new(valid_attrs(**overrides)).save!(validate: false)
    end
  end

  test "valid with shot, sequence, type, attacker and target" do
    c = BallCollision.new(valid_attrs)
    assert c.valid?, c.errors.full_messages.inspect
  end

  test "enums expose exactly the agreed values" do
    assert_equal %w[primary_impact secondary_impact carambolage], BallCollision.collision_types.keys
    assert_equal %w[b1 b2 b3], BallCollision.ball_attackers.keys
    assert_equal %w[b1 b2 b3], BallCollision.ball_targets.keys
  end

  test "unknown enum values raise" do
    assert_raises(ArgumentError) { BallCollision.new.collision_type = "klapper" }
    assert_raises(ArgumentError) { BallCollision.new.ball_attacker = "b4" }
  end

  test "required fields" do
    %i[shot collision_type ball_attacker ball_target sequence_number].each do |attr|
      c = BallCollision.new(valid_attrs(attr => nil))
      assert_not c.valid?, "#{attr} sollte Pflicht sein"
    end
  end

  test "sequence_number positive and unique per shot" do
    assert_invalid(:sequence_number, :greater_than, sequence_number: 0)
    BallCollision.create!(valid_attrs)
    assert_invalid(:sequence_number, :taken)
    assert_db_rejects(sequence_number: 0)
    assert_raises(ActiveRecord::RecordNotUnique) { BallCollision.new(valid_attrs).save!(validate: false) }
  end

  test "attacker must differ from target" do
    assert_invalid(:ball_target, :same_as_attacker, ball_target: "b1")
    assert_db_rejects(ball_target: "b1")
  end

  test "quantity_of_ball within 0..1" do
    assert BallCollision.new(valid_attrs(quantity_of_ball: 0.8)).valid?
    assert_invalid(:quantity_of_ball, :in, quantity_of_ball: 1.2)
    assert_db_rejects(quantity_of_ball: -0.1)
  end

  test "force and speed within 1..4" do
    assert BallCollision.new(valid_attrs(force: 4, speed: 1)).valid?
    assert_invalid(:force, :in, force: 5)
    assert_invalid(:speed, :in, speed: 0)
    assert_db_rejects(force: 0)
    assert_db_rejects(speed: 5)
  end

  test "effects within -3..3" do
    assert BallCollision.new(valid_attrs(effect_vertical: -3, effect_horizontal: 3)).valid?
    assert_invalid(:effect_vertical, :in, effect_vertical: 4)
    assert_invalid(:effect_horizontal, :in, effect_horizontal: -4)
    assert_db_rejects(effect_horizontal: -4)
  end

  test "scored only for carambolage" do
    assert BallCollision.new(valid_attrs(collision_type: "carambolage", ball_target: "b3", scored: false)).valid?
    assert_invalid(:scored, :only_for_carambolage, scored: true)
    assert_db_rejects(scored: false)
  end

  test "properties default to an empty object and keep caromball_raw" do
    c = BallCollision.create!(valid_attrs(properties: {"caromball_raw" => {"hit_percent" => 80}}))
    assert_equal({"caromball_raw" => {"hit_percent" => 80}}, c.reload.properties)
    assert_equal({}, BallCollision.create!(valid_attrs(sequence_number: 2)).reload.properties)
  end

  test "Shot has_many ball_collisions ordered and destroys them" do
    BallCollision.create!(valid_attrs(sequence_number: 3, collision_type: "carambolage", ball_target: "b3"))
    BallCollision.create!(valid_attrs)
    assert_equal [1, 3], shot.ball_collisions.map(&:sequence_number)

    assert_difference -> { BallCollision.count }, -2 do
      shot.destroy
    end
  end
end
