# == Schema Information
#
# Table name: seasons
#
#  id         :bigint           not null, primary key
#  data       :text
#  name       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  ba_id      :integer
#
# Indexes
#
#  index_seasons_on_ba_id  (ba_id) UNIQUE
#  index_seasons_on_name   (name) UNIQUE
#
require 'test_helper'

class SeasonTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
