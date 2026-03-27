module Admin
  class TrainingSourcesController < Admin::ApplicationController
    def create
      resource = resource_class.new(resource_params)
      
      if resource.save
        redirect_to(
          admin_training_source_url(resource, host: request.host, port: request.port),
          notice: "#{resource_class.name} wurde erfolgreich erstellt."
        )
      else
        render :new, locals: {
          page: Administrate::Page::Form.new(dashboard, resource),
        }, status: :unprocessable_entity
      end
    end
    
    def update
      # Extract source_files before update to handle them separately
      new_files = params[resource_name]&.delete(:source_files)
      
      if requested_resource.update(resource_params)
        # Attach new files without removing existing ones
        if new_files.present? && new_files.reject(&:blank?).any?
          requested_resource.source_files.attach(new_files.reject(&:blank?))
        end
        
        redirect_to(
          admin_training_source_url(requested_resource, host: request.host, port: request.port),
          notice: "#{resource_class.name} wurde erfolgreich aktualisiert."
        )
      else
        render :edit, locals: {
          page: Administrate::Page::Form.new(dashboard, requested_resource),
        }, status: :unprocessable_entity
      end
    end
    
    def delete_attachment
      attachment = requested_resource.source_files.find(params[:attachment_id])
      filename = attachment.filename.to_s
      
      attachment.purge
      
      redirect_to(
        admin_training_source_url(requested_resource, host: request.host, port: request.port),
        notice: "Datei '#{filename}' wurde gelöscht."
      )
    end
    
    private
    
    def resource_params
      params.require(resource_name)
            .permit(dashboard.permitted_attributes, source_files: [])
    end
  end
end
