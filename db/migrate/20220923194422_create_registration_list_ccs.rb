class CreateRegistrationListCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :registration_list_ccs do |t|
      t.integer :cc_id
      t.string :context
      t.string :name
      t.integer :branch_cc_id
      t.integer :season_id
      t.integer :discipline_id
      t.integer :category_cc_id
      t.datetime :deadline
      t.datetime :qualifying_date
      t.text :data
      t.string :status

      t.timestamps
    end
  end
end
