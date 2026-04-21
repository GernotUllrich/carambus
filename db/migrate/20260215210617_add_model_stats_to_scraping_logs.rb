class AddModelStatsToScrapingLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :scraping_logs, :model_stats, :jsonb, default: {} unless column_exists?(:scraping_logs, :model_stats)
    add_index :scraping_logs, :model_stats, using: :gin, algorithm: :concurrently unless index_exists?(:scraping_logs, :model_stats)
  end
end
