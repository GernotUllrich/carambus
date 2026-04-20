# frozen_string_literal: true

require "test_helper"

# Ontology v0.7: typed BallConfiguration with normalized coordinates in [0, 1],
# table_variant enum and gather_state enum. Smoke-level model tests in line
# with the PRAGMATISCHE_TESTS philosophy.
class BallConfigurationTest < ActiveSupport::TestCase
  test "factory produces a valid configuration" do
    config = build(:ball_configuration)
    assert config.valid?, config.errors.full_messages.inspect
  end

  test "saves with legal values" do
    config = build(:ball_configuration)
    assert config.save, config.errors.full_messages.inspect
    assert_predicate config, :persisted?
  end

  test "table_variant enum exposes exactly the allowed values" do
    assert_equal %w[match halbmatch klein], BallConfiguration.table_variants.keys
  end

  test "gather_state enum exposes exactly the allowed values" do
    assert_equal %w[pre_gather gathering post_gather], BallConfiguration.gather_states.keys
  end

  test "assigning an unknown table_variant raises ArgumentError (enum guard)" do
    assert_raises(ArgumentError) do
      BallConfiguration.new.table_variant = "unknown"
    end
  end

  test "assigning an unknown gather_state raises ArgumentError (enum guard)" do
    assert_raises(ArgumentError) do
      BallConfiguration.new.gather_state = "unknown"
    end
  end

  test "prefixed predicates and scopes work for table_variant" do
    match_config  = create(:ball_configuration, table_variant: "match")
    klein_config  = create(:ball_configuration, table_variant: "klein")

    assert_predicate match_config, :table_match?
    assert_not match_config.table_klein?
    assert_predicate klein_config, :table_klein?

    assert_includes BallConfiguration.table_match,  match_config
    assert_includes BallConfiguration.table_klein,  klein_config
    assert_not_includes BallConfiguration.table_klein, match_config
  end

  test "prefixed predicates work for gather_state" do
    pre = create(:ball_configuration, gather_state: "pre_gather")
    post = create(:ball_configuration, gather_state: "post_gather")

    assert_predicate pre, :gather_pre_gather?
    assert_predicate post, :gather_post_gather?
    assert_not pre.gather_post_gather?
  end

  test "coordinate above 1.0 is invalid" do
    config = build(:ball_configuration, b1_x: 1.5)
    assert_not config.valid?
    assert config.errors.of_kind?(:b1_x, :less_than_or_equal_to),
           "expected :less_than_or_equal_to error on :b1_x, got #{config.errors.details[:b1_x].inspect}"
  end

  test "coordinate below 0 is invalid" do
    config = build(:ball_configuration, b2_y: -0.01)
    assert_not config.valid?
    assert config.errors.of_kind?(:b2_y, :greater_than_or_equal_to),
           "expected :greater_than_or_equal_to error on :b2_y, got #{config.errors.details[:b2_y].inspect}"
  end

  test "missing coordinate is invalid" do
    config = build(:ball_configuration, b3_x: nil)
    assert_not config.valid?
    assert config.errors.of_kind?(:b3_x, :blank),
           "expected :blank error on :b3_x"
  end

  test "#balls returns normalized coordinates keyed by role" do
    config = build(:ball_configuration,
                   b1_x: 0.10, b1_y: 0.20,
                   b2_x: 0.30, b2_y: 0.40,
                   b3_x: 0.50, b3_y: 0.60)

    assert_equal({ b1: [0.10, 0.20], b2: [0.30, 0.40], b3: [0.50, 0.60] }, config.balls)
  end
end
