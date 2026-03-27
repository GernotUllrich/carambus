class CreateTrainingSources < ActiveRecord::Migration[7.2]
  def change
    create_table :training_sources do |t|
      t.string :title
      t.string :author
      t.integer :publication_year
      t.string :publisher
      t.string :language
      t.text :notes

      t.timestamps
    end
  end
end
