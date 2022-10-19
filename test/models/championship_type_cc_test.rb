# == Schema Information
#
# Table name: championship_type_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  name         :string
#  shortname    :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
require "test_helper"

class ChampionshipTypeCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
