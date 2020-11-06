class Club < ActiveRecord::Base
  belongs_to :region
  has_many :players
  has_many :season_participations
  has_one :club
  REFLECTION_KEYS = ["region", "players", "season_participations"]
  COLUMN_NAMES = {        #TODO FILTERS
                  "BA_ID" => "clubs.ba_id",
                  "Region" => "regions.name",
                  "Name" => "clubs.name",
                  "Shortname" => "clubs.shortname",
                  "Homepage" => "",
                  "Status" => "",
                  "Founded" => "",
                  "Dbu entry" => "",
  }
  #x clubs.ba_id regions.name clubs.name clubs.shortname
end
