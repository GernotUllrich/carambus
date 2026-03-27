class ValidateParentIdForeignKey < ActiveRecord::Migration[7.2]
  def change
    validate_foreign_key :training_examples, column: :parent_id
  end
end
