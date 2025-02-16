# == Schema Information
#
# Table name: club_locations
#
#  id          :bigint           not null, primary key
#  status      :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  club_id     :integer
#  location_id :integer
#
require "test_helper"

class ClubLocationTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
