class CreateWordles < ActiveRecord::Migration[6.1]
  def change
    create_table :wordles do |t|
      t.text :words
      t.text :hints
      t.text :data
      t.integer :seqno

      t.timestamps
    end
  end
end
