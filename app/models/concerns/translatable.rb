module Translatable
  extend ActiveSupport::Concern
  
  included do
    validates :source_language, presence: true, inclusion: { in: %w[de en nl fr] }
    before_validation :set_default_language
    before_save :sync_source_language_fields
    after_save :mark_translations_out_of_sync, if: :translations_need_sync?
  end
  
  SUPPORTED_LANGUAGES = %w[de en nl fr].freeze
  TARGET_LANGUAGES = %w[de en].freeze
  
  # Translate all translatable fields to DE and EN
  def translate_to_target_languages!(force: false)
    return unless should_translate?
    
    TARGET_LANGUAGES.each do |target_lang|
      next if target_lang == source_language
      
      translatable_fields.each do |field|
        target_field = "#{field}_#{target_lang}"
        current_value = send(target_field)
        original_value = send(field)
        
        # Translate if:
        # 1. Field is empty, OR
        # 2. force=true, OR  
        # 3. Field has same value as original (not a manual edit)
        should_translate = current_value.blank? || 
                          force || 
                          current_value == original_value
        
        if should_translate
          translated_value = translate_field(field, target_lang)
          send("#{target_field}=", translated_value) if translated_value.present?
        end
      end
    end
    
    self.translations_synced_at = Time.current
    save!
  end
  
  # Get field value in specific language (for I18n integration)
  def field_in(field_name, language)
    case language.to_s
    when 'de'
      send("#{field_name}_de").presence || (source_language == 'de' ? send(field_name) : nil)
    when 'en'
      send("#{field_name}_en").presence || (source_language == 'en' ? send(field_name) : nil)
    when source_language
      send(field_name)
    else
      # For other languages (nl, fr), return original if it matches, otherwise nil
      source_language == language.to_s ? send(field_name) : nil
    end
  end
  
  # Check if translations are in sync with original
  def translations_in_sync?
    translations_synced_at.present? && 
      (updated_at.nil? || translations_synced_at >= updated_at)
  end
  
  # Check if any translated field was manually edited (different from original)
  def has_manual_edits?
    return false unless translations_synced_at.present?
    
    TARGET_LANGUAGES.any? do |lang|
      next if lang == source_language
      
      translatable_fields.any? do |field|
        translated = send("#{field}_#{lang}")
        translated.present? && translated != send(field)
      end
    end
  end
  
  # Define translatable fields for each model
  def translatable_fields
    raise NotImplementedError, "#{self.class} must implement #translatable_fields"
  end
  
  private
  
  def set_default_language
    self.source_language ||= 'de'
  end
  
  # Sync original field to _de or _en if source_language is de or en
  def sync_source_language_fields
    return unless source_language.in?(['de', 'en'])
    
    translatable_fields.each do |field|
      field_value = send(field)
      if source_language == 'de'
        send("#{field}_de=", field_value)
      elsif source_language == 'en'
        send("#{field}_en=", field_value)
      end
    end
  end
  
  def should_translate?
    translatable_fields.any? { |field| send(field).present? }
  end
  
  def translations_need_sync?
    return false unless persisted?
    return false unless should_translate?
    
    # Check if source fields changed
    changed_source = saved_changes.keys.any? { |k| 
      translatable_fields.map(&:to_s).include?(k) || k == 'source_language' 
    }
    
    # Check if translated fields were manually edited
    changed_translated = saved_changes.keys.any? { |k| 
      k.match?(/_(de|en)$/)
    }
    
    changed_source || changed_translated
  end
  
  def mark_translations_out_of_sync
    # If translated fields were manually edited, keep synced_at but mark as edited
    # If source changed, clear synced_at
    if saved_changes.keys.any? { |k| translatable_fields.map(&:to_s).include?(k) || k == 'source_language' }
      update_column(:translations_synced_at, nil)
    end
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
