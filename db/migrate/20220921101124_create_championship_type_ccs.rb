class CreateChampionshipTypeCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :championship_type_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.string :shortname
      t.string :context
      t.integer :branch_cc_id
      t.string :status

      t.timestamps
    end
  end
end
