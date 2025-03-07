class SetDefaultStatusForPages < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    safety_assured do
      # Zuerst sicherstellen, dass wir die richtige Spaltenart haben
      change_column :pages, :status, :string

      # Dann alle nil-Werte auf 'draft' setzen
      execute("UPDATE pages SET status = 'draft' WHERE status IS NULL")

      # Standardwert setzen
      change_column_default :pages, :status, 'draft'
    end
  end
end
