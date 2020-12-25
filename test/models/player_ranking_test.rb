# == Schema Information
#
# Table name: player_rankings
#
#  id                         :bigint           not null, primary key
#  balls                      :integer
#  bed                        :float
#  btg                        :float
#  g                          :integer
#  gd                         :float
#  hs                         :integer
#  innings                    :integer
#  org_level                  :string
#  p_gd                       :float
#  points                     :integer
#  pp_gd                      :float
#  quote                      :float
#  rank                       :integer
#  remarks                    :text
#  sets                       :integer
#  sp_g                       :integer
#  sp_quote                   :float
#  sp_v                       :integer
#  status                     :string
#  t_ids                      :text
#  v                          :integer
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  discipline_id              :integer
#  p_player_class_id          :integer
#  player_class_id            :integer
#  player_id                  :integer
#  pp_player_class_id         :integer
#  region_id                  :integer
#  season_id                  :integer
#  tournament_player_class_id :integer
#
require 'test_helper'

class PlayerRankingTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
