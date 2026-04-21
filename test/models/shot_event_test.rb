# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 2D: kinetic sub-events inside a Shot. Carries Contis „Sperre"
# (re_hit) and „Austausch" (position_handover) as typed event rows
# instead of free-form text. DE-only `notes` per Tier 2 scoping.
class ShotEventTest < ActiveSupport::TestCase
  def shot
    @shot ||= begin
      concept = TrainingConcept.create!(title: "Tier 2D Test", axis: "conception")
      example = concept.training_examples.create!(title: "Tier 2D Example")
      example.shots.create!(
        shot_type: "ideal",
        sequence_number: 1,
        title: "Konterspiel start",
        source_language: "de"
      )
    end
  end

  def valid_attrs(**overrides)
    {
      shot: shot,
      sequence_number: 1,
      event_type: "initial_contact"
    }.merge(overrides)
  end

  test "schema columns present" do
    %w[shot_id sequence_number event_type ball_involved cushion_involved
       contact_coords_normalized notes]
      .each { |col| assert_includes ShotEvent.column_names, col }
  end

  test "event_type enum exposes exactly six values" do
    assert_equal %w[initial_contact cushion_contact sperre austausch
                    final_carambolage near_miss],
                 ShotEvent.event_types.keys
  end

  test "ball_involved enum exposes b1, b2, b3" do
    assert_equal %w[b1 b2 b3], ShotEvent.ball_involveds.keys
  end

  test "cushion_involved enum exposes four cushions (mirrors BallConfiguration)" do
    assert_equal %w[short_left short_right long_near long_far],
                 ShotEvent.cushion_involveds.keys
  end

  test "valid with shot + sequence_number + event_type" do
    e = ShotEvent.new(valid_attrs)
    assert e.valid?, e.errors.full_messages.inspect
  end

  test "requires shot" do
    e = ShotEvent.new(sequence_number: 1, event_type: "initial_contact")
    assert_not e.valid?
    assert e.errors.of_kind?(:shot, :blank)
  end

  test "requires sequence_number" do
    e = ShotEvent.new(valid_attrs(sequence_number: nil))
    assert_not e.valid?
    assert e.errors.of_kind?(:sequence_number, :blank)
  end

  test "sequence_number must be a positive integer" do
    e = ShotEvent.new(valid_attrs(sequence_number: 0))
    assert_not e.valid?
    assert e.errors.of_kind?(:sequence_number, :greater_than)
  end

  test "sequence_number uniqueness per shot" do
    ShotEvent.create!(valid_attrs)
    dup = ShotEvent.new(valid_attrs)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:sequence_number, :taken)
  end

  test "different shots can share sequence_number" do
    ShotEvent.create!(valid_attrs)
    other_shot = shot.training_example.shots.create!(
      shot_type: "alternative", sequence_number: 2,
      title: "alt", source_language: "de"
    )
    alt = ShotEvent.new(valid_attrs(shot: other_shot))
    assert alt.valid?
  end

  test "assigning unknown event_type raises ArgumentError" do
    assert_raises(ArgumentError) do
      ShotEvent.new.event_type = "combustion"
    end
  end

  test "assigning unknown ball_involved raises ArgumentError" do
    assert_raises(ArgumentError) do
      ShotEvent.new.ball_involved = "b4"
    end
  end

  test "assigning unknown cushion_involved raises ArgumentError" do
    assert_raises(ArgumentError) do
      ShotEvent.new.cushion_involved = "diagonal"
    end
  end

  test "ball_involved and cushion_involved are optional" do
    e = ShotEvent.new(valid_attrs)
    assert_nil e.ball_involved
    assert_nil e.cushion_involved
    assert e.valid?
  end

  test "prefixed predicates work for event_type" do
    e = ShotEvent.new(valid_attrs(event_type: "sperre"))
    assert_predicate e, :event_sperre?
    assert_not e.event_austausch?
  end

  test "contact_coords_normalized accepts [x, y] array" do
    e = ShotEvent.create!(valid_attrs(contact_coords_normalized: [0.42, 0.17]))
    e.reload
    assert_equal [0.42, 0.17], e.contact_coords_normalized
  end

  test "Shot has_many :shot_events and destroys them on destroy" do
    ShotEvent.create!(valid_attrs)
    ShotEvent.create!(valid_attrs(sequence_number: 2, event_type: "cushion_contact"))
    assert_equal 2, shot.shot_events.count

    assert_difference -> { ShotEvent.count }, -2 do
      shot.destroy
    end
  end

  test "Shot#shot_events are returned ordered by sequence_number" do
    ShotEvent.create!(valid_attrs(sequence_number: 3, event_type: "final_carambolage"))
    ShotEvent.create!(valid_attrs(sequence_number: 1, event_type: "initial_contact"))
    ShotEvent.create!(valid_attrs(sequence_number: 2, event_type: "cushion_contact"))

    assert_equal [1, 2, 3], shot.shot_events.map(&:sequence_number)
  end
end
