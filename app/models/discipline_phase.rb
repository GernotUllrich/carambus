# == Schema Information
#
# Table name: discipline_phases
#
#  id                   :bigint           not null, primary key
#  data                 :text
#  name                 :string
#  position             :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  discipline_id        :integer
#  parent_discipline_id :integer
#
class DisciplinePhase < ApplicationRecord
  # Broadcast changes in realtime with Hotwire
  after_create_commit lambda {
                        broadcast_prepend_later_to :discipline_phases, partial: "discipline_phases/index",
                                                                       locals: { discipline_phase: self }
                      }
  after_update_commit -> { broadcast_replace_later_to self }
  after_destroy_commit -> { broadcast_remove_to :discipline_phases, target: dom_id(self, :index) }
end
