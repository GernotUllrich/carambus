class AddUnchangedCountToScrapingLogs < ActiveRecord::Migration[7.2]
  def change
    add_column :scraping_logs, :unchanged_count, :integer, default: 0
  end
end
