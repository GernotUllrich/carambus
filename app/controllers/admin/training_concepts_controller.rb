module Admin
  class TrainingConceptsController < Admin::ApplicationController
    before_action :check_translation_needed, only: [:update]
    
    def translate
      requested_resource.translate_to_target_languages!
      redirect_to [:admin, requested_resource], 
                  notice: "Training concept was successfully translated."
    rescue => e
      redirect_to [:admin, requested_resource], 
                  alert: "Translation failed: #{e.message}"
    end
    
    def valid_action?(name, resource = resource_class)
      %w[translate].include?(name.to_s) || super
    end
    
    private
    
    def check_translation_needed
      return unless params[:training_concept]
      
      changed_fields = params[:training_concept].keys & %w[title short_description full_description source_language]
      @should_translate = changed_fields.any?
    end
    
    def after_resource_updated(resource)
      if @should_translate
        resource.translate_to_target_languages!
      end
    rescue => e
      Rails.logger.error("Auto-translation failed: #{e.message}")
    end
  end
end
