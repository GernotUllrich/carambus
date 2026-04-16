class TrainingConcept < ApplicationRecord
  include LocalProtector
  include Taggable
  include Translatable
  
  has_many :training_concept_disciplines, dependent: :destroy
  has_many :disciplines, through: :training_concept_disciplines
  has_many :training_examples, dependent: :destroy
  has_many :source_attributions, as: :sourceable, dependent: :destroy
  has_many :training_sources, through: :source_attributions
  
  accepts_nested_attributes_for :source_attributions, allow_destroy: true, reject_if: :all_blank
  
  validates :title, presence: true
  
  def translatable_fields
    [:title, :short_description, :full_description]
  end
  
  # Convenience methods for accessing translated content
  def title_in(language)
    field_in(:title, language)
  end
  
  def short_description_in(language)
    field_in(:short_description, language)
  end
  
  def full_description_in(language)
    field_in(:full_description, language)
  end
end
