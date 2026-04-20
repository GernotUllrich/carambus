class StartPosition < ApplicationRecord
  include LocalProtector
  include Taggable
  include Translatable

  self.table_name = 'starting_positions'

  belongs_to :training_example
  belongs_to :ball_configuration
  has_one_attached :image

  validates :training_example_id, uniqueness: true

  def translatable_fields
    [:description_text]
  end
end
