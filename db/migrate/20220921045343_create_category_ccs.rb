class CreateCategoryCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :category_ccs do |t|
      t.string :context
      t.integer :max_age
      t.integer :min_age
      t.string :name
      t.string :sex
      t.string :status
      t.integer :cc_id
      t.integer :branch_cc_id

      t.timestamps
    end
  end
end
