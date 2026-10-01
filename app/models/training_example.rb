class TrainingExample < ApplicationRecord
  include LocalProtector
  include Taggable
  include Translatable

  # Self-referential hierarchy for position variants
  belongs_to :parent, class_name: "TrainingExample", optional: true
  has_many   :children, class_name: "TrainingExample",
                        foreign_key: :parent_id,
                        dependent:   :destroy

  # v0.9 Phase D: M2M zu TrainingConcept über training_concept_examples,
  # weil eine Übung mehrere Konzepte bedienen kann und die Gewichtung
  # per Konzept unterschiedlich ausfällt. sequence_number ist ebenfalls
  # auf den Join gewandert (Reihenfolge ist konzept-abhängig).
  has_many :training_concept_examples, dependent: :destroy
  has_many :training_concepts, through: :training_concept_examples

  has_one  :start_position, dependent: :destroy
  has_many :shots, dependent: :destroy
  has_many :source_attributions, as: :sourceable, dependent: :destroy
  has_many :training_sources, through: :source_attributions

  # Trainingsprogramme (Weingartner): Wertpunkte und Contre-Kennzeichen einer
  # Figur, Reihenfolge unter demselben Elternknoten (Gruppe im Programm, Figur
  # in der Gruppe).
  validates :points, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :sequence_number, numericality: { only_integer: true, greater_than: 0 },
                              uniqueness: { scope: :parent_id }, allow_nil: true

  accepts_nested_attributes_for :start_position, allow_destroy: true
  accepts_nested_attributes_for :shots, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :source_attributions, allow_destroy: true, reject_if: :all_blank

  def translatable_fields
    [:title, :ideal_stroke_parameters_text]
  end
end
