module Admin
  class TrainingConceptsController < Admin::ApplicationController
    def update
      should_translate = params[:training_concept]&.[](:translate_after_save) == '1'
      translation_method = params[:training_concept]&.[](:translation_method) || 'deepl'
      
      if requested_resource.update(resource_params)
        if should_translate
          begin
            method_name = translation_method == 'ai' ? 'AI (Claude)' : 'DeepL mit Glossar'
            requested_resource.translate_to_target_languages!(force: true, method: translation_method)
            notice_message = "Trainingskonzept wurde gespeichert und erfolgreich übersetzt (#{method_name})."
          rescue => e
            Rails.logger.error "Translation error: #{e.message}\n#{e.backtrace.join("\n")}"
            notice_message = "Trainingskonzept wurde gespeichert, aber Übersetzung fehlgeschlagen: #{e.message}"
          end
        else
          notice_message = "Trainingskonzept wurde erfolgreich aktualisiert."
        end
        
        redirect_to(
          admin_training_concept_url(requested_resource, host: request.host, port: request.port),
          notice: notice_message
        )
      else
        render :edit, locals: {
          page: Administrate::Page::Form.new(dashboard, requested_resource),
        }, status: :unprocessable_entity
      end
    end
    
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
