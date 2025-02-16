# == Schema Information
#
# Table name: game_plan_row_ccs
#
#  id            :bigint           not null, primary key
#  home_brett    :integer
#  mpg           :integer
#  pmv           :integer
#  ppg           :integer
#  ppu           :integer
#  ppv           :integer
#  score         :integer
#  sets          :integer
#  visitor_brett :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  cc_id         :integer
#  discipline_id :integer
#  game_plan_id  :integer
#
class GamePlanRowCc < ApplicationRecord
  include LocalProtector
  belongs_to :discipline

  before_save :set_paper_trail_whodunnit
end
