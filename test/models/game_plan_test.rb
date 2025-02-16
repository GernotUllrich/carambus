# == Schema Information
#
# Table name: game_plans
#
#  id         :bigint           not null, primary key
#  data       :text
#  footprint  :string
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class GamePlanTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
