# frozen_string_literal: true

require "test_helper"

# v0.8 Tier 2B: named table regions as first-class entities. Zones carry
# normalized polygons (coords in [0, 1]) so the shape stays identical
# across match / halbmatch / klein table_variant rendering.
class TableZoneTest < ActiveSupport::TestCase
  def valid_attrs(**overrides)
    {
      key: "small_line",
      label: "Kleine Linie",
      zone_type: "band_strip",
      polygon_normalized: [[0.0, 0.0], [1.0, 0.0], [1.0, 0.1], [0.0, 0.1]]
    }.merge(overrides)
  end

  test "schema columns present" do
    %w[key label zone_type polygon_normalized description gretillat_ref weingartner_ref]
      .each { |col| assert_includes TableZone.column_names, col }
  end

  test "zone_type enum exposes exactly four values" do
    assert_equal %w[band_strip corner_region line_passage custom], TableZone.zone_types.keys
  end

  test "valid with key, label, zone_type" do
    z = TableZone.new(valid_attrs)
    assert z.valid?, z.errors.full_messages.inspect
  end

  test "key is required" do
    z = TableZone.new(valid_attrs(key: nil))
    assert_not z.valid?
    assert z.errors.of_kind?(:key, :blank)
  end

  test "key must be unique" do
    TableZone.create!(valid_attrs)
    dup = TableZone.new(valid_attrs)
    assert_not dup.valid?
    assert dup.errors.of_kind?(:key, :taken)
  end

  test "key must be slug-shaped" do
    z = TableZone.new(valid_attrs(key: "Not-A-Slug"))
    assert_not z.valid?
    assert z.errors.of_kind?(:key, :invalid)
  end

  test "assigning unknown zone_type raises ArgumentError" do
    assert_raises(ArgumentError) do
      TableZone.new.zone_type = "unknown"
    end
  end

  test "prefixed predicate works for zone_type" do
    z = TableZone.new(valid_attrs(zone_type: "corner_region"))
    assert_predicate z, :zone_corner_region?
    assert_not z.zone_band_strip?
  end

  test "polygon_normalized defaults to empty array" do
    z = TableZone.create!(valid_attrs.except(:polygon_normalized))
    assert_equal [], z.polygon_normalized
  end

  test "polygon_normalized round-trips as array of [x, y] pairs" do
    z = TableZone.create!(valid_attrs)
    z.reload
    assert_equal [[0.0, 0.0], [1.0, 0.0], [1.0, 0.1], [0.0, 0.1]], z.polygon_normalized
  end

  test "has_many ball_configuration_zones association" do
    z = TableZone.create!(valid_attrs)
    assert_respond_to z, :ball_configuration_zones
    assert_respond_to z, :ball_configurations
    assert_equal 0, z.ball_configuration_zones.size
  end
end
