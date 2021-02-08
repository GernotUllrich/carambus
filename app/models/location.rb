# == Schema Information
#
# Table name: locations
#
#  id             :bigint           not null, primary key
#  address        :text
#  data           :text
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
#
class Location < ApplicationRecord
  belongs_to :club
  belongs_to :organizer, polymorphic: true
  has_many :tables
  has_many :tournaments, foreign_key: :location_id
  serialize :data, Hash
end
