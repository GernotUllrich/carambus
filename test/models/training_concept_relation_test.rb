# frozen_string_literal: true

require "test_helper"

# v0.9 Phase C: self-referentielle Concept↔Concept-Relationen. Ersetzt
# und erweitert die gelöschte concept_principles-Tabelle: teaches /
# applies / exemplifies bleiben, specializes + parallels kommen dazu.
class TrainingConceptRelationTest < ActiveSupport::TestCase
  def source
    @source ||= TrainingConcept.create!(title: "Versammlungsstoß", axis: "conception")
  end

  def target
    @target ||= TrainingConcept.create!(title: "Übertragungseffet", axis: "technique")
  end

  def valid_attrs(**overrides)
    { source_concept: source, target_concept: target, relation: "applies" }.merge(overrides)
  end

  test "schema columns present" do
    %w[source_concept_id target_concept_id relation notes].each do |col|
      assert_includes TrainingConceptRelation.column_names, col
    end
  end

  test "relation enum exposes exactly five values" do
    assert_equal %w[teaches applies exemplifies specializes parallels],
                 TrainingConceptRelation.relations.keys
  end

  test "valid with source + target + relation" do
    r = TrainingConceptRelation.new(valid_attrs)
    assert r.valid?, r.errors.full_messages.inspect
  end

  test "requires source_concept" do
    r = TrainingConceptRelation.new(valid_attrs(source_concept: nil))
    assert_not r.valid?
    assert r.errors.of_kind?(:source_concept, :blank)
  end

  test "requires target_concept" do
    r = TrainingConceptRelation.new(valid_attrs(target_concept: nil))
    assert_not r.valid?
    assert r.errors.of_kind?(:target_concept, :blank)
  end

  test "requires relation" do
    r = TrainingConceptRelation.new(valid_attrs(relation: nil))
    assert_not r.valid?
    assert r.errors.of_kind?(:relation, :blank)
  end

  test "assigning unknown relation raises ArgumentError" do
    assert_raises(ArgumentError) do
      TrainingConceptRelation.new.relation = "mentions"
    end
  end

  test "prefixed predicates work for relation" do
    r = TrainingConceptRelation.new(valid_attrs(relation: "specializes"))
    assert_predicate r, :relation_specializes?
    assert_not r.relation_applies?
  end

  test "same (source, target, relation) combo is rejected as duplicate" do
    TrainingConceptRelation.create!(valid_attrs)
    dup = TrainingConceptRelation.new(valid_attrs)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:source_concept_id, :taken)
  end

  test "same (source, target) with different relation is allowed" do
    TrainingConceptRelation.create!(valid_attrs(relation: "applies"))
    alt = TrainingConceptRelation.new(valid_attrs(relation: "specializes"))
    assert alt.valid?, alt.errors.full_messages.inspect
  end

  test "self-loop is rejected at the model level" do
    r = TrainingConceptRelation.new(
      source_concept: source, target_concept: source, relation: "applies"
    )
    assert_not r.valid?
    assert r.errors.of_kind?(:target_concept_id, :invalid) ||
           r.errors[:target_concept_id].any?
  end

  test "TrainingConcept#outgoing_relations and #related_concepts" do
    TrainingConceptRelation.create!(valid_attrs(relation: "applies"))

    assert_equal 1, source.outgoing_relations.count
    assert_includes source.related_concepts, target
    assert_not_includes source.referring_concepts, target
  end

  test "TrainingConcept#incoming_relations and #referring_concepts" do
    TrainingConceptRelation.create!(valid_attrs(relation: "applies"))

    assert_equal 1, target.incoming_relations.count
    assert_includes target.referring_concepts, source
    assert_not_includes target.related_concepts, source
  end

  test "destroying a concept destroys its outgoing and incoming relations" do
    TrainingConceptRelation.create!(valid_attrs(relation: "applies"))
    TrainingConceptRelation.create!(valid_attrs(relation: "teaches"))

    assert_difference -> { TrainingConceptRelation.count }, -2 do
      source.destroy
    end
  end

  test "scope relation_teaches filters to teaches-relations" do
    TrainingConceptRelation.create!(valid_attrs(relation: "teaches"))
    TrainingConceptRelation.create!(valid_attrs(relation: "applies"))

    teaches_rows = source.outgoing_relations.relation_teaches
    assert_equal 1, teaches_rows.count
    assert_equal "teaches", teaches_rows.first.relation
  end
end
