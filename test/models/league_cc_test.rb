# == Schema Information
#
# Table name: league_ccs
#
#  id               :bigint           not null, primary key
#  context          :string
#  name             :string
#  report_form      :string
#  report_form_data :string
#  shortname        :string
#  status           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cc_id            :integer
#  league_id        :integer
#  season_cc_id     :integer
#
require "test_helper"

class LeagueCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
