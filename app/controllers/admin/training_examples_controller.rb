module Admin
  class TrainingExamplesController < Admin::ApplicationController
    before_action :set_training_concept, only: [:new, :create]
    
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
