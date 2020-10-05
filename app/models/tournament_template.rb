class TournamentTemplate < ActiveRecord::Base
  has_many :player_count_templates
  belongs_to :discipline

  COLUMN_NAMES = {

  }
end
