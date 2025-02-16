class AddSomeMoreAttributesToParty < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :manual_assignment, :boolean
    add_column :seedings, :tournament_type, :string
    Seeding.where.not(tournament_id: nil).update_all(tournament_type: "Tournament")
  end
end
