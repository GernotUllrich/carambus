module Admin
  class TagsController < Admin::ApplicationController
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
