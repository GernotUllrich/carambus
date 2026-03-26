class TrainingExample < ApplicationRecord
  include Taggable
  include Translatable
  
  belongs_to :training_concept
  has_one :starting_position, dependent: :destroy
  has_one :target_position, dependent: :destroy
  has_many :error_examples, dependent: :destroy
  
  validates :sequence_number, presence: true, 
            uniqueness: { scope: :training_concept_id }
  
  accepts_nested_attributes_for :starting_position, allow_destroy: true
  accepts_nested_attributes_for :target_position, allow_destroy: true
  accepts_nested_attributes_for :error_examples, allow_destroy: true, reject_if: :all_blank
  
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
