# frozen_string_literal: true

# Controller for WebSocket connection health checks
# Allows clients to verify their ActionCable connection is still alive
class CableHealthController < ApplicationController
  skip_before_action :verify_authenticity_token

  # GET /cable/health
  # Returns connection health status
  def show
    render json: {
      status: 'healthy',
      server_time: Time.current.to_i,
      connections: connection_stats
    }
  end

  # POST /cable/health/check
  # Check if a specific connection token is active
  def check
    connection_token = params[:token]
    
    if connection_token.blank?
      render json: { error: 'Token required' }, status: :bad_request
      return
    end

    active = connection_active?(connection_token)
    
    render json: {
      healthy: active,
      token: connection_token,
      server_time: Time.current.to_i,
      message: active ? 'Connection is active' : 'Connection not found'
    }
  end

  private

  def connection_stats
    {
      total: ActionCable.server.connections.size,
      active_channels: redis_subscriber_count
    }
  end

  def connection_active?(token)
    # Check if any active connection has this token
    ActionCable.server.connections.any? do |conn|
      conn.connection_identifier.include?(token)
    rescue StandardError
      false
    end
  end

  def redis_subscriber_count
    # Get count of subscribers on table-monitor-stream
    redis = Redis.new(url: redis_url)
    result = redis.pubsub('numsub', 'table-monitor-stream')
    result[1].to_i
  rescue StandardError => e
    Rails.logger.error "Failed to get Redis subscriber count: #{e.message}"
    0
  end

  def redis_url
    config = Rails.application.config_for(:cable)
    config['url'] || ENV.fetch('REDIS_URL', 'redis://localhost:6379/1')
  end
end


