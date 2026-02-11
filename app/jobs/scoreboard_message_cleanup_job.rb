# frozen_string_literal: true

# Background job to clean up expired scoreboard messages
# Runs periodically to broadcast acknowledgement for expired messages
# so they disappear from all scoreboards
class ScoreboardMessageCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # Find all expired messages that haven't been acknowledged yet
    expired_messages = ScoreboardMessage.expired

    if expired_messages.any?
      Rails.logger.info "[ScoreboardMessageCleanup] Found #{expired_messages.count} expired messages to clean up"

      expired_messages.each do |message|
        Rails.logger.info "[ScoreboardMessageCleanup] Acknowledging expired message ##{message.id}"
        
        # Mark as acknowledged (this will also broadcast the acknowledgement)
        message.update!(acknowledged_at: Time.current)
        
        # Broadcast acknowledgement to hide on all scoreboards
        if message.table_monitor_id.present?
          ActionCable.server.broadcast(
            'table-monitor-stream',
            {
              type: 'scoreboard_message_acknowledged',
              message_id: message.id,
              table_monitor_id: message.table_monitor_id,
              reason: 'auto_expired'
            }
          )
        else
          # Broadcast to all table monitors in location
          message.location.table_monitors.each do |tm|
            ActionCable.server.broadcast(
              'table-monitor-stream',
              {
                type: 'scoreboard_message_acknowledged',
                message_id: message.id,
                table_monitor_id: tm.id,
                reason: 'auto_expired'
              }
            )
          end
        end
      end
    else
      Rails.logger.debug "[ScoreboardMessageCleanup] No expired messages to clean up"
    end
  end
end
