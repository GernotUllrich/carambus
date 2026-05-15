# frozen_string_literal: true

# D-14-G5: Join-Model für M:N Sportwart-Wirkbereich (User × Discipline).
# User.has_many :sportwart_disciplines geht über dieses Model via :source-Mapping.
#
# ApiProtector: siehe SportwartLocation — lokales Konzept, am API-Server nicht zulässig.
class SportwartDiscipline < ApplicationRecord
  include ApiProtector

  belongs_to :user
  belongs_to :discipline

  validates :user_id, uniqueness: {scope: :discipline_id}
end
