class Tag < ApplicationRecord
  include Translatable
  
  has_many :taggings, dependent: :destroy
  has_many :training_concepts, through: :taggings, source: :taggable, source_type: 'TrainingConcept'
  has_many :training_examples, through: :taggings, source: :taggable, source_type: 'TrainingExample'
  has_many :starting_positions, through: :taggings, source: :taggable, source_type: 'StartingPosition'
  has_many :target_positions, through: :taggings, source: :taggable, source_type: 'TargetPosition'
  
  validates :name, presence: true, uniqueness: true
  
  def translatable_fields
    [:name, :description]
  end
  
  # Common tag categories
  CATEGORIES = [
    'Position',           # z.B. "Amerika-Position", "Ecke-Position"
    'Technik',           # z.B. "Versammlungsstoß", "Konterstoß"
    'Schwierigkeit',     # z.B. "Anfänger", "Fortgeschritten", "Profi"
    'Spielart',          # z.B. "1-shot", "2-shot", "3-shot"
    'Zone',              # z.B. "Cadre-Kreuz", "Ecke", "Mitte"
    'Spezial'            # z.B. "Klassiker", "Wettkampf-Position"
  ].freeze
  
  scope :by_category, ->(category) { where(category: category) }
  scope :ordered, -> { order(:category, :name) }
  
  def display_name
    category.present? ? "#{category}: #{name}" : name
  end
end
