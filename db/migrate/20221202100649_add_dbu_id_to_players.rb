class AddDbuIdToPlayers < ActiveRecord::Migration[7.0]
  def change
    add_column :players, :dbu_nr, :integer
    add_column :players, :dbu_pass_nr, :integer
    add_column :players, :fl_name, :string
    add_column :clubs, :dbu_nr, :integer
    add_column :regions, :dbu_name, :string
    add_column :regions, :telefon, :string
    add_column :regions, :fax, :string
    add_column :regions, :website, :string
    add_column :regions, :opening, :string
  end
end
