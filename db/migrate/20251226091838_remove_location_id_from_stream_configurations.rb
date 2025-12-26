class RemoveLocationIdFromStreamConfigurations < ActiveRecord::Migration[7.2]
  def change
    safety_assured { remove_reference :stream_configurations, :location, foreign_key: true, index: true }
  end
end
