# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  context    :string
#  name       :string
#  shortname  :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
class RegionCc < ApplicationRecord
  belongs_to :region
  has_many :branch_ccs
end
