class TrainingConcept < ApplicationRecord
  has_many :training_concept_disciplines, dependent: :destroy
  has_many :disciplines, through: :training_concept_disciplines
  has_many :training_examples, dependent: :destroy
  
  validates :title, presence: true
  validates :source_language, presence: true, inclusion: { in: %w[de en nl fr] }
  
  before_validation :set_default_language
  
  SUPPORTED_LANGUAGES = %w[de en nl fr].freeze
  TARGET_LANGUAGES = %w[de en].freeze
  
  def translate_to_target_languages!
    return unless should_translate?
    
    TARGET_LANGUAGES.each do |target_lang|
      next if target_lang == source_language
      
      translations[target_lang] = {
        'title' => translate_field(:title, target_lang),
        'short_description' => translate_field(:short_description, target_lang),
        'full_description' => translate_field(:full_description, target_lang),
        'translated_at' => Time.current.iso8601
      }
    end
    
    save!
  end
  
  def title_in(language)
    return title if language == source_language
    translations.dig(language, 'title') || title
  end
  
  def short_description_in(language)
    return short_description if language == source_language
    translations.dig(language, 'short_description') || short_description
  end
  
  def full_description_in(language)
    return full_description if language == source_language
    translations.dig(language, 'full_description') || full_description
  end
  
  private
  
  def set_default_language
    self.source_language ||= 'de'
  end
  
  def should_translate?
    title.present? && (short_description.present? || full_description.present?)
  end
  
  def translate_field(field_name, target_language)
    field_value = send(field_name)
    return nil if field_value.blank?
    
    DeeplTranslationService.new.translate(
      text: field_value,
      source_lang: source_language.upcase,
      target_lang: target_language.upcase
    )
  rescue => e
    Rails.logger.error("Translation failed for #{field_name}: #{e.message}")
    nil
  end
end
