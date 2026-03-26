module Admin
  class TagsController < Admin::ApplicationController
    def update
      # Save translation preference before resource_params filters it out
      should_translate = params[:tag]&.[](:translate_after_save) == '1'
      translation_method = params[:tag]&.[](:translation_method) || 'deepl'
      
      if requested_resource.update(resource_params)
        # Perform translation if requested
        if should_translate
          begin
            method_name = translation_method == 'ai' ? 'AI (Claude)' : 'DeepL mit Glossar'
            requested_resource.translate_to_target_languages!(force: true, method: translation_method)
            notice_message = "Tag wurde gespeichert und erfolgreich übersetzt (#{method_name})."
          rescue => e
            Rails.logger.error "Translation error: #{e.message}\n#{e.backtrace.join("\n")}"
            notice_message = "Tag wurde gespeichert, aber Übersetzung fehlgeschlagen: #{e.message}"
          end
        else
          notice_message = "Tag wurde erfolgreich aktualisiert."
        end
        
        redirect_to(
          admin_tag_url(requested_resource, host: request.host, port: request.port),
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
                  notice: "Tag wurde erfolgreich übersetzt."
    rescue => e
      redirect_to [:admin, requested_resource], 
                  alert: "Übersetzung fehlgeschlagen: #{e.message}"
    end
    
    def valid_action?(name, resource = resource_class)
      %w[translate].include?(name.to_s) || super
    end
  end
end
