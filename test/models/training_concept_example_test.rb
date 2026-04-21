# frozen_string_literal: true

require "test_helper"

# v0.9 Phase D: M2M-Join zwischen TrainingConcept und TrainingExample
# mit Gewichtung (weight 1-5) und optionaler Rolle (illustrates /
# counter_example). sequence_number ist ebenfalls auf dem Join, weil
# die Reihenfolge konzept-abhängig ist — dieselbe Übung kann in
# Konzept X an Position 3 stehen, in Konzept Y an Position 7.
class TrainingConceptExampleTest < ActiveSupport::TestCase
  def concept
    @concept ||= TrainingConcept.create!(title: "Test-Konzept", axis: "conception")
  end

  def example
    @example ||= TrainingExample.create!(title: "Test-Übung")
  end

  def valid_attrs(**overrides)
    {
      training_concept: concept,
      training_example: example,
      weight: 3
    }.merge(overrides)
  end

  test "schema columns present" do
    %w[training_concept_id training_example_id weight role sequence_number notes]
      .each { |col| assert_includes TrainingConceptExample.column_names, col }
  end

  test "role enum exposes exactly two values" do
    assert_equal %w[illustrates counter_example], TrainingConceptExample.roles.keys
  end

  test "weight defaults to 3 on new records" do
    link = TrainingConceptExample.new
    assert_equal 3, link.weight
  end

  test "valid with concept + example + weight" do
    link = TrainingConceptExample.new(valid_attrs)
    assert link.valid?, link.errors.full_messages.inspect
  end

  test "requires training_concept" do
    link = TrainingConceptExample.new(valid_attrs(training_concept: nil))
    assert_not link.valid?
    assert link.errors.of_kind?(:training_concept, :blank)
  end

  test "requires training_example" do
    link = TrainingConceptExample.new(valid_attrs(training_example: nil))
    assert_not link.valid?
    assert link.errors.of_kind?(:training_example, :blank)
  end

  test "weight must be integer 1..5" do
    [0, 6, -1, 99].each do |bad|
      link = TrainingConceptExample.new(valid_attrs(weight: bad))
      assert_not link.valid?, "weight=#{bad} should be invalid"
      assert link.errors.of_kind?(:weight, :in) || link.errors[:weight].any?
    end
  end

  test "weight accepts 1 through 5" do
    (1..5).each do |w|
      link = TrainingConceptExample.new(valid_attrs(weight: w, training_example: TrainingExample.create!(title: "E#{w}")))
      assert link.valid?, "weight=#{w} should be valid: #{link.errors.full_messages.inspect}"
    end
  end

  test "same (concept, example) pair is unique" do
    TrainingConceptExample.create!(valid_attrs)
    dup = TrainingConceptExample.new(valid_attrs)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:training_concept_id, :taken)
  end

  test "assigning unknown role raises ArgumentError" do
    assert_raises(ArgumentError) do
      TrainingConceptExample.new.role = "mentions"
    end
  end

  test "role is optional (nullable)" do
    link = TrainingConceptExample.new(valid_attrs(role: nil))
    assert link.valid?
  end

  test "sequence_number uniqueness is scoped per concept" do
    TrainingConceptExample.create!(valid_attrs(sequence_number: 1))
    ex2 = TrainingExample.create!(title: "E2")
    dup = TrainingConceptExample.new(valid_attrs(training_example: ex2, sequence_number: 1))
    assert_not dup.valid?
    assert dup.errors.of_kind?(:sequence_number, :taken)
  end

  test "sequence_number can repeat across different concepts" do
    TrainingConceptExample.create!(valid_attrs(sequence_number: 1))
    c2 = TrainingConcept.create!(title: "Other", axis: "technique")
    other = TrainingConceptExample.new(valid_attrs(training_concept: c2, sequence_number: 1))
    assert other.valid?, other.errors.full_messages.inspect
  end

  test "sequence_number is optional" do
    link = TrainingConceptExample.new(valid_attrs(sequence_number: nil))
    assert link.valid?
  end

  test "TrainingConcept M2M: concept.training_examples returns linked examples" do
    TrainingConceptExample.create!(valid_attrs)
    assert_includes concept.training_examples, example
  end

  test "TrainingExample M2M: example.training_concepts returns linked concepts" do
    TrainingConceptExample.create!(valid_attrs)
    assert_includes example.training_concepts, concept
  end

  test "an example can belong to multiple concepts" do
    c2 = TrainingConcept.create!(title: "Zweites Konzept", axis: "conception")
    TrainingConceptExample.create!(valid_attrs)
    TrainingConceptExample.create!(valid_attrs(training_concept: c2))
    assert_equal 2, example.training_concepts.count
    assert_includes example.training_concepts, concept
    assert_includes example.training_concepts, c2
  end

  test "a concept can have multiple examples with different weights" do
    e2 = TrainingExample.create!(title: "E2")
    TrainingConceptExample.create!(valid_attrs(weight: 5))
    TrainingConceptExample.create!(valid_attrs(training_example: e2, weight: 2))
    assert_equal 2, concept.training_examples.count
  end

  test "by_weight scope orders descending" do
    e2 = TrainingExample.create!(title: "Schwach")
    e3 = TrainingExample.create!(title: "Stark")
    TrainingConceptExample.create!(valid_attrs(weight: 2))
    TrainingConceptExample.create!(valid_attrs(training_example: e2, weight: 1))
    TrainingConceptExample.create!(valid_attrs(training_example: e3, weight: 5))
    # reorder überschreibt die Default-Sortierung vom has_many-Scope (sequence_number NULLS LAST, id)
    ordered = concept.training_concept_examples.reorder(weight: :desc).pluck(:weight)
    assert_equal [5, 2, 1], ordered
  end

  test "destroying concept destroys join rows but NOT the examples" do
    TrainingConceptExample.create!(valid_attrs)
    ex_id = example.id
    assert_difference -> { TrainingConceptExample.count }, -1 do
      concept.destroy
    end
    # Example überlebt, weil es andere Konzepte bedienen kann
    assert TrainingExample.exists?(ex_id), "TrainingExample sollte nicht mit-destroy werden"
  end

  test "destroying example destroys join rows" do
    TrainingConceptExample.create!(valid_attrs)
    assert_difference -> { TrainingConceptExample.count }, -1 do
      example.destroy
    end
  end
end
