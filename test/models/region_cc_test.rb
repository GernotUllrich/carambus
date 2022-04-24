# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  base_url   :string
#  context    :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_region_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#
require "test_helper"

class RegionCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
