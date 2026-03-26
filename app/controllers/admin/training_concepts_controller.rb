module Admin
  class TrainingConceptsController < Admin::ApplicationController
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
  end
end
