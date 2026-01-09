class AddStreamDestinationToStreamConfigurations < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :stream_configurations, :stream_destination, :string, default: 'youtube', null: false
    add_column :stream_configurations, :custom_rtmp_url, :string
    add_column :stream_configurations, :custom_rtmp_key, :string
    add_column :stream_configurations, :local_rtmp_server_ip, :string
    
    add_index :stream_configurations, :stream_destination, algorithm: :concurrently
    
    # Set existing records to 'youtube' (backward compatibility)
    reversible do |dir|
      dir.up do
        StreamConfiguration.update_all(stream_destination: 'youtube')
      end
    end
  end
end
