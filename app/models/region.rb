class Region < ActiveRecord::Base
  belongs_to :country
  has_many :clubs
  has_many :tournaments
  has_many :player_rankings

  COLUMN_NAMES = {
      "Logo" => "",
      "Shortname (BA)" => "regions.shortname",
      "Name" => "regions.name",
      "Email" => "regions.email",
      "Address" => "",
      "Country" => "",
  }
end