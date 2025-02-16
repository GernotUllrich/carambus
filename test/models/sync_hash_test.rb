# == Schema Information
#
# Table name: sync_hashes
#
#  id         :bigint           not null, primary key
#  doc        :text
#  md5        :string
#  url        :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require "test_helper"

class SyncHashTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
