# == Schema Information
#
# Table name: locations
#
#  id             :bigint           not null, primary key
#  address        :text
#  data           :text
#  md5            :string           not null
#  name           :string
#  organizer_type :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  club_id        :integer
#  organizer_id   :integer
#
# Indexes
#
#  index_locations_on_club_id       (club_id)
#  index_locations_on_foreign_keys  (club_id)
#  index_locations_on_md5           (md5) UNIQUE
#
class Location < ApplicationRecord
  belongs_to :club, optional: true
  belongs_to :organizer, polymorphic: true
  has_many :tables
  has_many :tournaments, foreign_key: :location_id
  serialize :data, Hash

  REFLECTION_KEYS = ["club", "organizer"]
  COLUMN_NAMES = {#TODO FILTERS
                  "Club" => "clubs.name",
                  "Address" => "locations.address",
                  "Name" => "locations.name",
                  "Region" => "regions.shortname"
  }

  before_save :add_md5

  def add_md5
    self.md5 ||= Digest::MD5.hexdigest(self.attributes.inspect)
  end



  def display_address
    "#{name}<br>#{address.split("\n").join("<br>")}".html_safe
  end
end
