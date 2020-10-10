class Tournament < ActiveRecord::Base
  belongs_to :discipline
  belongs_to :region
  belongs_to :season
  has_many :seedings
  has_many :games, dependent: :destroy

  serialize :remarks, Hash

  NAME_DISCIPLINE_MAPPINGS = {
      "9-Ball" => "9-Ball",
      "8-Ball" => "8-Ball",
      "14.1" => "14.1 endlos",
      "47/2" => "Cadre 47/2",
      "71/2" => "Cadre 71/2",
      "35/2" => "Cadre 35/2",
      "52/2" => "Cadre 52/2",
      "Kl.*I.*Freie" => "Freie Partie groß",
      "Freie.*Kl.*I" => "Freie Partie groß",
      "Einband.*Kl.*I" => "Einband groß",
      ".*Kl.*I.*Einband" => "Einband groß",
      "Einband" => "Einband klein",
      "Freie Partie" => "Freie Partie klein",
  }

  COLUMN_NAMES = { #TODO FILTERS
      "BA_ID" => "tournaments.ba_id",
      "Title" => "tournaments.title",
      "Shortname" => "tournaments.shortname",
      "Discipline" => "disciplines.name",
      "Region" => "regions.name",
      "Season" => "seasons.name",
      "Status" => "tournaments.plan_or_show",
      "SingleOrLeague" => "tournaments.single_or_league",
  }

  def date_str
    if date.present?
      "#{date.to_s(:db)}#{" - #{(end_date.to_date.to_s(:db))}" if end_date.present?}"
    end
  end
end
