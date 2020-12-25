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
require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
