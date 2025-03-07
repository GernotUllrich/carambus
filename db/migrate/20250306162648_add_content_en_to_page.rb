class AddContentEnToPage < ActiveRecord::Migration[7.2]
  def change
    add_column :pages, :content_en, :string
  end
end
