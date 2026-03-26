module Admin
  class TrainingExamplesController < Admin::ApplicationController
    before_action :set_training_concept, only: [:new, :create]
    
    # Override Administrate's before_action to skip finding resource for index and new
    def requested_resource
      if action_name == "new" || action_name == "index"
        nil
      else
        super
      end
    end
    
    # TrainingExamples können nur über TrainingConcepts erstellt werden
    def valid_action?(name, resource = resource_class)
      # "new" ist nur gültig, wenn wir von einem TrainingConcept kommen
      return false if name.to_s == 'new' && params[:training_concept_id].blank?
      # Sortier-Actions erlauben
      return true if %w[move_up move_down].include?(name.to_s)
      super
    end
    
    def new
      if params[:training_concept_id].blank?
        redirect_to admin_training_concepts_path, 
                    alert: "Trainingsbeispiele müssen über ein Trainingskonzept erstellt werden."
        return
      end
      super
    end
    
    def update
      should_translate = params[:training_example]&.[](:translate_after_save) == '1'
      translation_method = params[:training_example]&.[](:translation_method) || 'deepl'
      
      if requested_resource.update(resource_params)
        if should_translate
          begin
            method_name = translation_method == 'ai' ? 'AI (Claude)' : 'DeepL mit Glossar'
            requested_resource.translate_to_target_languages!(force: true, method: translation_method)
            notice_message = "Trainingsbeispiel wurde gespeichert und erfolgreich übersetzt (#{method_name})."
          rescue => e
            Rails.logger.error "Translation error: #{e.message}\n#{e.backtrace.join("\n")}"
            notice_message = "Trainingsbeispiel wurde gespeichert, aber Übersetzung fehlgeschlagen: #{e.message}"
          end
        else
          notice_message = "Trainingsbeispiel wurde erfolgreich aktualisiert."
        end
        
        redirect_to(
          admin_training_example_url(requested_resource, host: request.host, port: request.port),
          notice: notice_message
        )
      else
        render :edit, locals: {
          page: Administrate::Page::Form.new(dashboard, requested_resource),
        }, status: :unprocessable_entity
      end
    end
    
    def move_up
      example = requested_resource
      training_concept = example.training_concept
      examples = training_concept.training_examples.order(:sequence_number)
      current_index = examples.index(example)
      
      if current_index && current_index > 0
        # Swap sequence numbers with previous example
        prev_example = examples[current_index - 1]
        example_seq = example.sequence_number
        example.update_column(:sequence_number, prev_example.sequence_number)
        prev_example.update_column(:sequence_number, example_seq)
        
        redirect_to admin_training_concept_path(training_concept), 
                    notice: "Reihenfolge aktualisiert."
      else
        redirect_to admin_training_concept_path(training_concept), 
                    alert: "Kann nicht nach oben verschoben werden."
      end
    end
    
    def move_down
      example = requested_resource
      training_concept = example.training_concept
      examples = training_concept.training_examples.order(:sequence_number)
      current_index = examples.index(example)
      
      if current_index && current_index < examples.size - 1
        # Swap sequence numbers with next example
        next_example = examples[current_index + 1]
        example_seq = example.sequence_number
        example.update_column(:sequence_number, next_example.sequence_number)
        next_example.update_column(:sequence_number, example_seq)
        
        redirect_to admin_training_concept_path(training_concept), 
                    notice: "Reihenfolge aktualisiert."
      else
        redirect_to admin_training_concept_path(training_concept), 
                    alert: "Kann nicht nach unten verschoben werden."
      end
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
