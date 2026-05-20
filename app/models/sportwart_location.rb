# frozen_string_literal: true

# D-14-G5: Join-Model für M:N Sportwart-Wirkbereich (User × Location).
# User.has_many :sportwart_locations geht über dieses Model via :source-Mapping.
#
# ApiProtector: Sportwart-Wirkbereich ist ein lokales Konzept (per-Region-Scenario).
# Auf dem API-Server (carambus.de) macht das Anlegen von Wirkbereichs-Records keinen Sinn —
# ApiProtector verhindert das. IDs für diese Records sind >= Seeding::MIN_ID (lokale ID-Range).
class SportwartLocation < ApplicationRecord
  include ApiProtector

  belongs_to :user
  belongs_to :location

  validates :user_id, uniqueness: {scope: :location_id}
end
