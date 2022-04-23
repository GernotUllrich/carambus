class CreateCompetitionCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :competition_ccs do |t|
      t.integer :cc_id
      t.string :name
      t.string :context
      t.integer :branch_cc_id
      t.integer :discipline_id

      t.timestamps
    end
  end
end
