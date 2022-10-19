# == Schema Information
#
# Table name: category_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  max_age      :integer
#  min_age      :integer
#  name         :string
#  sex          :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
require "test_helper"

class CategoryCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
