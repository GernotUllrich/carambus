# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  context    :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
require "test_helper"

class RegionCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
