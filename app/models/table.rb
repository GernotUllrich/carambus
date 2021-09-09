# == Schema Information
#
# Table name: tables
#
#  id               :bigint           not null, primary key
#  data             :text
#  ip_address       :string
#  name             :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  location_id      :integer
#  table_kind_id    :integer
#  table_monitor_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (location_id => locations.id)
#  fk_rails_...  (table_kind_id => table_kinds.id)
#
class Table < ApplicationRecord
  belongs_to :location
  belongs_to :table_kind
  belongs_to :table_monitor

  def number
    m = name.match(/.*(\d+).*/)
    m.present? ? m[1].to_i : 0
  end

  def table_monitor
    table_monitor_id = read_attribute(:table_monitor_id)
    tm = TableMonitor.find_by_id(table_monitor_id)
    if tm.blank?
      tm = TableMonitor.create
      update(table_monitor: tm)
    end
    tm
  end
end
