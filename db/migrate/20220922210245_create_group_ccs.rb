class CreateGroupCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :group_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.string :context
      t.string :display
      t.string :status
      t.integer :branch_cc_id
      t.text :data

      t.timestamps
    end
  end
end
