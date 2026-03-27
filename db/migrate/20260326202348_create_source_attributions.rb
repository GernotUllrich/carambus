class CreateSourceAttributions < ActiveRecord::Migration[7.2]
  def change
    create_table :source_attributions do |t|
      t.references :training_source, null: false, foreign_key: true
      t.references :sourceable, polymorphic: true, null: false
      t.string :reference
      t.text :notes

      t.timestamps
    end
  end
end
