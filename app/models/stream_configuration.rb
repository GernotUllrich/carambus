# frozen_string_literal: true

# == Schema Information
#
# Table name: stream_configurations
#
#  id                  :bigint           not null, primary key
#  audio_bitrate       :integer          default(128)
#  camera_device       :string           default("/dev/video0")
#  camera_fps          :integer          default(60)
#  camera_height       :integer          default(720)
#  camera_width        :integer          default(1280)
#  error_message       :text
#  last_started_at     :datetime
#  last_stopped_at     :datetime
#  overlay_enabled     :boolean          default(TRUE)
#  overlay_height      :integer          default(200)
#  overlay_position    :string           default("bottom")
#  raspi_ip            :string
#  raspi_ssh_port      :integer          default(22)
#  restart_count       :integer          default(0)
#  status              :string           default("inactive")
#  video_bitrate       :integer          default(2000)
#  youtube_channel_id  :string
#  youtube_stream_key  :string
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  table_id            :bigint           not null
#
# Indexes
#
#  index_stream_configurations_on_status       (status)
#  index_stream_configurations_on_table_id     (table_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (table_id => tables.id)
#
# Note: location is accessed via table association (has_one :location, through: :table)
#
class StreamConfiguration < ApplicationRecord
  include ApiProtector  # Only exists on Local Servers, never on API Server
  
  # Ignore removed columns for safe deployment
  self.ignored_columns = ["location_id"]
  
  # Associations
  belongs_to :table
  has_one :location, through: :table
  
  # Encryption for sensitive data
  encrypts :youtube_stream_key, deterministic: false
  encrypts :custom_rtmp_key, deterministic: false
  
  # Validations
  validates :stream_destination, inclusion: { in: %w[youtube local custom] }, presence: true
  validates :youtube_stream_key, presence: true, if: -> { stream_destination == 'youtube' && (active? || starting?) }
  validates :custom_rtmp_url, presence: true, if: -> { stream_destination == 'custom' && (active? || starting?) }
  validates :local_rtmp_server_ip, presence: true, if: -> { stream_destination == 'local' && (active? || starting?) }
  validates :status, inclusion: { in: %w[inactive starting active stopping error] }
  validates :overlay_position, inclusion: { in: %w[top bottom custom] }
  validates :camera_device, presence: true
  validates :camera_width, numericality: { greater_than: 0 }
  validates :camera_height, numericality: { greater_than: 0 }
  validates :camera_fps, numericality: { greater_than: 0, less_than_or_equal_to: 60 }
  validates :video_bitrate, numericality: { greater_than: 0 }
  validates :audio_bitrate, numericality: { greater_than: 0 }
  validates :raspi_ip, presence: true, format: { with: /\A\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\z/, message: "must be a valid IP address" }, if: :ip_required?
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :inactive, -> { where(status: 'inactive') }
  scope :with_errors, -> { where(status: 'error') }
  scope :by_location, ->(location_id) { joins(:table).where(tables: { location_id: location_id }) }
  
  # Callbacks
  before_validation :set_raspi_ip_from_table, if: -> { raspi_ip.blank? && table.present? }
  after_initialize :set_defaults, if: :new_record?
  after_save :broadcast_status_change, if: -> { saved_change_to_status? || saved_change_to_error_message? || saved_change_to_last_started_at? }
  
  # Status helper methods
  def inactive?
    status == 'inactive'
  end
  
  def active?
    status == 'active'
  end
  
  def starting?
    status == 'starting'
  end
  
  def stopping?
    status == 'stopping'
  end
  
  def error?
    status == 'error'
  end
  
  def operational?
    active? || starting?
  end
  
  # Stream control methods
  def start_streaming
    return false unless inactive? || error?
    
    update(status: 'starting', error_message: nil)
    StreamControlJob.perform_later(id, 'start')
    true
  end
  
  def stop_streaming
    return false unless operational?
    
    update(status: 'stopping')
    StreamControlJob.perform_later(id, 'stop')
    true
  end
  
  def restart_streaming
    if operational?
      stop_streaming
      # Will be restarted by a separate call after stop completes
    else
      start_streaming
    end
  end
  
  def check_health
    StreamHealthJob.perform_later(id)
  end
  
  # Mark stream as successfully started
  def mark_started!
    update!(
      status: 'active',
      last_started_at: Time.current,
      error_message: nil,
      restart_count: 0
    )
  end
  
  # Mark stream as successfully stopped
  def mark_stopped!
    update!(
      status: 'inactive',
      last_stopped_at: Time.current,
      error_message: nil
    )
  end
  
  # Mark stream as failed
  def mark_failed!(error_msg)
    increment!(:restart_count)
    update!(
      status: 'error',
      error_message: error_msg
    )
  end
  
  # Get the scoreboard overlay URL
  def scoreboard_overlay_url
    return nil unless location.present? && table.present?
    
    # Determine host - use localhost if on the same machine, otherwise location URL
    host = ApplicationRecord.local_server? ? 'localhost' : location.url
    
    # Determine port from Rails server configuration
    # Try to get from action_mailer default_url_options first (most reliable)
    port = if Rails.application.config.action_mailer.default_url_options.present? &&
              Rails.application.config.action_mailer.default_url_options[:port].present?
      Rails.application.config.action_mailer.default_url_options[:port]
    elsif ENV['PORT'].present?
      ENV['PORT']
    elsif Rails.env.production?
      # Fallback for production: check common ports
      # For Raspberry Pi development server, typically 3131
      3131
    else
      3000
    end
    
    "http://#{host}:#{port}/locations/#{location.md5}/scoreboard_overlay?table_id=#{table.id}"
  end
  
  # Get RTMP URL based on stream destination
  def rtmp_url
    case stream_destination
    when 'youtube'
      youtube_rtmp_url
    when 'local'
      local_rtmp_url
    when 'custom'
      custom_rtmp_url_complete
    else
      raise "Unknown stream destination: #{stream_destination}"
    end
  end
  
  # Get stream uptime
  def uptime
    return nil unless active? && last_started_at.present?
    
    Time.current - last_started_at
  end
  
  # Format uptime as human readable string
  def uptime_humanized
    return "Not streaming" unless active?
    return "Just started" unless last_started_at.present?
    
    seconds = uptime.to_i
    hours = seconds / 3600
    minutes = (seconds % 3600) / 60
    
    if hours > 0
      "#{hours}h #{minutes}m"
    else
      "#{minutes}m"
    end
  end
  
  # Check if too many restart attempts
  def too_many_restarts?
    restart_count > 5
  end
  
  private
  
  # Get YouTube RTMP URL
  def youtube_rtmp_url
    return nil if youtube_stream_key.blank?
    "rtmp://a.rtmp.youtube.com/live2/#{youtube_stream_key}"
  end
  
  # Get local RTMP server URL (Mac mini/Laptop running Docker RTMP)
  def local_rtmp_url
    return nil if local_rtmp_server_ip.blank?
    
    # Stream name format: table<ID> (e.g., table1, table2)
    # This makes it easy to identify in OBS
    # Using '/stream' application (as configured in alfg/nginx-rtmp Docker image)
    "rtmp://#{local_rtmp_server_ip}:1935/stream/table#{table.id}"
  end
  
  # Get custom RTMP URL (user-specified)
  def custom_rtmp_url_complete
    return nil if custom_rtmp_url.blank?
    
    # If custom_rtmp_key is provided, append it to URL
    if custom_rtmp_key.present?
      "#{custom_rtmp_url}/#{custom_rtmp_key}"
    else
      custom_rtmp_url
    end
  end
  
  def set_defaults
    self.status ||= 'inactive'
    self.stream_destination ||= 'youtube'
    self.camera_device ||= '/dev/video0'
    self.camera_width ||= 1280
    self.camera_height ||= 720
    self.camera_fps ||= 60
    self.overlay_enabled = true if overlay_enabled.nil?
    self.overlay_position ||= 'bottom'
    self.overlay_height ||= 200
    self.video_bitrate ||= 2000
    self.audio_bitrate ||= 128
    self.raspi_ssh_port ||= 22
    self.restart_count ||= 0
  end
  
  def set_raspi_ip_from_table
    self.raspi_ip = table.ip_address if table.ip_address.present?
  end
  
  def ip_required?
    # IP is required unless we're just creating the record
    persisted? || operational?
  end
  
  # Broadcast status changes to ActionCable
  def broadcast_status_change
    ActionCable.server.broadcast(
      "stream_status",
      {
        stream_id: id,
        status: status,
        last_started_at: last_started_at&.iso8601,
        error_message: error_message
      }
    )
  end
end

