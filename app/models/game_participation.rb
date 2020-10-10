class GameParticipation < ActiveRecord::Base
  belongs_to :player
  belongs_to :game

  serialize :remarks, Hash

  COLUMN_NAMES = {
      "#" => "games.seqno",
      "Game" => "games.gname",
      "Tournament" => "tournaments.title",
      "Discipline" => "disciplines.name",
      "Date" => "tournaments.date",
      "Player" => "players.lastname||', '||players.firstname",
      "Club" => "clubs.shortname",
      "Role" => "game_participations.role",
      "Points" => "game_participations.points",
      "Result" => "game_participations.result",
      "Innings" => "game_participations.innings",
      "GD" => "game_participations.gd",
      "HS" => "game_participations.hs",
  }
end
