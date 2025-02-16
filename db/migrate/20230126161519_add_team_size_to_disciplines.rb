class AddTeamSizeToDisciplines < ActiveRecord::Migration[7.0]
  def change
    add_column :disciplines, :team_size, :integer
  end
end
