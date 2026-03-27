class TrainingExample < ApplicationRecord
  include Taggable
  include Translatable
  
  # Self-referential hierarchy for position variants
  belongs_to :parent, class_name: 'TrainingExample', optional: true
  has_many :children, class_name: 'TrainingExample', foreign_key: :parent_id, dependent: :destroy
  
  belongs_to :training_concept
  has_one :start_position, dependent: :destroy
  has_many :shots, dependent: :destroy
  has_many :source_attributions, as: :sourceable, dependent: :destroy
  has_many :training_sources, through: :source_attributions
  
  validates :sequence_number, presence: true, 
            uniqueness: { scope: :training_concept_id }
  
  accepts_nested_attributes_for :start_position, allow_destroy: true
  accepts_nested_attributes_for :shots, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :source_attributions, allow_destroy: true, reject_if: :all_blank
  
  before_validation :set_sequence_number
  
  scope :ordered, -> { order(:sequence_number) }
  
  def translatable_fields
    [:title, :ideal_stroke_parameters_text]
  end
  
  private
  
  def set_sequence_number
    return if sequence_number.present?
    
    max_sequence = training_concept.training_examples.maximum(:sequence_number) || 0
    self.sequence_number = max_sequence + 1
  end
end
