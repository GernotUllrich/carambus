# frozen_string_literal: true

require "test_helper"

class TrainingPackage::ExporterTest < ActiveSupport::TestCase
  include TrainingPackageTestHelper

  setup do
    wipe_training_tables!
    @graph = build_training_graph
  end

  test "exports every training table in import order with its global rows" do
    package = TrainingPackage::Exporter.call

    assert_equal TrainingPackage::TABLES, package["tables"].keys
    TrainingPackage::TABLES.each do |table|
      expected = TrainingPackage.model_for(table).unscoped.where("id < ?", ApplicationRecord::MIN_ID).order(:id).pluck(:id)
      assert_equal expected, package["tables"][table].map { |r| r["id"] }, table
      assert expected.any?, "#{table}: Testgraph sollte jede Tabelle belegen"
    end
  end

  test "leaves out local rows at or above MIN_ID and counts them" do
    local = TrainingConcept.create!(id: ApplicationRecord::MIN_ID + 7, title: "Lokal", axis: "conception")

    package = TrainingPackage::Exporter.call

    refute_includes package["tables"]["training_concepts"].map { |r| r["id"] }, local.id
    assert_equal 1, package["manifest"]["skipped_local"]["training_concepts"]
  end

  test "manifest carries format, schema, counts, prune flag and a digest over the tables" do
    package = TrainingPackage::Exporter.call(prune: true)
    manifest = package["manifest"]

    assert_equal TrainingPackage::FORMAT, manifest["format"]
    assert_equal TrainingPackage::FORMAT_VERSION, manifest["format_version"]
    assert_equal ActiveRecord::Base.connection.select_value("SELECT max(version) FROM schema_migrations"),
      manifest["schema_version"]
    assert_equal true, manifest["prune"]
    assert_equal package["tables"].transform_values(&:size), manifest["counts"]
    assert_equal TrainingPackage.digest(package["tables"]), manifest["sha256"]
  end

  test "prune defaults to false" do
    assert_equal false, TrainingPackage::Exporter.call["manifest"]["prune"]
  end

  test "values survive the trip through a file unchanged" do
    shot = @graph[:shot]
    shot.update_columns(created_at: Time.utc(2026, 9, 18, 10, 11, 12, 123_456))

    package = via_file(TrainingPackage::Exporter.call)
    row = package["tables"]["shots"].find { |r| r["id"] == shot.id }

    assert_equal "2026-09-18T10:11:12.123456Z", row["created_at"]
    assert_equal TrainingPackage.digest(package["tables"]), package["manifest"]["sha256"],
      "Digest muss nach JSON-Rundlauf stabil sein"
    bc_row = package["tables"]["ball_configurations"].first
    assert_in_delta 0.2, bc_row["b1_x"], 0.0
  end

  test "refuses to export while training records carry tags" do
    tag = Tag.create!(id: gid, name: "pkg-tag")
    Tagging.create!(id: gid, tag: tag, taggable: @graph[:dominance])

    error = assert_raises(TrainingPackage::Error) { TrainingPackage::Exporter.call }
    assert_match(/Tags/, error.message)
  end
end
