# == Schema Information
#
# Table name: debug_infos
#
#  id         :bigint           not null, primary key
#  info       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
class DebugInfo < ApplicationRecord
  before_save :set_paper_trail_whodunnit

  @@debug_info = DebugInfo.first || DebugInfo.create!
  def self.instance
    ret = @@debug_info
    ret = @@debug_info = DebugInfo.first || Setting.new.save! if ret.blank?
    ret
  end
end
