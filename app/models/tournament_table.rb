class TournamentTable < ActiveRecord::Base
  belongs_to :tournament
  belongs_to :table
end
