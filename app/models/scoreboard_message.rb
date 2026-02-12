# frozen_string_literal: true

# == Schema Information
#
# Table name: scoreboard_messages
#
#  id                :bigint           not null, primary key
#  acknowledged_at   :datetime
#  expires_at        :datetime
#  message           :text             not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  location_id       :integer          not null
#  sender_id         :integer          not null
#  table_monitor_id  :integer
#
class ScoreboardMessage < ApplicationRecord
  belongs_to :location
  belongs_to :table_monitor, optional: true
  belongs_to :sender, class_name: 'User', foreign_key: 'sender_id'

  validates :message, presence: true, length: { minimum: 1, maximum: 500 }
  validates :location_id, presence: true
  validates :sender_id, presence: true

  before_validation :set_expires_at, on: :create

  scope :active, -> { where(acknowledged_at: nil).where('expires_at > ?', Time.current) }
  scope :expired, -> { where(acknowledged_at: nil).where('expires_at <= ?', Time.current) }
  scope :acknowledged, -> { where.not(acknowledged_at: nil) }
  scope :for_location, ->(location_id) { where(location_id: location_id) }
  scope :for_table_monitor, ->(table_monitor_id) { where('table_monitor_id = ? OR table_monitor_id IS NULL', table_monitor_id) }

  # Check if message is still active (not acknowledged and not expired)
  def active?
    acknowledged_at.nil? && expires_at > Time.current
  end

  # Check if message is expired
  def expired?
    acknowledged_at.nil? && expires_at <= Time.current
  end

  # Mark message as acknowledged
  def acknowledge!
    return false unless active?
    
    update!(acknowledged_at: Time.current)
    broadcast_acknowledgement
    true
  end

  # Broadcast to all table monitors in location (or specific table if specified)
  def broadcast_to_scoreboards
    return unless active?

    if table_monitor_id.present?
      # Broadcast to specific table monitor
      broadcast_to_table_monitor(table_monitor)
    else
      # Broadcast to all table monitors in location
      # Get table_monitors through tables (location -> tables -> table_monitor)
      location.tables.includes(:table_monitor).each do |table|
        if table.table_monitor.present?
          broadcast_to_table_monitor(table.table_monitor)
        end
      end
    end
  end

  private

  def set_expires_at
    self.expires_at ||= 30.minutes.from_now
  end

  def broadcast_to_table_monitor(table_monitor)
    ActionCable.server.broadcast(
      'table-monitor-stream',
      {
        type: 'scoreboard_message',
        message_id: id,
        table_monitor_id: table_monitor.id,
        message: message,
        expires_at: expires_at.iso8601
      }
    )
  end

  def broadcast_acknowledgement
    # Notify all scoreboards that this message was acknowledged
    if table_monitor_id.present?
      ActionCable.server.broadcast(
        'table-monitor-stream',
        {
          type: 'scoreboard_message_acknowledged',
          message_id: id,
          table_monitor_id: table_monitor_id
        }
      )
    else
      # Broadcast to all table monitors in location
      # Get table_monitors through tables (location -> tables -> table_monitor)
      location.tables.includes(:table_monitor).each do |table|
        if table.table_monitor.present?
          ActionCable.server.broadcast(
            'table-monitor-stream',
            {
              type: 'scoreboard_message_acknowledged',
              message_id: id,
              table_monitor_id: table.table_monitor.id
            }
          )
        end
      end
    end
  end
end
