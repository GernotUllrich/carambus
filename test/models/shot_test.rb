# frozen_string_literal: true

require "test_helper"

# Shape tests for the Shot <-> BallConfiguration association introduced by
# ontology v0.7. The end position is optional because error-only shots may
# lack a structured endpoint.
class ShotTest < ActiveSupport::TestCase
  test "belongs_to :end_ball_configuration, optional, class_name BallConfiguration" do
    assoc = Shot.reflect_on_association(:end_ball_configuration)
    assert_not_nil assoc, "Shot should belong_to :end_ball_configuration"
    assert_equal :belongs_to, assoc.macro
    assert_equal "BallConfiguration", assoc.options[:class_name]
    assert assoc.options[:optional],
           "end_ball_configuration is optional (nullable FK)"
  end

  test "belongs_to :training_example stays intact" do
    assoc = Shot.reflect_on_association(:training_example)
    assert_not_nil assoc
    assert_equal :belongs_to, assoc.macro
  end

  test "legacy jsonb and string attributes are gone" do
    assert_not Shot.column_names.include?("end_position_data"),
               "end_position_data column should have been dropped"
    assert_not Shot.column_names.include?("end_position_type"),
               "end_position_type column should have been dropped"
  end

  test "end_ball_configuration_id column exists" do
    assert_includes Shot.column_names, "end_ball_configuration_id"
  end

  test "inverse association on BallConfiguration is :ending_shots" do
    config = build(:ball_configuration)
    assert_respond_to config, :ending_shots
  end
end
