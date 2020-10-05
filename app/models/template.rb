class Template < ActiveRecord::Base
  has_many :discipline_templates
  has_many :template_games
  has_many :player_count_templates
end
