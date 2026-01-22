class AddCameraManualSettingsToStreamConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :stream_configurations, :focus_auto, :integer, default: 0
    # 0 = manual (prevents auto-focus), 1 = auto
    add_column :stream_configurations, :exposure_auto, :integer, default: 1
    # 1 = manual (prevents auto-exposure), 3 = auto
    add_column :stream_configurations, :focus_absolute, :integer
    # Manual focus value (0-250, step=5, optional)
    add_column :stream_configurations, :exposure_absolute, :integer
    # Manual exposure value (3-2047, optional, default: 250)
    add_column :stream_configurations, :brightness, :integer
    # Brightness (0-255, optional, default: 128)
    add_column :stream_configurations, :contrast, :integer
    # Contrast (0-255, optional, default: 128)
    add_column :stream_configurations, :saturation, :integer
    # Saturation (0-255, optional, default: 128)
  end
end
