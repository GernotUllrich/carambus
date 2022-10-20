# == Schema Information
#
# Table name: regions
#
#  id                 :bigint           not null, primary key
#  address            :text
#  email              :string
#  logo               :string
#  name               :string
#  public_cc_url_base :string
#  shortname          :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  country_id         :integer
#
# Indexes
#
#  index_regions_on_country_id  (country_id)
#  index_regions_on_shortname   (shortname) UNIQUE
#
require 'test_helper'

class RegionTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
