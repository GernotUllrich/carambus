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
end
