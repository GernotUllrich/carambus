# == Schema Information
#
# Table name: uploads
#
#  id         :bigint           not null, primary key
#  filename   :string
#  position   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :integer
#
require "test_helper"

class UploadTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
