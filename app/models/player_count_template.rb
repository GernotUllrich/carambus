class PlayerCountTemplate < ActiveRecord::Base
  belongs_to :tournament_template
  belongs_to :template
end
