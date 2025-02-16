class CreateRegistrationCcs < ActiveRecord::Migration[6.1]
  def change
    create_table :registration_ccs do |t|
      t.integer :registration_list_cc_id
      t.integer :player_id
      t.string :status

      t.timestamps
    end
  end
end
