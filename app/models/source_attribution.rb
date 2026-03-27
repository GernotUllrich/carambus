class SourceAttribution < ApplicationRecord
  belongs_to :training_source
  belongs_to :sourceable, polymorphic: true
  
  validates :training_source, presence: true
  validates :sourceable, presence: true
  
  # Helper method for display
  def display_reference
    parts = [training_source.display_name]
    parts << reference if reference.present?
    parts.join(' - ')
  end
end
