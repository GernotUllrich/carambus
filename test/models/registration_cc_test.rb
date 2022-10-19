# == Schema Information
#
# Table name: registration_ccs
#
#  id                      :bigint           not null, primary key
#  status                  :string
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  player_id               :integer
#  registration_list_cc_id :integer
#
# Indexes
#
#  index_registration_ccs_on_player_id_and_registration_list_cc_id  (player_id,registration_list_cc_id) UNIQUE
#
require "test_helper"

class RegistrationCcTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
