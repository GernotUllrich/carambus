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

  # Genau ein TableLocal je Tisch — `Table has_one :table_local` greift sonst einen beliebigen
  # heraus, und die gesamte ortsgebundene Konfiguration (Scoreboard-IP, Tischheizung, Kalender,
  # Sprache) wird unzuverlaessig. Die Validierung ist das Gegenstueck zum Unique-Index aus
  # `AddUniqueIndexToTableLocals`: sie ist nicht atomar (deshalb der Index), macht den Konflikt
  # in der Oberflaeche aber als Fehlermeldung sichtbar statt als 500.
  validates :table_id, uniqueness: true, allow_nil: true

  # Plan 40-01: Grundsprache dieses Tisches — greift, wenn kein Turnier laeuft (Training) oder
  # das laufende Turnier keine eigene Sprache gesetzt hat. `nil` = nicht konfiguriert.
  # Plan 40-02: ein leeres Select-Feld liefert "", nicht nil — und "" waere nach der
  # Validierung unten UNGUELTIG (`allow_nil` greift dort nicht). Ohne diese Normalisierung
  # koennte der Turnierleiter die Sprache nicht wieder auf "nicht gesetzt" zuruecksetzen.
  normalizes :locale, with: ->(value) { value.presence }
  validates :locale, inclusion: {in: I18n.available_locales.map(&:to_s)}, allow_nil: true
end
