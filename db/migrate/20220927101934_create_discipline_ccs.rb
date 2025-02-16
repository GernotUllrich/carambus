class CreateDisciplineCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :discipline_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.integer :discipline_id
      t.integer :branch_cc_id
      t.string :context

      t.timestamps
    end
  end
end
