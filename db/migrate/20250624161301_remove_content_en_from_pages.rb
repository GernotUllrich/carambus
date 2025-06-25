class RemoveContentEnFromPages < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured {
      remove_column :pages, :content_en, :string
    }
  end
end
