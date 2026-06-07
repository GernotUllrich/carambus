# frozen_string_literal: true

require "test_helper"

class ShotTest < ActiveSupport::TestCase
  setup do
    @training_concept = TrainingConcept.create!(title: "Test-Konzept")
    @training_example = TrainingExample.create!(training_concept: @training_concept)
  end

  test "saves with default source_language de" do
    shot = Shot.new(training_example: @training_example, shot_type: "ideal")
    assert shot.valid?, shot.errors.full_messages.to_sentence
    shot.save!
    assert_equal "de", shot.source_language
  end

  test "Translatable per-field sync writes title_de for de source" do
    shot = Shot.create!(
      training_example: @training_example,
      shot_type: "ideal",
      title: "Stoßball langer Stoß"
    )
    assert_equal "Stoßball langer Stoß", shot.title_de
  end

  test "rejects invalid source_language" do
    shot = Shot.new(
      training_example: @training_example,
      shot_type: "ideal",
      source_language: "xx"
    )
    assert_not shot.valid?
    assert_includes shot.errors.attribute_names, :source_language
  end
end
