class CreateUploads < ActiveRecord::Migration[7.0]
  def change
    create_table :uploads do |t|
      t.string :filename
      t.integer :user_id
      t.integer :position

      t.timestamps
    end
  end
end
