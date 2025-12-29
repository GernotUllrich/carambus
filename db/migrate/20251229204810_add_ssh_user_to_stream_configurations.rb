class AddSshUserToStreamConfigurations < ActiveRecord::Migration[7.2]
  def change
    add_column :stream_configurations, :raspi_ssh_user, :string, default: 'pi'
  end
end
