class AddPerspectiveCorrectionToStreamConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :stream_configurations, :perspective_enabled, :boolean, default: false
    add_column :stream_configurations, :perspective_coords, :string
    # Format: "x0:y0:x1:y1:x2:y2:x3:y3" (8 coordinates for 4 corners)
    # Coordinates can be in pixels or use W/H for width/height
    # Example: "0:0:W:0:W:H:0:H" (no correction, full frame)
    # Example: "10:5:90:5:95:95:5:95" (slight correction in percentages)
  end
end
