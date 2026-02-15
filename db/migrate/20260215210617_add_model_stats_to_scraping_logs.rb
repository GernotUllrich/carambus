class AddModelStatsToScrapingLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :scraping_logs, :model_stats, :jsonb, default: {}
    add_index :scraping_logs, :model_stats, using: :gin, algorithm: :concurrently
  end
end
