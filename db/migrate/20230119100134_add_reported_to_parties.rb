class AddReportedToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :reported_at, :datetime
    add_column :parties, :reported_by_player_id, :integer
    add_column :parties, :reported_by, :string
    add_column :parties, :party_no, :integer
  end
end
