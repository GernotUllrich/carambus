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
  include ApiProtector

  belongs_to :table

  # Plan 40-01: Grundsprache dieses Tisches — greift, wenn kein Turnier laeuft (Training) oder
  # das laufende Turnier keine eigene Sprache gesetzt hat. `nil` = nicht konfiguriert.
  validates :locale, inclusion: {in: I18n.available_locales.map(&:to_s)}, allow_nil: true
end
