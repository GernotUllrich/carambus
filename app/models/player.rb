# frozen_string_literal: true

# == Schema Information
#
# Table name: players
#
#  id            :bigint           not null, primary key
#  data          :text
#  firstname     :string
#  guest         :boolean          default(FALSE), not null
#  lastname      :string
#  nickname      :string
#  title         :string
#  type          :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  ba_id         :integer
#  cc_id         :integer
#  club_id       :integer
#  tournament_id :integer
#
# Indexes
#
#  index_players_on_ba_id    (ba_id) UNIQUE
#  index_players_on_cc_id    (cc_id) UNIQUE
#  index_players_on_club_id  (club_id)
#
class Player < ApplicationRecord
  belongs_to :club, optional: true
  has_many :game_participations, dependent: :nullify
  has_many :season_participations
  has_many :player_rankings
  has_many :seedings, dependent: :nullify
  has_many :party_a_games, foreign_key: :player_a_id, class_name: 'PartyGame'
  has_many :party_b_games, foreign_key: :player_b_id, class_name: 'PartyGame'
  has_one :admin_user, class_name: 'User', foreign_key: 'player_id'
  REFLECTION_KEYS = %w[club game_participations seedings season_participations].freeze

  serialize :data, Hash
  # for teams:
  #  data ordered by ba_id  then first player's data are copied into resp. fields of player record
  # data:
  {
    'players' => [
      {
        'firstname' => 'Alfred',
        'lastname' => 'Meyer',
        'ba_id' => 12_342,
        'player_id' => 1234
      }
    ]
  }

  COLUMN_NAMES = { # TODO: FILTERS
                   'Id' => 'players.id',
                   'BA_ID' => 'players.ba_id',
                   'CC_ID' => 'players.cc_id',
                   'Nickname' => 'players.nickname',
                   'Firstname' => 'players.firstname',
                   'Lastname' => 'players.lastname',
                   'Title' => 'players.title',
                   'Club' => 'clubs.shortname',
                   'Region' => 'regions.shortname',
                   'BaId' => 'players.ba_id'
  }.freeze

  def fullname
    "#{lastname}, #{firstname}"
  end

  def simple_firstname
    nickname.presence || firstname.gsub('Dr.', '')
  end

  def name
    fullname
  end

  def self.fix_from_shortnames(lastname, firstname, season, region, club_str, tournament, allow_players_outside_ba)
    player = nil
    club = Club.where(region: region).where('name ilike ?', club_str).first ||
      Club.where(region: region).where('shortname ilike ?', club_str).first
    if club.present?
      season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(
        seasons: { id: season.id }, players: { firstname: firstname, lastname: lastname }
      )
      if season_participations.count == 1
        season_participation = season_participations.first
        player = season_participation.player
        if season_participation.club_id == club.id
        else
          real_club = season_participations.first.club
          logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
          logger.info "[scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region.shortname}, season #{season.name}!"
          unless SeasonParticipation.find_by_player_id_and_season_id_and_club_id(
            player.id, season.id, real_club.id
          )
            SeasonParticipation.create(player_id: player.id, season_id: season.id,
                                       club_id: real_club.id)
          end
        end
        if tournament.present?
          seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id) ||
            Seeding.create(player_id: player.id, tournament_id: tournament.id)
        end
        state_ix = 0
      elsif season_participations.count.zero?
        players = Player.where(firstname: firstname, lastname: lastname)
        if players.count.zero?
          logger.info "[scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"
          logger.info "[scrape_tournaments] Inkonsistence - fixed - added Player Player #{lastname}, #{firstname} active to club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}"
          if allow_players_outside_ba
            player_fixed = Player.create(lastname: lastname, firstname: firstname, club_id: club.id)
            player_fixed.update(ba_id: 999_000_000 + player_fixed.id)
            SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
              SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
            if tournament.present?
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
                Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
            end
          end
          state_ix = 0
        elsif players.count == 1
          player_fixed = players.first
          logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
          SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
            SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
          logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
              Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
          end
          state_ix = 0
        elsif players.count > 1
          logger.info "[scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{players.map(&:club).map do |c|
            "#{c.andand.shortname} [#{c.andand.ba_id}]"
          end }] "
          logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{players.map(&:club).map do |c|
            "#{c.andand.shortname} [#{c.andand.ba_id}]"
          end.first}] "
          player_fixed = players.first
          SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id) ||
            SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
              Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
          end
          state_ix = 0
        end
      else
        # (ambiguous clubs)
        if season_participations.map(&:club_id).uniq.include?(club.id)
          season_participation = season_participations.where(club_id: club.id).first
          player = season_participation.player
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id) ||
              Seeding.create(player_id: player.id, tournament_id: tournament.id)
          end
        else
          logger.info "[scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
          fixed_season_participation = season_participations.last
          fixed_club = fixed_season_participation.club
          player_fixed = fixed_season_participation.player
          logger.info "[scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
          SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, fixed_club.id) ||
            SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: fixed_club.id)
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
              Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
          end
        end
        state_ix = 0
      end
    else
      logger.info "[scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
      fixed_club = region.clubs.create(name: club_str, shortname: club_str)
      player_fixed = fixed_club.players.create(firstname: firstname, lastname: lastname)
      fixed_club.update(ba_id: 999_000_000 + fixed_club.id)
      player_fixed.update(ba_id: 999_000_000 + player_fixed.id)
      SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: fixed_club.id)

      logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
      logger.info "[scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
      if tournament.present?
        seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id) ||
          Seeding.create(player_id: player_fixed.id, tournament_id: tournament.id)
      end
      state_ix = 0
    end
    [(player || player_fixed), seeding, state_ix]
  end

  def self.merge_players(player_ok, player_tmp_arr)
    Array(player_tmp_arr).each do |player_tmp|
      Player.transaction do
        GameParticipation.where(player_id: player_tmp.id).map { |o| o.update(player: player_ok) }
        SeasonParticipation.where(player_id: player_tmp.id).map { |o| o.update(player: player_ok) }
        PlayerRanking.where(player_id: player_tmp.id).map { |o| o.update(player: player_ok) }
        Seeding.where(player_id: player_tmp.id).map { |o| o.update(player: player_ok) }
        PartyGame.where(player_a_id: player_tmp.id).map { |o| o.update(player_a: player_ok) }
        PartyGame.where(player_b_id: player_tmp.id).map { |o| o.update(player_b: player_ok) }
        player_tmp.destroy
        player_ok
      end
    end
  end

  def xxx

    Player.where("firstname ilike '%(%'").each do |p|
      firstname = p.firstname.match(/(.*)\(.*/)[1]
      p2 = Player.where(lastname: p.lastname, firstname: firstname).first
      if p2.present?
      puts  p2.andand.attributes.andand.inspect , p.attributes.inspect
      end
    end; nil
    Player.where("lastname ilike 'von%'").each do |p|
      name = p.name.match(/von\s+(.*)$/).andand[1].to_s
      p2 = Player.where(lastname: name, firstname: "#{p.firstname} von").first
      puts "--- will merge #{[p2.id, p2.fullname]} to #{[p.id, p.fullname]}}" if p2.present?
    end
  end

  def mg(id1, id2)
    p1 = Player[id1]
    p2 = Player[id2]
    if p1.ba_id.present?# && p2.ba_id > 999000000
      cc_id = p1.cc_id || p2.cc_id
      p2.season_participations.delete_all
      p2.update(cc_id: nil)
      Player.merge_players(p1, p2)
      p1.update(cc_id: cc_id)
    end
  end

  def self.fix_player_without_ba_id(region, firstname, lastname, should_be_ba_id = nil, should_be_club_id = nil)
    region.fix_player_without_ba_id(firstname, lastname, should_be_ba_id, should_be_club_id)
  end
end

# {"data"=>[{"innings_goal"=>20, "playera"=>{"result"=>25, "innings"=>18, "innings_list"=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2,
# 1, 2, 0, 2, 2, 2, 1], "innings_redo_list"=>[0], "hs"=>3, "gd"=>"1.39", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4, 4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3],
#   "innings_redo_list"=>[], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}}, {"innings_goal"=>20, "playera"=>{"result"=>25, "innings"=>18, "innings_list
# "=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2, 1, 2, 0, 2, 2, 2, 1], "innings_redo_list"=>[1], "hs"=>3, "gd"=>"1.39", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4,
#   4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3], "innings_redo_list"=>[], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}}], "updated_at"=>[Sat, 26 Mar 2022 11:32
# :46 UTC +00:00, Sat, 26 Mar 2022 11:33:28 UTC +00:00], "timer_start_at"=>[Sat, 26 Mar 2022 11:32:46 UTC +00:00, Sat, 26 Mar 2022 11:33:28 UTC +00:00]}
#
# {"data"=>[{"innings_goal"=>20, "playera"=>{"result"=>25, "innings"=>18, "innings_list"=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2,
#                                                                                          1, 2, 0, 2, 2, 2, 1], "innings_redo_list"=>[1], "hs"=>3, "gd"=>"1.39", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4, 4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3],
#                                                                                                                                                                                                         "innings_redo_list"=>[], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}}, {"innings_goal"=>20, "playera"=>{"result"=>25, "innings"=>18, "innings_list
# "=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2, 1, 2, 0, 2, 2, 2, 1], "innings_redo_list"=>[2], "hs"=>3, "gd"=>"1.39", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4,
#                                                                                                                                                                                                   4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3], "innings_redo_list"=>[], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}}], "updated_at"=>[Sat, 26 Mar 2022 11:33
# :28 UTC +00:00, Sat, 26 Mar 2022 11:33:29 UTC +00:00], "timer_start_at"=>[Sat, 26 Mar 2022 11:33:28 UTC +00:00, Sat, 26 Mar 2022 11:33:29 UTC +00:00]}
#
#
#
#
# {"data"=>[{"innings_goal"=>20, "playera"=>{"result"=>25, "innings"=>18, "innings_list"=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2,1, 2, 0, 2, 2, 2, 1], "innings_redo_list"=>[2], "hs"=>3, "gd"=>"1.39", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4, 4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3],"innings_redo_list"=>[], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playera", "balls"=>0}}, {"innings_goal"=>20, "playera"=>{"result"=>27, "innings"=>19, "innings_list
# "=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2, 1, 2, 0, 2, 2, 2, 1, 2], "innings_redo_list"=>[], "hs"=>3, "gd"=>"1.42", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4, 4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3], "innings_redo_list"=>[0], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playerb", "balls"=>0}}], "updated_at"=>[Sat, 26 Mar 2022 11:33:29 UTC +00:00, Sat, 26 Mar 2022 11:33:29 UTC +00:00], "active_timer"=>["timeout", nil], "timer_start_at"=>[Sat, 26 Mar 2022 11:33:29 UTC +00:00, nil]}
#
#
# {"data"=>[{"innings_goal"=>20, "playera"=>{"result"=>27, "innings"=>19, "innings_list"=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2,
#                                                                                          1, 2, 0, 2, 2, 2, 1, 2], "innings_redo_list"=>[], "hs"=>3, "gd"=>"1.42", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>30, "innings"=>18, "innings_list"=>[3, 0, 3, 1, 1, 4, 4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3]
#           , "innings_redo_list"=>[0], "hs"=>5, "gd"=>"1.67", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playerb", "balls"=>0}}, {"innings_goal"=>20, "playera"=>{"result"=>0, "innings"=>0, "innings_lis
# t"=>[1, 2, 0, 1, 2, 1, 1, 2, 3, 0, 2, 1, 2, 0, 2, 2, 2, 1, 2], "innings_redo_list"=>[], "hs"=>0, "gd"=>"NaN", "balls_goal"=>40, "tc"=>0}, "playerb"=>{"result"=>0, "innings"=>0, "innings_list"=>[3, 0, 3, 1, 1, 4,
#                                                                                                                                                                                                   4, 0, 0, 2, 1, 1, 1, 0, 5, 1, 0, 3], "innings_redo_list"=>[0], "hs"=>0, "gd"=>"NaN", "balls_goal"=>40, "tc"=>0}, "current_inning"=>{"active_player"=>"playerb", "balls"=>0}}], "updated_at"=>[Sat, 26 Mar 2022 12:33
# :30 CET +01:00, Sat, 26 Mar 2022 12:33:45 CET +01:00]}
