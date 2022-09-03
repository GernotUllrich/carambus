# == Schema Information
#
# Table name: wordles
#
#  id         :bigint           not null, primary key
#  data       :text
#  hints      :text
#  seqno      :integer
#  words      :text
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class WordleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
