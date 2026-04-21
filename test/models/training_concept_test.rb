# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 1: every TrainingConcept gets a Gretillat-spine axis tag
# (technique | conception | psychology | training). Default is conception
# because that is where most of the training-shot literature sits.
class TrainingConceptTest < ActiveSupport::TestCase
  test "axis column exists" do
    assert_includes TrainingConcept.column_names, "axis"
  end

  test "axis enum exposes exactly four values" do
    assert_equal %w[technique conception psychology training], TrainingConcept.axes.keys
  end

  test "axis defaults to conception on new instances" do
    tc = TrainingConcept.new
    assert_equal "conception", tc.axis
  end

  test "assigning unknown axis raises ArgumentError" do
    assert_raises(ArgumentError) do
      TrainingConcept.new.axis = "unknown"
    end
  end

  # v0.9 Phase B — Concept absorbiert die Principle-Struktur

  test "new Principle-inherited columns present" do
    %w[kind key gretillat_ref weingartner_ref importance_order].each do |col|
      assert_includes TrainingConcept.column_names, col,
        "TrainingConcept.#{col} must exist after v0.9 Phase B"
    end
  end

  test "kind enum exposes exactly six values" do
    assert_equal %w[topic strategic_maxim measurable_dimension phenomenological technique system],
                 TrainingConcept.kinds.keys
  end

  test "kind defaults to nil on new instances" do
    tc = TrainingConcept.new
    assert_nil tc.kind
  end

  test "kind is optional — a concept can live without a classification" do
    tc = TrainingConcept.new(title: "Some Topic")
    assert tc.valid?, tc.errors.full_messages.inspect
  end

  test "assigning unknown kind raises ArgumentError" do
    assert_raises(ArgumentError) do
      TrainingConcept.new.kind = "unknown_kind"
    end
  end

  test "prefixed predicate works for kind" do
    tc = TrainingConcept.new(kind: "strategic_maxim")
    assert_predicate tc, :kind_strategic_maxim?
    assert_not tc.kind_measurable_dimension?
  end

  test "key is optional (nullable)" do
    tc = TrainingConcept.new(title: "No-key Concept")
    assert tc.valid?
  end

  test "key must be slug-shaped when present" do
    tc = TrainingConcept.new(title: "T", key: "Not-A-Slug")
    assert_not tc.valid?
    assert tc.errors.of_kind?(:key, :invalid)
  end

  test "key accepts a valid slug" do
    tc = TrainingConcept.new(title: "T", key: "valid_slug_123")
    assert tc.valid?, tc.errors.full_messages.inspect
  end

  test "key must be unique when present" do
    TrainingConcept.create!(title: "First",  key: "unique_slug")
    dup = TrainingConcept.new(title: "Second", key: "unique_slug")
    assert_not dup.valid?
    assert dup.errors.of_kind?(:key, :taken)
  end

  test "multiple concepts without key are allowed (partial unique index)" do
    TrainingConcept.create!(title: "A")
    tc_b = TrainingConcept.new(title: "B")
    assert tc_b.valid?
    assert tc_b.save
  end
end
