class AddModelStatsToScrapingLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :scraping_logs, :model_stats, :jsonb, default: {}
    add_index :scraping_logs, :model_stats, using: :gin
  end
end
