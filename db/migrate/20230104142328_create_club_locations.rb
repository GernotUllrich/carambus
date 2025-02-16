class CreateClubLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :club_locations do |t|
      t.integer :club_id
      t.integer :location_id
      t.string :status

      t.timestamps
    end
    # Location.joins(:club).each do |location|
    #   ClubLocation.create(club_id: location.club_id, location_id: location.id)
    # end
  end
end
