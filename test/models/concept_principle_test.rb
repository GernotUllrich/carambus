# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 2: join table linking TrainingConcepts to Principles with a
# typed relation (teaches | applies | exemplifies). notes is DE-only
# plain text per Tier 2 scoping (no Translatable).
class ConceptPrincipleTest < ActiveSupport::TestCase
  def concept
    @concept ||= TrainingConcept.create!(title: "Konterspiel-Test", axis: "conception")
  end

  def principle
    @principle ||= Principle.create!(
      key: "dominance",
      label: "Dominanz",
      principle_type: "measurable_dimension"
    )
  end

  test "relation enum exposes exactly three values" do
    assert_equal %w[teaches applies exemplifies], ConceptPrinciple.relations.keys
  end

  test "valid with concept + principle + relation" do
    cp = ConceptPrinciple.new(
      training_concept: concept, principle: principle, relation: "teaches"
    )
    assert cp.valid?, cp.errors.full_messages.inspect
  end

  test "requires training_concept" do
    cp = ConceptPrinciple.new(principle: principle, relation: "teaches")
    assert_not cp.valid?
    assert cp.errors.of_kind?(:training_concept, :blank)
  end

  test "requires principle" do
    cp = ConceptPrinciple.new(training_concept: concept, relation: "teaches")
    assert_not cp.valid?
    assert cp.errors.of_kind?(:principle, :blank)
  end

  test "requires relation" do
    cp = ConceptPrinciple.new(training_concept: concept, principle: principle)
    assert_not cp.valid?
    assert cp.errors.of_kind?(:relation, :blank)
  end

  test "assigning unknown relation raises ArgumentError" do
    assert_raises(ArgumentError) do
      ConceptPrinciple.new.relation = "mentions"
    end
  end

  test "same (concept, principle, relation) combo is rejected as duplicate" do
    ConceptPrinciple.create!(training_concept: concept, principle: principle, relation: "teaches")
    dup = ConceptPrinciple.new(training_concept: concept, principle: principle, relation: "teaches")
    assert_not dup.valid?
    assert dup.errors.of_kind?(:training_concept_id, :taken)
  end

  test "same (concept, principle) with different relation is allowed" do
    ConceptPrinciple.create!(training_concept: concept, principle: principle, relation: "teaches")
    alt = ConceptPrinciple.new(training_concept: concept, principle: principle, relation: "applies")
    assert alt.valid?, alt.errors.full_messages.inspect
  end

  test "destroying concept removes join rows" do
    ConceptPrinciple.create!(training_concept: concept, principle: principle, relation: "teaches")
    assert_difference -> { ConceptPrinciple.count }, -1 do
      concept.destroy
    end
  end

  test "notes is a plain text column (no _de / _en suffixes)" do
    assert_includes ConceptPrinciple.column_names, "notes"
    assert_not_includes ConceptPrinciple.column_names, "notes_de"
    assert_not_includes ConceptPrinciple.column_names, "notes_en"
  end
end
