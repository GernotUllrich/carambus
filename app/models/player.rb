# frozen_string_literal: true

# The Player class represents players in an application. It is associated with various models such as GameParticipation,
# SeasonParticipation, Club, and others. It is responsible for maintaining player details, including their participation
# in games, seasons, and associated clubs.
# Validations are included for the pin4 attribute, which should be unique and a specific length. It also uses
# a before_save callback to update a player's full name.
# It includes several instance and class methods for functionality like forming teams from players, updating team names,
# analyzing duplicate players, and more.
class Player < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  include Searchable
  include PlayerFinder
  has_many :game_participations, dependent: :nullify
  has_many :season_participations, dependent: :destroy
  has_many :clubs, through: :season_participations
  has_many :player_rankings
  has_many :seedings, dependent: :nullify
  has_many :registration_ccs
  has_many :party_a_games, foreign_key: :player_a_id, class_name: "PartyGame"
  has_many :party_b_games, foreign_key: :player_b_id, class_name: "PartyGame"
  has_one :admin_user, class_name: "User", foreign_key: "player_id", dependent: :nullify
  
  # International associations
  # Note: International tournament participation is tracked via Seeding (not a separate model)
  # Tournament results are tracked via Games and GameParticipations
  has_many :international_tournaments, through: :seedings, source: :tournament, 
           class_name: 'InternationalTournament'
  
  # Polymorphe Video Association
  has_many :videos, as: :videoable, dependent: :nullify
  
  REFLECTION_KEYS = %w[club game_participations seedings season_participations].freeze

  self.ignored_columns = ["region_ids"]

  belongs_to :region, optional: true

  validates :pin4,
            uniqueness: true,
            length: { is: 4 },
            exclusion: { in: %w[1234 1111 0000 1212 7777 1004 2000 4444 2222 6969 9999 3333 5555 6666 1122 1313 8888
                                4321 2001 1010] },
            unless: -> { pin4.blank? }
  
  validates :nationality, length: { is: 2 }, allow_blank: true
  validates :umb_player_id, uniqueness: true, allow_nil: true

  before_save do
    self.fl_name = "#{firstname} #{lastname}".strip
  end

  serialize :data, coder: JSON, type: Hash
  # for teams:
  #  data ordered by ba_id  then first player's data are copied into resp. fields of player record
  # data:
  # {
  #   'players' => [
  #     {
  #       'firstname' => 'Alfred',
  #       'lastname' => 'Meyer',
  #       'ba_id' => 12_342,
  #       'player_id' => 1234
  #     }
  #   ]
  # }
  @default_guest = {
    a: {},
    b: {}
  }
  COLUMN_NAMES = {
    # IDs (versteckt, nur für Backend-Filterung)
    "id" => "players.id",
    "region_id" => "regions.id",
    "club_id" => "season_participations.club_id",
    
    # Externe IDs (sichtbar, filterbar)
    "CC_ID" => "players.cc_id",
    "DBU_ID" => "players.dbu_nr",
    
    # Referenzen (Dropdown/Select)
    "Region" => "regions.shortname",
    "Club" => "clubs.shortname",
    
    # Eigene Felder
    "Firstname" => "players.firstname",
    "Lastname" => "players.lastname",
    "Nickname" => "players.nickname",
    "Title" => "players.title",
  }.freeze

  # Searchable concern provides search_hash, we only need to define the specifics
  
  def self.text_search_sql
    "(players.fl_name ilike :search)
     or (players.firstname ilike :search)
     or (players.lastname ilike :search)
     or (players.nickname ilike :search)
     or (players.cc_id = :isearch)
     or (clubs.name ilike :search)
     or (clubs.shortname ilike :search)"
  end

  def self.search_joins
    [
      :region,
      { season_participations: :club }
    ]
  end

  def self.search_distinct?
    true # wegen season_participations können Duplikate entstehen
  end

  def self.cascading_filters
    {
      'region_id' => ['club_id']  # Region-Auswahl filtert verfügbare Clubs
    }
  end
  
  def self.field_examples(field_name)
    case field_name
    when 'Firstname', 'Lastname', 'Nickname'
      { description: "Textsuche nach #{field_name}", examples: ["Meyer", "Hans", "Hansi"] }
    when 'CC_ID', 'DBU_ID'
      { description: "Numerische ID", examples: ["12345", "67890"] }
    when 'Region'
      { description: "Region auswählen", examples: [] }
    when 'Club'
      { description: "Verein auswählen (nach Region gefiltert)", examples: [] }
    when 'Title'
      { description: "Titel/Anrede", examples: ["Herr", "Frau", "Dr."] }
    else
      super
    end
  end

  def self.default_guest(ab, location)
    if @default_guest[ab][location.id].blank?
      club = location.club
      default_guest = club
                        .season_participations.joins("INNER JOIN \"players\" ON \"players\".\"id\" =
\"season_participations\".\"player_id\"")
                        .where(season_id: Season.current_season&.id, players: { fl_name: "Gast #{ab.to_s.upcase}" }).first
      if default_guest.blank?
        default_guest = SeasonParticipation.create(club_id: club.id,
                                                   season_id: Season.current_season&.id,
                                                   player: Player.create(lastname: "Gast #{ab.to_s.upcase}"),
                                                   status: "guest")
      end
      @default_guest[ab][location.id] = default_guest
    end
    @default_guest[ab][location.id]
  end

  def fullname
    "#{lastname}, #{firstname}".gsub(/,\s*$/, "")
  end

  def shortname
    lastname.present? ? lastname : firstname
  end

  def self.team_from_players(players)
    if players.blank?
      nil
    elsif players.count == 1
      players[0]
    else
      args = { data:
                 { "players" => players.map do |p|
                   {
                     firstname: p.firstname,
                     lastname: p.lastname,
                     ba_id: p.ba_id,
                     cc_id: p.cc_id,
                     player_id: p.id
                   }
                 end },
               region_id: players[0].andand.region_id
      }

      Team.where(args).first || Team.create!(args)
    end
  end

  def club
    season_participations.order(:season_id).last.andand.club
  end

  def simple_firstname
    nickname.presence || firstname.andand.gsub("Dr.", "")
  end

  def name
    fullname
  end

  def self.update_teams_fl_names
    Team.all.each do |team|
      d = team.data
      players = [d["players"]]
      players_new = players.map do |pl_hash|
        pl_hash["fl"] = "#{pl_hash["firstname"]} #{pl_hash["lastname"]}".strip
        pl_hash
      end
      d["players"] = players_new
      team.data = d
      team.data_will_change!
      team.save
    end
  end

  def self.analyse_duplicates(opts = {})
    # get duplicates
    fl_names_done = []
    if File.exist?("tmp/PLAYER_DUPLICATES")
      str = File.read("tmp/PLAYER_DUPLICATES")
      if str.present?
        struct = JSON.parse(str)
        fl_names_done = struct.keys
      end
    end
    fl_names = []
    Player.select("fl_name").where(type: nil).group("type", :fl_name).having("count(*) > 1").each do |pl|
      fl_names << pl.fl_name
    end
    fl_names -= fl_names_done unless opts[:partial_recalc]
    struct = struct.presence || {}
    fl_names.each_with_index do |fl_name, ix|
      players = Player.cross_domain_player_search(fl_name, opts)
      if players.nil?
        str = struct.to_json
        f = File.new("tmp/PLAYER_DUPLICATES", "wb")
        f.write(str)
        f.close
        # sleep 20
        players = players.to_a
      end
      struct[fl_name] = players
      next unless (ix % 50).zero?

      str = struct.to_json
      f = File.new("tmp/PLAYER_DUPLICATES", "wb")
      f.write(str)
      f.close
    end
    str = struct.to_json
    os f = File.new("tmp/PLAYER_DUPLICATES", "wb")
    f.write(str)
    f.close
  end

  def self.merge_duplicates_when_uniq_in_cc
    struct = JSON.parse(File.read("tmp/PLAYER_DUPLICATES"))
    uniq_in_cc = struct.select { |_k, v| v.count == 1 }
    uniq_in_cc.each do |fl_name, v|
      player_master = Player.where(firstname: v[0][0], lastname: v[0][1], cc_id: v[0][3], type: nil).first
      next unless player_master.present?

      other_players = Player.where(fl_name: fl_name, type: nil).where.not(id: player_master.id).to_a
      next unless other_players.present?

      Player.merge_players(player_master, other_players)
      others = "#{[other_players.map(&:id), other_players.map(&:ba_id)]}] with [#{[player_master.id,
                                                                                   player_master.ba_id]}"
      Rails.logger.info "====== MERGED #{fl_name} from [#{others}]"
    end
  end

  def self.merge_players_when_matching_club_and_dbu_nr
    struct = JSON.parse(File.read("tmp/PLAYER_DUPLICATES"))
    struct.each do |k, vvv|
      dbu_numbers = []
      vvv.each do |v|
        dbu_numbers |= [v[4]]
      end
      dbu_numbers.each do |dbu_nr|
        nrw_nr = nil
        cc_id = nil
        firstname, lastname, _region, _pass_nr, _dbu_nr = nil
        vvv.each do |vv|
          next if vv[4] != dbu_nr

          firstname, lastname, region, pass_nr, _dbu_nr = vv
          if region == "BVNRW"
            nrw_nr = pass_nr
          elsif pass_nr != dbu_nr
            cc_id = pass_nr
          end
        end
        player_master = Player.where(firstname: firstname, lastname: lastname, cc_id: cc_id, type: nil).first
        player_master ||= Player.where(firstname: firstname, lastname: lastname, cc_id: nrw_nr, type: nil).first
        next unless player_master.present?

        club_cc_ids = player_master.clubs.uniq.map(&:cc_id).compact
        players_to_merge = Player.where(fl_name: k, type: nil).where.not(id: player_master.id).to_a.select do |p|
          (p.clubs.uniq.map(&:cc_id).compact & club_cc_ids).present?
        end
        if players_to_merge.present?
          Player.merge_players(player_master, players_to_merge)
          Rails.logger.info "====== MERGED #{k} from [#{[players_to_merge.map do |p|
            [p.id, p.cc_id, p.dbu_nr]
          end]}] with [#{[player_master.id, player_master.cc_id,
                          player_master.dbu_nr]}]"
        end
        player_master.reload.update(cc_id: cc_id)
      end
    end
  end

  def self.merge_duplicates
    # get duplicates
    fl_names = []
    Player.select("fl_name").where(type: nil).group("type", :fl_name).having("count(*) > 1").each do |pl|
      fl_names << pl.fl_name
    end
    # merge 999000000 Players
    Player.where(type: nil, fl_name: fl_names).where.not(ba_id: nil).where("ba_id > 999000000").to_a.each do |pl|
      club = pl.club
      pl_master = Player
                    .where(type: nil, fl_name: pl.fl_name)
                    .where("ba_id is null OR ba_id < 999000000").to_a
                    .find { |p| p.club.andand.id.to_i == club.andand.id.to_i }
      next unless pl_master.present?

      Player.merge_players(pl_master, [pl])
      Rails.logger.info "====== MERGED #{pl.fl_name} from [#{[pl.id,
                                                              pl.ba_id]}] with [#{[pl_master.id, pl_master.ba_id]}]"
    end

    # SeasonParticipation.
    #   joins("left outer join players on players.id = season_participations.player_id").
    #   where(players: { type: nil }).
    #   #where(status: nil, season_id: 14).
    #   inject([]) do |memo, sp|
    #   memo << sp.player.andand.fl_name if Player.where(type: nil, fl_name: sp.player.andand.fl_name).count > 1; memo
    # end.
    # raise StandardError "FALSE IMPLEMENTATION - DO NOT USE IT"
    # Player.select(:fl_name).where(type: nil).group(:fl_name).having("count(*) > 1").map(&:fl_name).each do |fl_name|
    #   ba_id_max = Player.where(type: nil).where(fl_name: fl_name).where.not(ba_id: nil)
    #     .where("ba_id < 999000000").all.map(&:ba_id).max
    #   if ba_id_max.present?
    #     master = Player.where(type: nil).where(fl_name: fl_name).where(ba_id: ba_id_max).first
    #     ids = Player.where(type: nil).where(fl_name: fl_name).ids - [master.id]
    #     Player.merge_players(master, Player.where(id: ids).to_a)
    #   else
    #     Rails.logger.info "===== scrape ===== WARNING player '#{fl_name}' - no ba_id"
    #     master = Player.where(type: nil).where(fl_name: fl_name).first
    #     ids = Player.where(type: nil).where(fl_name: fl_name).ids - [master.id]
    #     Player.merge_players(master, Player.where(id: ids).to_a)
    #   end
    # end
  end

  def self.cross_domain_player_search(fl_name, opts = {})
    players = []
    name_parts = fl_name.split(/\s+/).map(&:strip)
    partitions = name_parts.count - 1
    player_found = false
    (1..partitions).each_with_index do |_p, ix|
      firstname = name_parts[0..ix].join(" ")
      lastname = name_parts[ix + 1..].join(" ")
      shortnames = opts[:only_shortnames].present? ? Array(opts[:only_shortnames]) : Region::SHORTNAMES_CC
      shortnames.each do |r_shortname|
        region = Region.find_by_shortname(r_shortname)
        next if region.blank?

        next unless region.cc_id.present?

        url = region.public_cc_url_base
        msg, doc = region.post_cc_public("suche", {
          pno: "",
          s: "",
          f: region.cc_id,
          v: firstname,
          n: lastname,
          pa: "",
          lastPageNo: "",
          nextPageNo: 1
        })
        if msg == "OK"
          player_table = doc.css("article section table")[1]
          player_found = false
          if player_table.present?
            player_table.css("tr").each do |tr|
              next if tr.css("th").count.positive?

              dbu_nr = nil
              pass_nr = nil
              player_link_a = tr.css("a")[0]
              next if player_link_a.blank?

              player_link = tr.css("a")[0]["href"]
              player_url = url + player_link
              u, p = player_url.split("p=")
              params = p.split("-")
              params[3] = params[4]
              params[1] = params[2] = ""
              p = params.join("-")
              player_url = "#{u}p=#{p}"
              Rails.logger.info "reading #{player_url}"
              uri = URI(player_url)
              player_html = Net::HTTP.get(uri)
              player_doc = Nokogiri::HTML(player_html)
              detail_table = player_doc.css("aside section table")[0]
              clubs = []
              detail_table.css("tr").each do |tr_d|
                case tr_d.css("td")[0].text.strip
                when "Pass-Nr."
                  pass_nr = tr_d.css("td")[1].text.strip.to_i
                when "DBU-Nr."
                  dbu_nr = tr_d.css("td")[1].text.strip.to_i
                when "Vereine"
                  club_links = tr_d.css("td")[1].css("a")
                  club_links.each do |club_link|
                    club_name = club_link.text.strip
                    club_cc_id = club_link["href"].split("p=")[1].split(/[-|]/)[3].to_i
                    clubs << [club_name, club_cc_id]
                  end
                else
                  clubs
                end
              end
              players << [firstname, lastname, region.shortname, pass_nr, dbu_nr, clubs]
              player_found = true
            end
          end
        else
          Rails.logger.info "==== scrape ==== IO PROBLEM "
          return nil
        end
      end
    end
    unless player_found
      Rails.logger.info "==== scrape ==== WARNING Player #{fl_name} probably exists in \
 other permutation - check manually!!!"
    end
    players
  end

  def self.fix_from_shortnames(lastname, firstname, season, region,
                               club_str_, tournament, allow_players_outside_ba,
                               allow_creates, position)
    if firstname&.match(/.*\((.*)\)/)
      firstname.gsub!(/\s*\((.*)\)/, "")
    end
    return nil if club_str_.nil?
    club_str = club_str_.strip.gsub("  ", " ")
    player = nil
    club = Club.where("synonyms ilike ?", "%#{club_str}%").to_a.find do |cb|
      cb.synonyms.split("\n").include?(club_str)
    end
    if club.present?
      season_participations = SeasonParticipation.joins(:player).joins(:club)
                                                 .joins(:season)
                                                 .where(seasons: { id: season.id }, players: { firstname: firstname,
                                                                                               lastname: lastname })
                                                 .where(
                                                   "clubs.synonyms ilike ?", "%#{club_str}%"
                                                 ).to_a.select do |sp|
        sp.club.synonyms.split("\n").include?(club_str)
      end
      if season_participations.count == 1
        season_participation = season_participations.first
        player = season_participation&.player
        unless season_participation&.club_id == club.id
          real_club = season_participations.first&.club
          if real_club.present?
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz: Player #{lastname}, #{firstname} \
not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - Fixed: \
Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], \
Region #{real_club.region&.shortname}, season #{season.name}!"
            unless SeasonParticipation.find_by_player_id_and_season_id_and_club_id(
              player&.id, season.id, real_club.id
            )
              (sp = SeasonParticipation.new(player_id: player&.id, season_id: season.id,
                                            club_id: real_club.id); sp.region_id = region.id; sp.save)

            end
          end
        end
        if tournament.present?
          seeding = Seeding.find_by_player_id_and_tournament_id_and_tournament_type(player&.id, tournament.id,
                                                                                    tournament.class.name)
          unless seeding.present?
            seeding = Seeding.new(player_id: player&.id, tournament: tournament, position: position)
            seeding.region_id = region.id
            if seeding.save
              Rails.logger.info("Seeding[#{seeding.id}] created.")
            else
              Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player&.id}: #{seeding.errors.full_messages.join(', ')}")
            end
          end
        end
        state_ix = 0
      elsif season_participations.count.zero?
        # Use PlayerFinder to find or create player intelligently
        # This prevents duplicate player creation
        player_fixed = Player.find_or_create_player(
          firstname: firstname,
          lastname: lastname,
          club_id: club.id,
          region_id: region.id,
          season_id: season.id,
          allow_create: (allow_players_outside_ba && allow_creates)
        )
        
        if player_fixed.present?
          logger.info "==== scrape ==== [scrape_tournaments] Player '#{firstname} #{lastname}' found/created: Player #{player_fixed.id}"
          
          # Ensure SeasonParticipation exists
          sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id)
          unless sp.present?
            sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
            sp.region_id = region.id
            sp.save
          end
          
          # Ensure Seeding exists
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player_fixed.id, tournament_id: tournament.id, position: position)
              seeding.region_id = region.id
              if seeding.save
                Rails.logger.info("Seeding[#{seeding.id}] created.")
              else
                Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player_fixed.id}: #{seeding.errors.full_messages.join(', ')}")
              end
            end
          end
        else
          logger.warn "==== scrape ==== [scrape_tournaments] Could not find or create player '#{firstname} #{lastname}'"
        end
        
        state_ix = 0
        
        # LEGACY CODE PATH - kept for backward compatibility but should rarely execute now
        players = Player.where(type: nil).where(firstname: firstname, lastname: lastname)
        if players.count == 1
          player_fixed = players.first
          if player_fixed.present?
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz: Player #{lastname}, #{firstname} \
is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id)
            unless sp.present?
              sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              sp.region_id = region.id
              sp.save
            end
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - fixed: \
Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], \
region #{region.shortname} and season #{season.name}"
            if tournament.present?
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed.id, tournament_id: tournament.id, position: position)
                seeding.region_id = region.id
                if seeding.save
                  Rails.logger.info("Seeding[#{seeding.id}] created.")
                else
                  Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player_fixed.id}: #{seeding.errors.full_messages.join(', ')}")
                end
              end
            end
          end
          state_ix = 0
        elsif players.count > 1
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - Fatal: Ambiguous:
Player #{lastname}, #{firstname} not active everywhere but exists in
Clubs [#{players.map(&:club).map { |c| "#{c.andand.shortname} [#{c.andand.ba_id}]" }}] "
          clubs_str = players.map(&:club).map do |c|
            "#{c.andand.shortname} [#{c.andand.ba_id}]"
          end.first
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - temporary fix: \
Assume Player #{lastname}, #{firstname} is active in Clubs [#{clubs_str}] "
          player_fixed = players.first
          if player_fixed.present?
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, club.id)
            unless sp.present?
              sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              sp.region_id = region.id
              sp.save
            end
            if tournament.present?
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed.id, tournament_id: tournament.id, position: position)
                seeding.region_id = region.id
                if seeding.save
                  Rails.logger.info("Seeding[#{seeding.id}] created.")
                else
                  Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player_fixed.id}: #{seeding.errors.full_messages.join(', ')}")
                end
              end
            end
          end
          state_ix = 0
        end
      else
        # (ambiguous clubs)
        if season_participations.map(&:club_id).uniq.include?(club.id)
          season_participation = season_participations.find { |sp| sp.club_id == club.id }
          if season_participation.present?
            player = season_participation.player
            if tournament.present?
              seeding = Seeding.find_by_player_id_and_tournament_id(player.id, tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player.id, tournament_id: tournament.id, position: position)
                seeding.region_id = region.id
                seeding.save
              end
            end
          end
        else
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz: Player #{lastname}, #{firstname} is not \
active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
          fixed_season_participation = season_participations.last
          if fixed_season_participation.present?
            fixed_club = fixed_season_participation.club
            player_fixed = fixed_season_participation.player
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - fixed: Player #{lastname}, #{firstname} \
playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} \
and season #{season.name}"
            sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                                 fixed_club.id)
            unless sp.present?
              sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: fixed_club.id)
              sp.region_id = region.id
              sp.save
            end
            if tournament.present?
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id)
              unless seeding.present?
                seeding = Seeding.new(player_id: player_fixed.id, tournament_id: tournament.id, position: position)
                seeding.region_id = region.id
                if seeding.save
                  Rails.logger.info("Seeding[#{seeding.id}] created.")
                else
                  Rails.logger.error("==== scrape ==== Failed to create seeding for player #{player_fixed.id}: #{seeding.errors.full_messages.join(', ')}")
                end
              end
            end
          end
        end
        state_ix = 0
      end
    else
      logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - fatal: Club #{club_str}, \
