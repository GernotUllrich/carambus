# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 2: first-class Principle entity. Holds measurable dimensions
# (dominance, margin_of_error, risk_factor), strategic maxims (the_dam,
# security_primacy, follow_over_point), and phenomenological observations
# (mystery_of_close_balls).
class PrincipleTest < ActiveSupport::TestCase
  def valid_attrs(**overrides)
    {
      key: "dominance",
      label: "Dominanz",
      principle_type: "measurable_dimension"
    }.merge(overrides)
  end

  test "schema columns present" do
    %w[key label principle_type description gretillat_ref weingartner_ref importance_order]
      .each { |col| assert_includes Principle.column_names, col }
  end

  test "principle_type enum exposes exactly three values" do
    assert_equal %w[strategic_maxim measurable_dimension phenomenological],
                 Principle.principle_types.keys
  end

  test "valid with key, label, principle_type" do
    p = Principle.new(valid_attrs)
    assert p.valid?, p.errors.full_messages.inspect
  end

  test "key is required" do
    p = Principle.new(valid_attrs(key: nil))
    assert_not p.valid?
    assert p.errors.of_kind?(:key, :blank)
  end

  test "key must be unique" do
    Principle.create!(valid_attrs)
    dup = Principle.new(valid_attrs)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:key, :taken)
  end

  test "key must be slug-shaped (lowercase / underscore / digits)" do
    p = Principle.new(valid_attrs(key: "NotASlug"))
    assert_not p.valid?
    assert p.errors.of_kind?(:key, :invalid)
  end

  test "label is required" do
    p = Principle.new(valid_attrs(label: nil))
    assert_not p.valid?
    assert p.errors.of_kind?(:label, :blank)
  end

  test "assigning unknown principle_type raises ArgumentError" do
    assert_raises(ArgumentError) do
      Principle.new.principle_type = "unknown"
    end
  end

  test "prefixed predicate works for principle_type" do
    p = Principle.new(valid_attrs(principle_type: "strategic_maxim"))
    assert_predicate p, :principle_strategic_maxim?
    assert_not p.principle_measurable_dimension?
  end

  test "has_many :concept_principles and :training_concepts associations" do
    p = Principle.create!(valid_attrs)
    assert_respond_to p, :concept_principles
    assert_respond_to p, :training_concepts
    assert_equal 0, p.concept_principles.size
    assert_equal 0, p.training_concepts.size
  end

  test "destroying a principle destroys its concept_principles" do
    p = Principle.create!(valid_attrs)
    tc = TrainingConcept.create!(title: "T", axis: "conception")
    ConceptPrinciple.create!(training_concept: tc, principle: p, relation: "teaches")
    assert_difference -> { ConceptPrinciple.count }, -1 do
      p.destroy
    end
  end
end
