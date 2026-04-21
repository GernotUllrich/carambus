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

  # Translatable wiring: shots were created without source_language / translations
  # columns despite including the Translatable concern. Any Shot.create blew up
  # on NoMethodError in the before_validation callback.

  test "has source_language column" do
    assert_includes Shot.column_names, "source_language"
  end

  test "has translations jsonb column" do
    assert_includes Shot.column_names, "translations"
  end

  test "Translatable callback fills source_language to 'de'" do
    # Call the callback directly; a full `valid?` pass also triggers
    # set_sequence_number which needs training_example. We isolate the
    # Translatable fix here.
    shot = Shot.new
    shot.send(:set_default_language)
    assert_equal "de", shot.source_language
  end

  # v0.8 Tier 2C — raw columns for Translatable's before_save sync

  test "has raw text columns title, notes, end_position_description, shot_description" do
    %w[title notes end_position_description shot_description].each do |col|
      assert_includes Shot.column_names, col,
        "Shot.#{col} must exist as raw column — Translatable#sync_source_language_fields reads it"
    end
  end

  test "Shot.create with raw title/notes no longer raises and syncs into _de" do
    concept = TrainingConcept.create!(title: "Tier 2C Test", axis: "conception")
    example = concept.training_examples.create!(title: "Tier 2C Example")

    shot = example.shots.create!(
      shot_type: "ideal",
      sequence_number: 1,
      title: "A Konterspiel opener",
      notes: "Weich anspielen",
      shot_description: "B1 trifft B2 voll",
      end_position_description: "Bälle liegen in catches"
    )

    assert_predicate shot, :persisted?
    assert_equal "A Konterspiel opener",  shot.title_de
    assert_equal "Weich anspielen",       shot.notes_de
    assert_equal "B1 trifft B2 voll",     shot.shot_description_de
    assert_equal "Bälle liegen in catches", shot.end_position_description_de
  end

  test "field_in(:title, 'de') reads the DE-synced value" do
    concept = TrainingConcept.create!(title: "Tier 2C Test 2", axis: "conception")
    example = concept.training_examples.create!(title: "Tier 2C Example 2")

    shot = example.shots.create!(shot_type: "ideal", sequence_number: 1, title: "Title-DE")

    assert_equal "Title-DE", shot.field_in(:title, "de")
  end
end
