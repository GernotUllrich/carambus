# == Schema Information
#
# Table name: t_locations
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
#  index _t_locations_on_club_id      (club_id)
#  index_t_locations_on_foreign_keys  (club_id)
#
class TLocation < ApplicationRecord
  belongs_to :club
  belongs_to :organizer, polymorphic: true
  has_many :tables
  has_many :t_tournaments, foreign_key: :t_location_id
  serialize :data, Hash
end
