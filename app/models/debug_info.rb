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
  has_paper_trail
  @@debug_info = DebugInfo.first || DebugInfo.create!
  def self.instance
    ret = @@debug_info
    if ret.blank?
      ret = @@debug_info = DebugInfo.first || Setting.new.save!
    end
    ret
  end
end