region #{region.shortname} not found!! Typo?"
      fixed_club = region.clubs.new(name: club_str, shortname: club_str)
      fixed_club.region_id = region.id
      fixed_club.save
      fixed_club.update(ba_id: 999_000_000 + fixed_club.id)
      
      if allow_creates
        # Use PlayerFinder instead of direct creation
        player_fixed = Player.find_or_create_player(
          firstname: firstname,
          lastname: lastname,
          club_id: fixed_club.id,
          region_id: region.id,
          season_id: season.id,
          allow_create: true
        )
        
        if player_fixed.present?
          sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id, fixed_club.id)
          unless sp.present?
            sp = SeasonParticipation.new(player_id: player_fixed.id, season_id: season.id, club_id: fixed_club.id)
            sp.region_id = region.id
            sp.save
          end
          
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - temporary fix: Club #{club_str} created \
in region #{region.shortname}"
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistenz - temporary fix: Player #{lastname}, \
#{firstname} (ID: #{player_fixed.id}) playing for Club #{club_str}"
          
          if tournament.present?
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, tournament.id)
            unless seeding.present?
              seeding = Seeding.new(player_id: player_fixed.id, tournament: tournament, position: position)
              seeding.region_id = region.id
              seeding.save
            end
          end
        end
        state_ix = 0
      end
    end
    [player || player_fixed, club || fixed_club, seeding, state_ix]
  rescue StandardError => e
    Tournament.logger.info "===== scrape =====  StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
    nil
  end

  def self.merge_players(player_ok, player_tmp_arr)
    cc_id = player_ok.cc_id || Array(player_tmp_arr).map(&:cc_id).compact.first
    dbu_nr = player_ok.dbu_nr || Array(player_tmp_arr).select do |p|
      p.dbu_nr.present? && p.dbu_nr < 998_000_000
    end.map(&:dbu_nr).compact.first
    player_ok.update(cc_id: cc_id, dbu_nr: dbu_nr)
    Array(player_tmp_arr).each do |player_tmp|
      Player.transaction do
        SeasonParticipation.where(player_id: player_tmp.id).each do |sp|
          if SeasonParticipation.where(player_id: player_ok.id, season_id: sp.season_id,
                                       club_id: sp.club_id).first.present?
            # Duplicate SeasonParticipation exists, delete this one
            sp.destroy
          else
            # Move to master player
            sp.update(player_id: player_ok.id)
          end
        end
        GameParticipation.where(player_id: player_tmp.id).all.each { |l| l.update(player_id: player_ok.id) }
        PlayerRanking.where(player_id: player_tmp.id).all.each { |l| l.update(player_id: player_ok.id) }
        Seeding.where(player_id: player_tmp.id).all.each { |l| l.update(player_id: player_ok.id) }
        PartyGame.where(player_a_id: player_tmp.id).all.each { |l| l.update(player_a_id: player_ok.id) }
        PartyGame.where(player_b_id: player_tmp.id).all.each { |l| l.update(player_b_id: player_ok.id) }
        if player_tmp.id != player_ok.id
          player_tmp.unprotected = true
          player_tmp.destroy
        end
        Team.where("data ilike '%#{player_ok.fl_name.gsub("'", "''")}%'").each do |team|
          players = team.data["players"]
          players.each do |players_hash|
            if players_hash["fl"].present?
              next unless players_hash["fl"] != player_ok.fl_name
            end
            next unless players_hash["ba_id"] != player_ok.ba_id || players_hash["player_id"] != player_ok.id

            players_hash["player_id"] = player_ok.id
            players_hash["ba_id"] = player_ok.ba_id
            team.data_will_change!
          end
          team.save!
        end
      end
    end
  end

  def self.fix_player_without_ba_id(region, firstname, lastname, should_be_ba_id = nil, should_be_club_id = nil)
    region.fix_player_without_ba_id(firstname, lastname, should_be_ba_id, should_be_club_id)
  end

  def self.remove_inactive_guests(location)
    # Find all guest players
    club = location.club
    default_guest_a = Player.default_guest(:a, location)
    default_guest_b = Player.default_guest(:b, location)
    guest_players = Player.joins(season_participations: %i[club season])
                          .where(clubs: { id: club.id })
                          .where.not(id: [default_guest_a.player.id,
                                          default_guest_b.player.id])
                          .where(season_participations: { status: "guest" })
                          .where(seasons: { id: Season.current_season&.id })
                          .order("fl_name")
    # For each guest player, check if they have any recent game participations
    guest_players.each do |player|
      last_participation = player.game_participations.order(created_at: :desc).first

      # If no recent participation or last participation was more than 2 weeks ago
      if last_participation.nil? || last_participation.created_at < 2.weeks.ago
        # Delete the player
        player.destroy
      end
    end
  end

  def self.find_duplicates_by_fl_name
    # Find all fl_names that have more than one player
    duplicate_fl_names = Player.where(type: nil)
                               .group(:fl_name)
                               .having('count(*) > 1')
                               .pluck(:fl_name)

    # Return hash with fl_name as key and array of players as value
    duplicates = {}
    duplicate_fl_names.each do |fl_name|
      duplicates[fl_name] = Player.where(type: nil, fl_name: fl_name).to_a
    end

    duplicates
  end

  def self.find_duplicates_by_fl_name_simple
    # Simple version that returns just the fl_names with counts
    Player.where(type: nil)
          .group(:fl_name)
          .having('count(*) > 1')
          .count
  end

  def self.find_duplicates_by_dbu_nr
    # Find all dbu_nrs that have more than one player
    duplicate_dbu_nrs = Player.where(type: nil)
                              .where.not(dbu_nr: nil)
                              .group(:dbu_nr)
                              .having('count(*) > 1')
                              .pluck(:dbu_nr)

    # Return hash with dbu_nr as key and array of players as value
    duplicates = {}
    duplicate_dbu_nrs.each do |dbu_nr|
      duplicates[dbu_nr] = Player.where(type: nil, dbu_nr: dbu_nr).to_a
    end

    duplicates
  end

  def self.find_duplicates_by_dbu_nr_simple
    # Simple version that returns just the dbu_nrs with counts
    Player.where(type: nil)
          .where.not(dbu_nr: nil)
          .group(:dbu_nr)
          .having('count(*) > 1')
          .count
  end
end
