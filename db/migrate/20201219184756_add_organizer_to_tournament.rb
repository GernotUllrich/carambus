class AddOrganizerToTournament < ActiveRecord::Migration[6.0]
  def change
    add_column :tournaments, :organizer_id, :integer
    add_column :tournaments, :organizer_type, :string
    add_column :tournaments, :location_id, :integer
  end
end
