class AddTranslationFieldsToPages < ActiveRecord::Migration[7.0]
  def change
    add_column :pages, :last_translated_at, :datetime
  end
end
