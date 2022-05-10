# == Schema Information
#
# Table name: game_plan_ccs
#
#  id                  :bigint           not null, primary key
#  bez_brett           :string
#  data                :text
#  ersatzspieler_regel :integer
#  mb_draw             :integer
#  mp_lost             :integer
#  mp_won              :integer
#  name                :string
#  pez_partie          :string
#  plausi              :boolean
#  rang_kegel          :integer
#  rang_mgd            :integer
#  rang_partie         :integer
#  vorgabe             :integer
#  znp                 :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  branch_cc_id        :integer
#  cc_id               :integer
#  discipline_id       :integer
#  row_type_id         :integer
#
require "test_helper"

class GamePlanCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
