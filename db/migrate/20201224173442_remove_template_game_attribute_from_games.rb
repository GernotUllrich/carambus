class RemoveTemplateGameAttributeFromGames < ActiveRecord::Migration[6.0]
  def change
    remove_column :games, :template_game_id
  end
end
