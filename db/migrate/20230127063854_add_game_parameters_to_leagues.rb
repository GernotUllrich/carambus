class AddGameParametersToLeagues < ActiveRecord::Migration[7.0]
  def change
    add_column :leagues, :game_parameters, :text
  end
end
