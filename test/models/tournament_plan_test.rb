# == Schema Information
#
# Table name: tournament_plans
#
#  id                    :bigint           not null, primary key
#  even_more_description :text
#  executor_class        :string
#  executor_params       :text
#  more_description      :text
#  name                  :string
#  ngroups               :integer
#  nrepeats              :integer
#  players               :integer
#  rulesystem            :text
#  tables                :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
require 'test_helper'

class TournamentPlanTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
