class AddTimerJobIdToTableMonitors < ActiveRecord::Migration[6.1]
  def change
    add_column :table_monitors, :timer_job_id, :string
  end
end
