# frozen_string_literal: true

# Ligen-Reihen: Ligen einer Reihe tragen nach der Bereinigung den jüngsten Namen;
# frühere Namen bleiben hier zeilengetrennt erhalten (eigener Ursprungsname zuerst, wie Club#synonyms).
class AddSynonymsToLeagues < ActiveRecord::Migration[7.2]
  def change
    add_column :leagues, :synonyms, :text
  end
end
