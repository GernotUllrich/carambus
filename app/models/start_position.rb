class StartPosition < ApplicationRecord
  include LocalProtector
  include Taggable
  include Translatable
  
  self.table_name = 'starting_positions'
  
  belongs_to :training_example
  has_one_attached :image
  
  validates :training_example_id, uniqueness: true
  
  def translatable_fields
    [:description_text]
  end
  
  # ball_measurements structure example:
  # {
  #   "b1": { "x": 100, "y": 200, "description": "Ball 1 position" },
  #   "b2": { "x": 150, "y": 250, "description": "Ball 2 position" },
  #   "b3": { "x": 200, "y": 300, "description": "Ball 3 position" }
  # }
  
  # position_variants structure example:
  # [
  #   { "name": "Variant A", "b1": { "x": 105, "y": 205 } },
  #   { "name": "Variant B", "b1": { "x": 95, "y": 195 } }
  # ]
end
