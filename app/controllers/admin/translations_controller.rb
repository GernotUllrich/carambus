module Admin
  class TranslationsController < Admin::ApplicationController
    def index
      @source_lang = params[:source_lang] || 'nl'
      @target_lang = params[:target_lang] || 'de'
      @translation_method = params[:translation_method] || 'deepl'
      @source_text = params[:source_text]
      @translated_text = nil
      @error = nil
      
      if @source_text.present?
        begin
          @translated_text = perform_translation(
            @source_text,
            @source_lang,
            @target_lang,
            @translation_method
          )
          
          if @translated_text.nil?
            @error = "Translation failed. Please check the logs for details."
          end
        rescue => e
          @error = "Error: #{e.message}"
          Rails.logger.error("Translation controller error: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
        end
      end
    end
    
    private
    
    def perform_translation(text, source_lang, target_lang, method)
      case method
      when 'deepl'
        service = DeeplTranslationService.new
        service.translate(
          text: text,
          source_lang: source_lang,
          target_lang: target_lang,
          use_glossary: true
        )
      when 'anthropic'
        service = AnthropicTranslationService.new
        service.translate(
          text: text,
          source_lang: source_lang,
          target_lang: target_lang
        )
      when 'openai'
        service = OpenaiTranslationService.new
        service.translate(
          text: text,
          source_lang: source_lang,
          target_lang: target_lang
        )
      else
        nil
      end
    end
  end
end
