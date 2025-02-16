class AddStaffelTextToLeagues < ActiveRecord::Migration[6.1]
  def change
    add_column :leagues, :staffel_text, :string
    add_index :leagues, ["ba_id", "ba_id2"], unique: true
  end
end
