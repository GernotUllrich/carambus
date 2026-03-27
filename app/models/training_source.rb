class TrainingSource < ApplicationRecord
  has_many :source_attributions, dependent: :destroy
  has_many :training_concepts, through: :source_attributions, source: :sourceable, source_type: 'TrainingConcept'
  has_many :training_examples, through: :source_attributions, source: :sourceable, source_type: 'TrainingExample'
  
  # Source files are stored locally and NOT synchronized via rsync
  has_many_attached :source_files, service: :local_sources
  
  validates :title, presence: true
  validates :language, inclusion: { in: %w[de en nl fr], allow_blank: true }
  
  def display_name
    parts = [title]
    parts << "(#{author})" if author.present?
    parts << publication_year.to_s if publication_year.present?
    parts.join(' ')
  end
end
