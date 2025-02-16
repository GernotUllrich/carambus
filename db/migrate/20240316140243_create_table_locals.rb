class CreateTableLocals < ActiveRecord::Migration[7.0]
  def change
    create_table :table_locals do |t|
      t.string :tpl_ip_address
      t.string :ip_address
      t.integer :table_id

      t.timestamps
    end
  end
end
