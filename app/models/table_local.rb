# == Schema Information
#
# Table name: table_locals
#
#  id             :bigint           not null, primary key
#  ip_address     :string
#  tpl_ip_address :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  table_id       :integer
#
class TableLocal < ApplicationRecord
  belongs_to :table
end
