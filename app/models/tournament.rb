class Tournament < ActiveRecord::Base
  belongs_to :discipline
  belongs_to :region
  belongs_to :season
  has_many :seedings
  has_many :games, dependent: :destroy

  serialize :remarks, Hash

  COLUMN_NAMES = { #TODO FILTERS
      "BA_ID" => "tournaments.ba_id",
      "Title" => "tournaments.title",
      "Shortname" => "tournaments.shortname",
      "Discipline" => "disciplines.name",
      "Region" => "regions.name",
      "Season" => "seasons.name",
      "Status" => "tournaments.state",
      "SingleOrLeague" => "tournaments.single_or_league",
  }

  def date_str
    if date.present?
      "#{date.to_s(:db)}#{" - #{(end_date.to_date.to_s(:db))}" if end_date.present?}"
    end
  end
end
