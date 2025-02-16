# == Schema Information
#
# Table name: slots
#
#  id                 :bigint           not null, primary key
#  dayofweek          :integer
#  hourofday_end      :integer
#  hourofday_start    :integer
#  minuteofhour_end   :integer
#  minuteofhour_start :integer
#  next_end           :datetime
#  next_start         :datetime
#  recurring          :boolean
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  table_id           :integer
#
require "test_helper"

class SlotTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
