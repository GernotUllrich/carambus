# == Schema Information
#
# Table name: innings
#
#  id              :bigint           not null, primary key
#  data            :text
#  player_a_count  :string
#  player_b_count  :string
#  player_c_count  :string
#  player_d_count  :string
#  sequence_number :integer
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  game_id         :integer
#
# Indexes
#
#  index_innings_on_foreign_keys                 (game_id,sequence_number) UNIQUE
#  index_innings_on_game_id_and_sequence_number  (game_id,sequence_number) UNIQUE
#
class Inning < ApplicationRecord
  belongs_to :game
end
