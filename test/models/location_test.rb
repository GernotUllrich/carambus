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
require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
