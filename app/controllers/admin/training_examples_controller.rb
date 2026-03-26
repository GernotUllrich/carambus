module Admin
  class TrainingExamplesController < Admin::ApplicationController
    before_action :set_training_concept, only: [:new, :create]
    before_action :check_translation_needed, only: [:update]
    
    # Override Administrate's before_action to skip finding resource for index and new
    def requested_resource
      if action_name == "new" || action_name == "index"
        nil
      else
        super
      end
    end
    
    def new
      if params[:training_concept_id].blank?
        redirect_to admin_training_concepts_path, 
                    alert: "Trainingsbeispiele müssen über ein Trainingskonzept erstellt werden."
        return
      end
      super
    end
    
    private
    
    def check_translation_needed
      return unless params[:training_example]
      
      changed_fields = params[:training_example].keys & %w[title ideal_stroke_parameters_text source_language]
      @should_translate = changed_fields.any?
    end
    
    def after_resource_updated(resource)
      if @should_translate
        resource.translate_to_target_languages!
      end
    rescue => e
      Rails.logger.error("Auto-translation failed: #{e.message}")
    end
    
    def set_training_concept
      @training_concept = TrainingConcept.find(params[:training_concept_id]) if params[:training_concept_id]
    end
    
    def scoped_resource
      if params[:training_concept_id]
        TrainingConcept.find(params[:training_concept_id]).training_examples
      else
        TrainingExample
      end
    end
  end
end
