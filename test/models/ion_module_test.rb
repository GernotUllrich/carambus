# == Schema Information
#
# Table name: ion_modules
#
#  id             :bigint           not null, primary key
#  data           :text
#  html           :text
#  module_type    :string
#  position       :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  ion_content_id :integer
#  module_id      :string
#
require "test_helper"

class IonModuleTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
