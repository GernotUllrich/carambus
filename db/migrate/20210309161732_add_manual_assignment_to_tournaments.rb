class AddManualAssignmentToTournaments < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :manual_assignment, :boolean, default: false
  end
end
