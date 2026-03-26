class TargetPosition < ApplicationRecord
  include Taggable
  include Translatable
  
  belongs_to :training_example
  # TODO: Add image attachment once ActiveStorage is properly configured
  # has_one_attached :image
  
  validates :training_example_id, uniqueness: true
  
  def translatable_fields
    [:description_text]
  end
  
  # ball_measurements structure example:
  # {
  #   "b1": { "x": 100, "y": 200, "description": "Ball 1 target position" },
  #   "b2": { "x": 150, "y": 250, "description": "Ball 2 target position" },
  #   "b3": { "x": 200, "y": 300, "description": "Ball 3 target position" }
  # }
end
