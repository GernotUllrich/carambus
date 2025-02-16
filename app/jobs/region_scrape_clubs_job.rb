class RegionScrapeClubsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    Rails.logger.silence do
      region, opts = args
      region.scrape_clubs(Season.current_season, opts.merge(from_background: true))
    end
  end
end
