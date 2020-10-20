class CreateGroupExecutors < ActiveRecord::Migration
  def change
    create_table :group_executors do |t|
      t.string :state

      t.timestamps null: false
    end
  end
end
