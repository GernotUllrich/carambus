class AddScrapeDataToRegion < ActiveRecord::Migration[7.2]
  def change
    add_column :regions, :scrape_data, :text
  end
end
