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

  # v0.8 Tier 1: Gretillats pedagogical axis spine.
  AXES = %w[technique conception psychology training].freeze
  enum :axis, AXES.index_with(&:itself)

  # v0.9 Phase B: Concept absorbiert die Principle-Struktur.
  # kind klassifiziert die Konzept-Natur (Thema vs. Regel vs. Messgröße
  # vs. Beobachtung vs. Technik vs. System). Nullable — reine Topic-
  # Concepts brauchen kein kind gesetzt, können aber zur Klarheit.
  KINDS = %w[topic strategic_maxim measurable_dimension phenomenological technique system].freeze
  enum :kind, KINDS.index_with(&:itself), prefix: :kind

  validates :title, presence: true
  validates :axis,  presence: true
  validates :key,
            uniqueness: true,
            format: { with: /\A[a-z_][a-z0-9_]*\z/ },
            allow_nil: true
  
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
