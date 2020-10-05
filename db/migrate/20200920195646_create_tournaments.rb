class CreateTournaments < ActiveRecord::Migration
  def change
    create_table :tournaments do |t|
      t.string :title
      t.integer :discipline_id
      t.string :modus
      t.string :age_restriction
      t.datetime :date
      t.datetime :accredation_end
      t.text :location
      t.integer :hosting_club_id

      t.timestamps null: false
    end
  end
end
