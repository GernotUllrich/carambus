# == Schema Information
#
# Table name: meta_maps
#
#  id          :bigint           not null, primary key
#  ba_base_url :string
#  cc_base_url :string
#  class_ba    :string
#  class_cc    :string
#  data        :text
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
require "test_helper"

class MetaMapTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end