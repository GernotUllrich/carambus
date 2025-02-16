# == Schema Information
#
# Table name: registration_list_ccs
#
#  id              :bigint           not null, primary key
#  context         :string
#  data            :text
#  deadline        :datetime
#  name            :string
#  qualifying_date :datetime
#  status          :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  branch_cc_id    :integer
#  category_cc_id  :integer
#  cc_id           :integer
#  discipline_id   :integer
#  season_id       :integer
#
class RegistrationListCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc
  belongs_to :season
  belongs_to :discipline
  belongs_to :category_cc
  has_many :registration_ccs
end
