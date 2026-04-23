module Admin
  class ShotsController < Admin::ApplicationController
    before_action :set_training_example, only: [:new, :create]

    # Override Administrate's before_action to skip finding resource for index and new
    def requested_resource
      if action_name == "new" || action_name == "index"
        nil
      else
        super
      end
    end

    # Shots können nur über TrainingExamples erstellt werden
    def valid_action?(name, resource = resource_class)
      # "new" ist nur gültig, wenn wir von einem TrainingExample kommen
      return false if name.to_s == "new" && params[:training_example_id].blank?
      super
    end

    # Administrate enumeriert fuer den Namespace ALLE /admin/shots-Routen,
    # inkl. der nested :new unter /admin/training_examples/:id/shots/new.
    # Dadurch haelt es `accessible_action?(:new)` fuer true, rendert im
    # Index-Header aber `new_admin_shot_path` — das existiert nicht, weil
    # der Standalone-Mount `only: [:index]` ist. Wir suppressen daher den
    # "new"-Button auf der Top-Level-Index-Page.
    def existing_action?(resource, action_name)
      return false if action_name.to_s == "new" && params[:training_example_id].blank?
      super
    end
    helper_method :existing_action?

    # Override destroy to redirect to parent TrainingExample
    def destroy
      training_example_id = requested_resource.training_example_id
      
      if requested_resource.destroy
        redirect_to(
          admin_training_example_url(training_example_id, host: request.host, port: request.port),
          notice: translate_with_resource("destroy.success")
        )
      else
        redirect_back(
          fallback_location: admin_shots_url(host: request.host, port: request.port),
          alert: requested_resource.errors.full_messages.join("<br/>")
        )
      end
    end
    
    # Override create to handle translation
    def create
      resource = Shot.new(resource_params)
      
      if resource.save
        # Handle translation if requested
        if params[:translate_after_save] == '1'
          translation_method = params[:translation_method] || 'deepl'
          begin
            resource.translate_to_target_languages!(method: translation_method, force: true)
            flash[:notice] = "Shot created and translations updated successfully."
          rescue => e
            flash[:alert] = "Shot created, but translation failed: #{e.message}"
          end
        end
        
        redirect_to(
          admin_training_example_url(resource.training_example_id, host: request.host, port: request.port),
          notice: flash[:notice] || translate_with_resource("create.success")
        )
      else
        render :new, locals: { page: Administrate::Page::Form.new(dashboard, resource) }
      end
    end
    
    # Override update to handle translation
    def update
      translate_after_save = params.delete(:translate_after_save)
      translation_method = params.delete(:translation_method)
      
      if requested_resource.update(resource_params)
        # Handle translation if requested
        if translate_after_save == '1'
          begin
            requested_resource.translate_to_target_languages!(method: translation_method || 'deepl', force: true)
            flash[:notice] = "Shot updated and translations synced successfully."
          rescue => e
            flash[:alert] = "Shot updated, but translation failed: #{e.message}"
          end
        end
        
        redirect_to(
          admin_shot_url(requested_resource, host: request.host, port: request.port),
          notice: flash[:notice] || translate_with_resource("update.success")
        )
      else
        render :edit, locals: { page: Administrate::Page::Form.new(dashboard, requested_resource) }
      end
    end
    
    # Move shot up in sequence
    def move_up
      shot = requested_resource
      previous_shot = shot.training_example.shots.where('sequence_number < ?', shot.sequence_number).order(sequence_number: :desc).first
      
      if previous_shot
        Shot.transaction do
          temp_seq = shot.sequence_number
          shot.update!(sequence_number: previous_shot.sequence_number)
          previous_shot.update!(sequence_number: temp_seq)
        end
        flash[:notice] = "Shot moved up"
      else
        flash[:alert] = "Shot is already at the top"
      end
      
      redirect_to admin_training_example_url(shot.training_example_id, host: request.host, port: request.port)
    end
    
    # Move shot down in sequence
    def move_down
      shot = requested_resource
      next_shot = shot.training_example.shots.where('sequence_number > ?', shot.sequence_number).order(sequence_number: :asc).first
      
      if next_shot
        Shot.transaction do
          temp_seq = shot.sequence_number
          shot.update!(sequence_number: next_shot.sequence_number)
          next_shot.update!(sequence_number: temp_seq)
        end
        flash[:notice] = "Shot moved down"
      else
        flash[:alert] = "Shot is already at the bottom"
      end
      
      redirect_to admin_training_example_url(shot.training_example_id, host: request.host, port: request.port)
    end
    
    private
    
    def set_training_example
      @training_example = TrainingExample.find(params[:training_example_id]) if params[:training_example_id]
    end
    
    def resource_params
      params.require(resource_name).permit(
        dashboard.permitted_attributes,
        :shot_image
      )
    end
  end
end
