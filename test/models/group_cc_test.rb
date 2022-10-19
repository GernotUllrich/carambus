# == Schema Information
#
# Table name: group_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  data         :text
#  display      :string
#  name         :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
require "test_helper"

class GroupCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
