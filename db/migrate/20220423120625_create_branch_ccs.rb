class CreateBranchCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :branch_ccs do |t|
      t.integer :cc_id
      t.string :context
      t.integer :region_cc_id
      t.integer :discipline_id
      t.string :name

      t.timestamps
    end
  end
end
