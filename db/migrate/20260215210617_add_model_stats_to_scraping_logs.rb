class AddModelStatsToScrapingLogs < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!
  
  def change
    add_column :scraping_logs, :model_stats, :jsonb, default: {} unless column_exists?(:scraping_logs, :model_stats)
    
    # In test environment: normal index (concurrent not supported in transactions)
    # In production: concurrent index (safe for live database)
    if Rails.env.test?
      add_index :scraping_logs, :model_stats, using: :gin unless index_exists?(:scraping_logs, :model_stats)
    else
      add_index :scraping_logs, :model_stats, using: :gin, algorithm: :concurrently unless index_exists?(:scraping_logs, :model_stats)
    end
  end
end
