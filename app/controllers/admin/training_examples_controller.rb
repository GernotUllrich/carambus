module Admin
  class TrainingExamplesController < Admin::ApplicationController
    before_action :set_training_concept, only: [:new, :create]
    
    # Only allow "new" action when nested under a training_concept
    def valid_action?(name, resource = resource_class)
      return false if name == :new && params[:training_concept_id].blank?
      super
    end
    
    private
    
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
