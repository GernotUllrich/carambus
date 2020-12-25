# == Schema Information
#
# Table name: player_classes
#
#  id            :bigint           not null, primary key
#  shortname     :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  discipline_id :integer
#
require 'test_helper'

class PlayerClassTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
