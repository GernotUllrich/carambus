class CreateDebugInfos < ActiveRecord::Migration[6.0]
  def change
    create_table :debug_infos do |t|
      t.string :info

      t.timestamps
    end
  end
end
