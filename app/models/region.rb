class Region < ActiveRecord::Base
  belongs_to :country
  has_many :clubs
  has_many :tournaments

  COLUMN_NAMES = {
      "Logo" => "",
      "Shortname (BA)" => "regions.shortname",
      "Name" => "regions.name",
      "Email" => "regions.email",
      "Address" => "",
      "Country" => "",
  }
end