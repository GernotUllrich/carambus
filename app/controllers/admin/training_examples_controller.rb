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
    
    def destroy
      # v0.9 Phase D: TrainingExample ↔ TrainingConcept ist jetzt M2M
      # (training_concept_examples mit weight + sequence_number). Es gibt
      # keinen eindeutigen Parent-Concept mehr, daher Redirect zum Index.
      if requested_resource.destroy
        redirect_to admin_training_examples_path,
                    notice: "Trainingsbeispiel wurde erfolgreich gelöscht."
      else
        redirect_to admin_training_example_url(requested_resource, host: request.host, port: request.port),
                    alert: "Trainingsbeispiel konnte nicht gelöscht werden: #{requested_resource.errors.full_messages.join(', ')}"
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
    
    def resource_params
      params.require(resource_name).permit(
        dashboard.permitted_attributes,
        source_attributions_attributes: [:id, :training_source_id, :reference, :notes, :_destroy]
      ).tap do |whitelisted|
        whitelisted[:tag_list] = params[resource_name][:tag_list] if params[resource_name][:tag_list]
      end
    end
  end
end
