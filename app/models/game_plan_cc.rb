# == Schema Information
#
# Table name: game_plan_ccs
#
#  id                  :bigint           not null, primary key
#  bez_brett           :string
#  data                :text
#  ersatzspieler_regel :integer
#  mb_draw             :integer
#  mp_lost             :integer
#  mp_won              :integer
#  name                :string
#  pez_partie          :string
#  plausi              :boolean
#  rang_kegel          :integer
#  rang_mgd            :integer
#  rang_partie         :integer
#  vorgabe             :integer
#  znp                 :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  branch_cc_id        :integer
#  cc_id               :integer
#  discipline_id       :integer
#  row_type_id         :integer
#
class GamePlanCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc
  belongs_to :discipline
  has_many :league_ccs

  before_save :set_paper_trail_whodunnit

  serialize :data, coder: JSON, type: Hash

  delegate :fedId, :branchId, :region_cc, to: :branch_cc

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end
end
