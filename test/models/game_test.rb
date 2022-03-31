# == Schema Information
#
# Table name: games
#
#  id            :bigint           not null, primary key
#  data          :text
#  ended_at      :datetime
#  gname         :string
#  group_no      :integer
#  roles         :text
#  round_no      :integer
#
#
#
#
#
# seqno         :integer
#  started_at    :datetime
#  table_no      :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  tournament_id :integer
#
require 'test_helper'

class GameTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
