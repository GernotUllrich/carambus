# == Schema Information
#
# Table name: parties
#
#  id                  :bigint           not null, primary key
#  data                :text
#  date                :datetime
#  day_seqno           :integer
#  remarks             :text
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  ba_id               :integer
#  host_league_team_id :integer
#  league_id           :integer
#  league_team_a_id    :integer
#  league_team_b_id    :integer
#
require 'test_helper'

class PartyTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
