# == Schema Information
#
# Table name: regions
#
#  id         :bigint           not null, primary key
#  address    :text
#  email      :string
#  logo       :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  country_id :integer
#
# Indexes
#
#  index_regions_on_country_id  (country_id)
#  index_regions_on_shortname   (shortname) UNIQUE
#
class Region < ApplicationRecord
  belongs_to :country
  has_many :clubs
  has_many :tournaments
  has_many :player_rankings
  has_many :tournament_locations, as: :organizer, class_name: "Location"
  has_many :organized_tournaments, as: :organizer, class_name: "Tournament"
  has_one :setting

  COLUMN_NAMES = {
      "Logo" => "",
      "Shortname (BA)" => "regions.shortname",
      "Name" => "regions.name",
      "Email" => "regions.email",
      "Address" => "regions.address",
      "Country" => "",
  }

  def display_shortname
    shortname
  end
end
