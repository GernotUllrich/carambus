# == Schema Information
#
# Table name: table_monitors
#
#  id                    :bigint           not null, primary key
#  active_timer          :string
#  current_element       :string           default("pointer_mode"), not null
#  data                  :text
#  ip_address            :string
#  name                  :string
#  nnn                   :integer
#  panel_state           :string           default("pointer_mode"), not null
#  state                 :string
#  timer_finish_at       :datetime
#  timer_halt_at         :datetime
#  timer_start_at        :datetime
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  clock_job_id          :string
#  game_id               :integer
#  next_game_id          :integer
#  timer_job_id          :string
#  tournament_monitor_id :integer
#
require 'test_helper'

class TableMonitorTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
