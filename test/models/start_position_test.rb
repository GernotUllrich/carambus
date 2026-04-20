# frozen_string_literal: true

require "test_helper"

# Shape tests for the StartPosition <-> BallConfiguration association introduced
# by ontology v0.7. Keeps to PRAGMATISCHE_TESTS scope: we verify the wiring,
# not the full persistence chain (which would require upstream discipline /
# training_concept / training_example factories we do not yet have).
class StartPositionTest < ActiveSupport::TestCase
  test "belongs_to :ball_configuration, required" do
    assoc = StartPosition.reflect_on_association(:ball_configuration)
    assert_not_nil assoc, "StartPosition should belong_to :ball_configuration"
    assert_equal :belongs_to, assoc.macro
    assert_not assoc.options[:optional],
               "ball_configuration is mandatory on StartPosition (FK null: false)"
  end

  test "belongs_to :training_example stays intact" do
    assoc = StartPosition.reflect_on_association(:training_example)
    assert_not_nil assoc
    assert_equal :belongs_to, assoc.macro
  end

  test "legacy jsonb attributes are gone" do
    assert_not StartPosition.column_names.include?("ball_measurements"),
               "ball_measurements column should have been dropped"
    assert_not StartPosition.column_names.include?("position_variants"),
               "position_variants column should have been dropped"
  end

  test "ball_configuration_id column exists" do
    assert_includes StartPosition.column_names, "ball_configuration_id"
  end
end
