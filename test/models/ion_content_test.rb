# == Schema Information
#
# Table name: ion_contents
#
#  id              :bigint           not null, primary key
#  data            :text
#  deep_scraped_at :datetime
#  hidden          :boolean          default(FALSE), not null
#  html            :text
#  level           :string
#  position        :integer
#  scraped_at      :datetime
#  title           :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  ion_content_id  :integer
#  page_id         :integer
#
require "test_helper"

class IonContentTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
