class ErrorExample < ApplicationRecord
  belongs_to :training_example
  # TODO: Add image attachment once ActiveStorage is properly configured
  # has_one_attached :image
  
  validates :sequence_number, presence: true,
            uniqueness: { scope: :training_example_id }
  
  before_validation :set_sequence_number
  
  scope :ordered, -> { order(:sequence_number) }
  
  # stroke_parameters_data structure example:
  # {
  #   "force": 0.7,
  #   "effect": "left",
  #   "aim_point": "top",
  #   "angle": 45
  # }
  
  private
  
  def set_sequence_number
    return if sequence_number.present?
    
    max_sequence = training_example.error_examples.maximum(:sequence_number) || 0
    self.sequence_number = max_sequence + 1
  end
end
