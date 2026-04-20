class Shot < ApplicationRecord
  include LocalProtector
  include Translatable
  
  belongs_to :training_example
  belongs_to :end_ball_configuration,
             class_name: "BallConfiguration",
             optional: true,
             inverse_of: :ending_shots
  has_many :shot_events, -> { order(:sequence_number) }, dependent: :destroy
  has_one_attached :shot_image
  
  validates :shot_type, presence: true, inclusion: { in: %w[ideal alternative error] }
  validates :sequence_number, presence: true, 
            uniqueness: { scope: :training_example_id }
  
  before_validation :set_sequence_number
  
  scope :ordered, -> { order(:sequence_number) }
  scope :ideal, -> { where(shot_type: 'ideal') }
  scope :alternative, -> { where(shot_type: 'alternative') }
  scope :errors, -> { where(shot_type: 'error') }
  
  def translatable_fields
    [
      :title,
      :notes,
      :end_position_description,
      :shot_description
    ]
  end
  
  def ideal?
    shot_type == 'ideal'
  end
  
  def alternative?
    shot_type == 'alternative'
  end
  
  def error?
    shot_type == 'error'
  end
  
  private
  
  def set_sequence_number
    return if sequence_number.present?
    
    max_sequence = training_example.shots.maximum(:sequence_number) || 0
    self.sequence_number = max_sequence + 1
  end
end
