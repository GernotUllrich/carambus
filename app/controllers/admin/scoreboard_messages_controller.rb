# frozen_string_literal: true

module Admin
  class ScoreboardMessagesController < ApplicationController
    before_action :authenticate_user!
    before_action :check_permissions
    before_action :set_message, only: [:show, :edit, :update, :destroy]

    def index
      @messages = ScoreboardMessage
                    .includes(:location, :table_monitor, :sender)
                    .order(created_at: :desc)
                    .page(params[:page])
                    .per(20)

      # Filter by status if requested
      @messages = case params[:status]
                  when 'active'
                    @messages.active
                  when 'acknowledged'
                    @messages.acknowledged
                  when 'expired'
                    @messages.expired
                  else
                    @messages
                  end
    end

    def new
      @message = ScoreboardMessage.new
      load_form_data
    end

    def create
      @message = ScoreboardMessage.new(message_params)
      @message.sender = current_user

      if @message.save
        # Broadcast to scoreboards
        @message.broadcast_to_scoreboards

        flash[:notice] = 'Message sent successfully to scoreboard(s).'
        redirect_to admin_scoreboard_messages_path
      else
        load_form_data
        render :new
      end
    end

    def show
    end

    def edit
      load_form_data
    end

    def update
      if @message.update(message_params)
        flash[:notice] = 'Message updated successfully.'
        redirect_to admin_scoreboard_messages_path
      else
        load_form_data
        render :edit
      end
    end

    def destroy
      @message.destroy
      flash[:notice] = 'Message deleted successfully.'
      redirect_to admin_scoreboard_messages_path
    end

    # Acknowledge a message via AJAX from admin interface
    def acknowledge
      @message = ScoreboardMessage.find(params[:id])
      
      if @message.acknowledge!
        render json: { success: true, message: 'Message acknowledged' }
      else
        render json: { success: false, message: 'Failed to acknowledge message' }, status: :unprocessable_entity
      end
    end

    private

    def set_message
      @message = ScoreboardMessage.find(params[:id])
    end

    def check_permissions
      unless current_user.club_admin? || current_user.system_admin?
        flash[:alert] = 'You do not have permission to access this page.'
        redirect_to admin_root_path
      end
    end

    def message_params
      params.require(:scoreboard_message).permit(:message, :location_id, :table_monitor_id)
    end

    def load_form_data
      # Load locations for dropdown
      @locations = Location.order(:name)
      
      # Load table monitors grouped by location
      @table_monitors_by_location = TableMonitor
                                      .joins(:table)
                                      .includes(table: :location)
                                      .group_by { |tm| tm.table.location }
    end
  end
end
