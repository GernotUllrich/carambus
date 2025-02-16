# == Schema Information
#
# Table name: slots
#
#  id                 :bigint           not null, primary key
#  dayofweek          :integer
#  hourofday_end      :integer
#  hourofday_start    :integer
#  minuteofhour_end   :integer
#  minuteofhour_start :integer
#  next_end           :datetime
#  next_start         :datetime
#  recurring          :boolean
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  table_id           :integer
#
class Slot < ApplicationRecord
  # Broadcast changes in realtime with Hotwire
  after_create_commit -> { broadcast_prepend_later_to :slots, partial: "slots/index", locals: { slot: self } }
  after_update_commit -> { broadcast_replace_later_to self }
  after_destroy_commit -> { broadcast_remove_to :slots, target: dom_id(self, :index) }
end
