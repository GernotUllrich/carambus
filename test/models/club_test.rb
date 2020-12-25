# == Schema Information
#
# Table name: clubs
#
#  id         :bigint           not null, primary key
#  address    :text
#  dbu_entry  :string
#  email      :string
#  founded    :string
#  homepage   :string
#  logo       :string
#  name       :string
#  priceinfo  :text
#  shortname  :string
#  status     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_clubs_on_ba_id         (ba_id) UNIQUE
#  index_clubs_on_foreign_keys  (ba_id) UNIQUE
#
require 'test_helper'

class ClubTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
