class AddRegisterToParties < ActiveRecord::Migration[6.1]
  def change
    add_column :parties, :register_at, :date
    add_column :parties, :group, :string
    add_column :parties, :round, :string
    add_column :parties, :status, :integer
    add_column :parties, :time, :datetime
    add_column :party_ccs, :register_at, :date
    add_column :party_ccs, :group, :string
    add_column :party_ccs, :round, :string
    add_column :party_ccs, :status, :integer
    add_column :party_ccs, :time, :datetime
    add_column :party_ccs, :match_id, :integer
  end
end
