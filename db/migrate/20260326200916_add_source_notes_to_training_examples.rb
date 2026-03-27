class AddSourceNotesToTrainingExamples < ActiveRecord::Migration[7.2]
  def change
    add_column :training_examples, :source_notes, :text
  end
end
