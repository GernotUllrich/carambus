class AddRankToSeedings < ActiveRecord::Migration[6.0]
  def change
    add_column :seedings, :rank, :integer
  end
end
