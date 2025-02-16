# == Schema Information
#
# Table name: discipline_phases
#
#  id                   :bigint           not null, primary key
#  data                 :text
#  name                 :string
#  position             :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  discipline_id        :integer
#  parent_discipline_id :integer
#
require "test_helper"

class DisciplinePhaseTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
