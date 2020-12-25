# == Schema Information
#
# Table name: tables
#
#  id            :bigint           not null, primary key
#  data          :text
#  ip_address    :string
#  name          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  location_id   :integer
#  table_kind_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (table_kind_id => table_kinds.id)
#
require 'test_helper'

class TableTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
