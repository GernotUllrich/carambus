# == Schema Information
#
# Table name: league_team_ccs
#
#  id             :bigint           not null, primary key
#  data           :text
#  name           :string
#  shortname      :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cc_id          :integer
#  league_cc_id   :integer
#  league_team_id :integer
#
require "test_helper"

class LeagueTeamCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
