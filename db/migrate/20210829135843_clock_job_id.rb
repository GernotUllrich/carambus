class ClockJobId < ActiveRecord::Migration[6.0]
  def change
    add_column :table_monitors, :clock_job_id, :string
  end
end
