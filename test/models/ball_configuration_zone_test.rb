# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 2B: M2M join between BallConfiguration and TableZone. One
# configuration can touch multiple zones simultaneously (B1 aiming for
# small_line while B2 parks in catches). `which_ball` + `role` typify
# the link.
class BallConfigurationZoneTest < ActiveSupport::TestCase
  def config
    @config ||= BallConfiguration.create!(
      b1_x: 0.10, b1_y: 0.20,
      b2_x: 0.30, b2_y: 0.40,
      b3_x: 0.50, b3_y: 0.60,
      table_variant: "match",
      gather_state: "pre_gather"
    )
  end

  def zone
    @zone ||= TableZone.create!(
      key: "small_line",
      label: "Kleine Linie",
      zone_type: "band_strip",
      polygon_normalized: [[0, 0], [1, 0], [1, 0.1], [0, 0.1]]
    )
  end

  test "which_ball enum exposes exactly four values" do
    assert_equal %w[b1 b2 b3 any], BallConfigurationZone.which_balls.keys
  end

  test "role enum exposes exactly three values" do
    assert_equal %w[target source via], BallConfigurationZone.roles.keys
  end

  test "valid with config + zone + which_ball + role" do
    bcz = BallConfigurationZone.new(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    assert bcz.valid?, bcz.errors.full_messages.inspect
  end

  test "requires ball_configuration" do
    bcz = BallConfigurationZone.new(table_zone: zone, which_ball: "b1", role: "target")
    assert_not bcz.valid?
    assert bcz.errors.of_kind?(:ball_configuration, :blank)
  end

  test "requires table_zone" do
    bcz = BallConfigurationZone.new(ball_configuration: config, which_ball: "b1", role: "target")
    assert_not bcz.valid?
    assert bcz.errors.of_kind?(:table_zone, :blank)
  end

  test "requires which_ball" do
    bcz = BallConfigurationZone.new(ball_configuration: config, table_zone: zone, role: "target")
    assert_not bcz.valid?
    assert bcz.errors.of_kind?(:which_ball, :blank)
  end

  test "requires role" do
    bcz = BallConfigurationZone.new(ball_configuration: config, table_zone: zone, which_ball: "b1")
    assert_not bcz.valid?
    assert bcz.errors.of_kind?(:role, :blank)
  end

  test "assigning unknown which_ball raises ArgumentError" do
    assert_raises(ArgumentError) do
      BallConfigurationZone.new.which_ball = "b4"
    end
  end

  test "assigning unknown role raises ArgumentError" do
    assert_raises(ArgumentError) do
      BallConfigurationZone.new.role = "bounces_off"
    end
  end

  test "same (config, zone, which_ball, role) combo is rejected as duplicate" do
    BallConfigurationZone.create!(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    dup = BallConfigurationZone.new(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    assert_not dup.valid?
    assert dup.errors.of_kind?(:ball_configuration_id, :taken)
  end

  test "same (config, zone) with different which_ball is allowed" do
    BallConfigurationZone.create!(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    alt = BallConfigurationZone.new(
      ball_configuration: config, table_zone: zone,
      which_ball: "b2", role: "target"
    )
    assert alt.valid?, alt.errors.full_messages.inspect
  end

  test "destroying configuration removes join rows" do
    BallConfigurationZone.create!(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    assert_difference -> { BallConfigurationZone.count }, -1 do
      config.destroy
    end
  end

  test "destroying zone removes join rows" do
    BallConfigurationZone.create!(
      ball_configuration: config, table_zone: zone,
      which_ball: "b1", role: "target"
    )
    assert_difference -> { BallConfigurationZone.count }, -1 do
      zone.destroy
    end
  end
end
