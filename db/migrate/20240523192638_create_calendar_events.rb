class CreateCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_events do |t|
      t.string :summary
      t.boolean :recurring
      t.integer :location_id
      t.datetime :event_start
      t.datetime :event_end

      t.timestamps
    end
  end
end
