# == Schema Information
#
# Table name: table_kinds
#
#  id         :bigint           not null, primary key
#  measures   :text
#  name       :string
#  short      :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
require 'test_helper'

class TableKindTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
