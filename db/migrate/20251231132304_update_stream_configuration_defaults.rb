class UpdateStreamConfigurationDefaults < ActiveRecord::Migration[7.2]
  def change
    # Reduce defaults for Raspberry Pi 4 performance
    # 640x360@30fps with 1000 kbps is much more achievable
    change_column_default :stream_configurations, :camera_width, from: 1280, to: 640
    change_column_default :stream_configurations, :camera_height, from: 720, to: 360
    change_column_default :stream_configurations, :camera_fps, from: 60, to: 30
    change_column_default :stream_configurations, :video_bitrate, from: 2000, to: 1000
  end
end
