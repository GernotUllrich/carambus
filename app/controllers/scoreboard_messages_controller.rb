# frozen_string_literal: true

# Public controller for scoreboard message acknowledgements
# This allows scoreboards to acknowledge messages without admin authentication
class ScoreboardMessagesController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:acknowledge]
  
  # POST /scoreboard_messages/:id/acknowledge
  def acknowledge
    @message = ScoreboardMessage.find(params[:id])
    
    if @message.acknowledge!
      render json: { 
        success: true, 
        message: 'Message acknowledged',
        acknowledged_at: @message.acknowledged_at
      }
    else
      render json: { 
        success: false, 
        message: 'Failed to acknowledge message or message already acknowledged/expired' 
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { 
      success: false, 
      message: 'Message not found' 
    }, status: :not_found
  end
end
