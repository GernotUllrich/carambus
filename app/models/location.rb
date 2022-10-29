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
#  region_id      :integer
#
# Indexes
#
#  index_locations_on_md5  (md5) UNIQUE
#

class Location < ApplicationRecord
  belongs_to :club, optional: true
  belongs_to :region, optional: true
  belongs_to :organizer, polymorphic: true
  has_many :tables
  has_many :tournaments, foreign_key: :location_id
  serialize :data, Hash

  REFLECTION_KEYS = ["club", "region"]
  COLUMN_NAMES = { #TODO FILTERS
                   "Club" => "clubs.shortname",
                   "Address" => "locations.address",
                   "Name" => "locations.name",
                   "Region" => "regions.shortname"
  }

  before_save :add_md5

  def add_md5
    self.md5 ||= Digest::MD5.hexdigest(self.attributes.inspect)
  end

  def self.merge_locations(location_ok_id, with_location_ids = [])
    with_locations = Location.where(id: with_location_ids)
    unless with_locations.count == with_location_ids.count
      location_ok = Location[location_ok_id]
      if location_ok.present?
        location_ok.merge_locations(with_location_ids)
      else
        raise ArgumentError
      end
    else
      raise ArgumentError
    end
  end

  def merge_locations(with_location_ids = [])
    Tournament.where(location_id: with_location_ids).update_all(location_id: id)
    Table.where(location_id: with_location_ids).update_all(location_id: id)
    Location.where(id: with_location_ids).destroy_all
    Rails.logger.info("REPORT Location.merge_locations(#{id}, #{with_location_ids.inspect})")
    reload
  end

  def display_address
    "#{name}<br>#{address.split("\n").join("<br>")}".html_safe
  end
end
