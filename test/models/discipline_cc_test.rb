# == Schema Information
#
# Table name: discipline_ccs
#
#  id            :bigint           not null, primary key
#  context       :string
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  branch_cc_id  :integer
#  cc_id         :integer
#  discipline_id :integer
#
require "test_helper"

class DisciplineCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
