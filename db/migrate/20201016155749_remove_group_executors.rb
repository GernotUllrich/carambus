class RemoveGroupExecutors < ActiveRecord::Migration
  def change
    drop_table :group_executors
  end
end
