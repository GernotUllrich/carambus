# == Schema Information
#
# Table name: season_ccs
#
#  id                :bigint           not null, primary key
#  context           :string
#  name              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  cc_id             :integer
#  competition_cc_id :integer
#  season_id         :integer
#
# Indexes
#
#  index_season_ccs_on_competition_cc_id_and_cc_id_and_context  (competition_cc_id,cc_id,context) UNIQUE
#
require "test_helper"

class SeasonCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
