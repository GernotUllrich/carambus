class CreateStreamConfigurations < ActiveRecord::Migration[7.2]
  def change
    create_table :stream_configurations do |t|
      t.references :table, null: false, foreign_key: true, index: false
      t.references :location, null: false, foreign_key: true, index: false
      
      # YouTube configuration
      t.string :youtube_stream_key  # will be encrypted
      t.string :youtube_channel_id
      
      # Camera configuration
      t.string :camera_device, default: '/dev/video0'
      t.integer :camera_width, default: 1280
      t.integer :camera_height, default: 720
      t.integer :camera_fps, default: 60
      
      # Overlay configuration
      t.boolean :overlay_enabled, default: true
      t.string :overlay_position, default: 'bottom'  # top, bottom, custom
      t.integer :overlay_height, default: 200
      
      # Stream status
      t.string :status, default: 'inactive'  # inactive, starting, active, stopping, error
      t.datetime :last_started_at
      t.datetime :last_stopped_at
      t.text :error_message
      t.integer :restart_count, default: 0
      
      # Network configuration
      t.string :raspi_ip  # IP address of the scoreboard Raspberry Pi
      t.integer :raspi_ssh_port, default: 22
      
      # Stream quality settings
      t.integer :video_bitrate, default: 2000  # kbit/s
      t.integer :audio_bitrate, default: 128   # kbit/s

      t.timestamps
    end
    
    # Ensure only one stream configuration per table
    add_index :stream_configurations, :table_id, unique: true
    # Allow querying by location
    add_index :stream_configurations, :location_id
    # Allow querying by status
    add_index :stream_configurations, :status
  end
end
