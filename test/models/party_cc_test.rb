# == Schema Information
#
# Table name: party_ccs
#
#  id                     :bigint           not null, primary key
#  data                   :text
#  day_seqno              :integer
#  remarks                :text
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  cc_id                  :integer
#  league_cc_id           :integer
#  league_team_a_cc_id    :integer
#  league_team_b_cc_id    :integer
#  league_team_host_cc_id :integer
#  party_id               :integer
#
require "test_helper"

class PartyCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
