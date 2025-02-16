# == Schema Information
#
# Table name: group_ccs
#
#  id           :bigint           not null, primary key
#  context      :string
#  data         :text
#  display      :string
#  name         :string
#  status       :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  branch_cc_id :integer
#  cc_id        :integer
#
class GroupCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc
  has_many :tournament_cc
  has_many :registration_list_ccs

  NAME_MAPPING = {
    groups: {
      "Gruppe 1" => "Gruppe 1",
      "/group1:.*/" => "Gruppe 1",
      "Gruppe A" => "Gruppe 1",
      "Gr. A" => "Gruppe 1",
      "A" => "Gruppe 1",
      "Jeder gegen Jeden" => "Gruppe 1",
      "1. Vorrunde" => "Gruppe 1",
      "Gruppe 2" => "Gruppe 2",
      "/group2:.*/" => "Gruppe 2",
      "Gruppe B" => "Gruppe 2",
      "Gr. B" => "Gruppe 2",
      "B" => "Gruppe 2",
      "2. Vorrunde" => "Gruppe 2",
      "Gruppe 3" => "Gruppe 3",
      "/group3:.*/" => "Gruppe 3",
      "Gruppe C" => "Gruppe 3",
      "Gr. C" => "Gruppe 3",
      "C" => "Gruppe 3",
      "Gruppe 4" => "Gruppe 4",
      "/group4:.*/" => "Gruppe 4",
      "Gruppe D" => "Gruppe 4",
      "Gr. D" => "Gruppe 4",
      "D" => "Gruppe 4",
      "Halbfinale" => "Halbfinale",
      "Halbfinale 1" => "Halbfinale",
      "hf1" => "Halbfinale",
      "Halbfinale 2" => "Halbfinale",
      "hf2" => "Halbfinale",
      "HF" => "Halbfinale",
      "QF" => "Viertelfinale",
      "Viertelfinale" => "Viertelfinale",
      "Finale" => "Finale",
      "fin" => "Finale",
      "Spiel um Platz 1" => "Finale",
      "Platz 1-2" => "Finale",
      "Platz 3-4" => "Platz 3-4",
      "Spiel um Platz 3" => "Platz 3-4",
      "Spiel um Platz 3 + 4" => "Platz 3-4",
      "Spiel um Platz 3/4" => "Platz 3-4",
      "Platz 3/4" => "Platz 3-4",
      "Platz 3 / 4" => "Platz 3-4",
      "p<3-4>" => "Platz 3-4",
      "Spiel um Platz 5" => "Platz 5-6",
      "Spiel um Platz 5 + 6" => "Platz 5-6",
      "Spiel um Platz 5/6" => "Platz 5-6",
      "Spiel um Platz 6 + 5" => "Platz 5-6",
      "Platz 5/6" => "Platz 5-6",
      "Platz 5 / 6" => "Platz 5-6",
      "Platz 5" => "Platz 5-6",
      "p<5-6>" => "Platz 5-6",
      "Platz 5-6" => "Platz 5-6",
      "Platz 7-8" => "Platz 7-8",
      "Platz 7" => "Platz 7-8",
      "Spiel um Platz 7" => "Platz 7-8",
      "Spiel um Platz 8" => "Platz 7-8",
      "Spiel um Platz 7 + 8" => "Platz 7-8",
      "Spiel um Platz 7/8" => "Platz 7-8",
      "Platz 7/8" => "Platz 7-8",
      "Platz 7 / 8" => "Platz 7-8",
      "p<7-8>" => "Platz 7-8",
      "Platz 9-10" => "Platz 9-10",
      "Platz 9/10" => "Platz 9-10",
      "Platz 9 / 10" => "Platz 9-10",
      "p<9-10>" => "Platz 9-10",
      "Spiel um Platz 9" => "Platz 9-10",
      "Spiel um Platz 9 + 10" => "Platz 9-10",
      "Spiel um Platz 9/10" => "Platz 9-10",
      "Platz 11-12" => "Platz 11-12",
      "Platz 11/12" => "Platz 11-12",
      "p<11-12>" => "Platz 11-12",
      "Spiel um Platz 11" => "Platz 11-12",
      "Spiel um Platz 11 + 12" => "Platz 11-12",
      "Spiel um Platz 11/12" => "Platz 11-12",
      "Platz 13-14" => "Platz 13-14",
      "PLatz 13-14" => "Platz 13-14",
      "Platz 13/14" => "Platz 13-14",
      "Platz 15-16" => "Platz 15-16",
      "Platz 15/16" => "Platz 15-16",
      "Platz 9-12" => "Platz 9-12",
      "Platz 13-16" => "Platz 13-16",
      "Platz 17-24" => "Platz 17-24",
      "Platz 25-32" => "Platz 25-32",
      "Hauptrunde" => "Hauptrunde",
      "Endrunde" => "Endrunde"
    },
    round: {
      "Hauptrunde" => "Hauptrunde",
      "Gruppe" => "Hauptrunde",
      "HR" => "Hauptrunde",
      "4-Gruppe Jeder/Jeden" => "Hauptrunde",
      "NBV 4 Spieler" => "Hauptrunde",
      "Runde 1" => "Runde 1",
      "1. Runde" => "Runde 1",
      "1.Spielrunde" => "Runde 1",
      "Runde 2" => "Runde 2",
      "2. Runde" => "Runde 2",
      "2.Spielrunde" => "Runde 2",
      "Runde 3" => "Runde 3",
      "3. Runde" => "Runde 3",
      "3.Spielrunde" => "Runde 3"
    }

  }
end
