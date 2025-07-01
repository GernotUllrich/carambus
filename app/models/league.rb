# frozen_string_literal: true

# == Schema Information
#
# Table name: leagues
#
#  id                 :bigint           not null, primary key
#  ba_id2             :integer
#  cc_id2             :integer
#  game_parameters    :text
#  game_plan_locked   :boolean          default(FALSE), not null
#  name               :string
#  organizer_type     :string
#  registration_until :date
#  shortname          :string
#  source_url         :string
#  staffel_text       :string
#  sync_date          :datetime
#  type               :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  ba_id              :integer
#  cc_id              :integer
#  discipline_id      :integer
#  game_plan_id       :integer
#  organizer_id       :integer
#  season_id          :integer
#
# Indexes
#
#  index_leagues_on_ba_id_and_ba_id2  (ba_id,ba_id2) UNIQUE
#
class League < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable

  self.ignored_columns = ["region_ids"]

  # Configure PaperTrail to ignore automatic timestamp updates and sync_date changes
  # This prevents unnecessary version records during scraping operations
  has_paper_trail ignore: [:updated_at, :sync_date] unless Carambus.config.carambus_api_url.present?

  belongs_to :discipline, optional: true
  belongs_to :season, optional: true
  has_one :league_cc, -> { where(context: "nbv") }, dependent: :destroy
  has_many :league_teams
  has_many :parties
  has_many :tournaments
  belongs_to :organizer, polymorphic: true, optional: true
  belongs_to :game_plan, optional: true

  serialize :game_parameters, coder: YAML, type: Hash

  # Validations to ensure proper uniqueness
  validates :name, presence: true
  validates :shortname, presence: true, if: -> { organizer_type == 'Region' }

  # Primary uniqueness: CC IDs are the most important identifiers from scraping
  validates :cc_id, uniqueness: {
    scope: [:cc_id2, :organizer_id, :organizer_type],
    message: "must be unique within the same organizer (cc_id + cc_id2 combination)"
  }, if: -> { cc_id.present? && organizer_type == 'Region' }

  # Secondary uniqueness: Ensure no duplicate leagues with same name and staffel
  # This is mainly for cases where cc_id might not be set yet
  validates :name, uniqueness: {
    scope: [:season_id, :organizer_id, :organizer_type, :staffel_text],
    message: "must be unique within the same region, season, and staffel"
  }, if: -> { organizer_type == 'Region' && cc_id.blank? }

  GAME_PARAMETER_DEFAULTS = {
    pool: {
      substitutes: true,
      kickoff_switches_with: "set",
      match_points: {
        win: 0,
        draw: 0,
        lost: 0
      },
      extra_shootout_match_points: {
        win: 0,
        lost: 0
      },
      victory_to_nil: -1, # (*) Es werden {victory_to_nil}:0 Partie-Punkte bei einem Nichtantritt erfasst.
      handicap: nil, # (Diese Einstellung ermöglicht es, ein Handycap einzugeben.)
      plausi: nil, # (Warnung, falls ein Spieler mindestens zweimal in der screen Disziplin eingesetzt wird.)
      bez_partie: nil, # (Bezeicher in Rundenzeile: z.B. Frames, Legs, Partien, ...)
      bez_brett: nil, # (Bezeicher in Rundenzeile: z.B. Brett, Paarung, ...)
      rang_partie: nil, # (Aktivierung erlaubt, dass z.B. Partien, Frames oder Legs in der Tabelle als zusätzliche Spalte angezeigt und gewertet werden.)
      rang_mgd: nil, # (Aktivierung erlaubt, dass z.B. Mannschaftsgesamtdurchschnitt (Karambol-MGD) in der Tabelle als zusätzliche Spalte angezeigt und gewertet wird.)
      rang_kegel: nil, # (Aktivierung erlaubt, dass z.B. zusätzliche, Billard-Kegel spezifische Spalten in der Tabelle angezeigt und gewertet werden.)
      ersatzspieler_regel: 0,
      # 0: Keine Ersatzspieler-Regelung
      # 1: Ersatzspieler NUR aus direkt nachfolgender Mannschaft möglich
      # 2: Ersatzspieler aus ALLEN nachfolgenden Mannschaften möglich
      row_type_id: nil
      # 20; 10-Ball
      # 21: 10-Ball Doppel
      # 1: 14/1e
      # 2: 8-Ball
      # 25: 8-Ball Doppel
      # 22: 8-Ball Sudden Death
      # 3: 9-Ball
      # 52: 9-Ball (5er Team)
      # 23: 9-Ball Doppel
      # 26: Ausstoßen
      # 4: Gesamtsumme
      # 5: Neue Runde
      # 51: Shootout (3er Team)
      # 24: Shootout (4er Team)
    },
    karambol: {
      substitutes: true,
      match_points: {
        win: 0,
        draw: 0,
        lost: 0
      },
      kickoff_switches_with: "set",
      victory_to_nil: -1, # (*) Es werden {victory_to_nil}:0 Partie-Punkte bei einem Nichtantritt erfasst.
      handicap: nil, # (Diese Einstellung ermöglicht es, ein Handycap einzugeben.)
      plausi: nil, # (Warnung, falls ein Spieler mindestens zweimal in der selben Disziplin eingesetzt wird.)
      bez_partie: nil, # (Bezeicher in Rundenzeile: z.B. Frames, Legs, Partien, ...)
      bez_brett: nil, # (Bezeicher in Rundenzeile: z.B. Brett, Paarung, ...)
      rang_partie: nil, # (Aktivierung erlaubt, dass z.B. Partien, Frames oder Legs in der Tabelle als zusätzliche Spalte angezeigt und gewertet werden.)
      rang_mgd: nil, # (Aktivierung erlaubt, dass z.B. Mannschaftsgesamtdurchschnitt (Karambol-MGD) in der Tabelle als zusätzliche Spalte angezeigt und gewertet wird.)
      rang_kegel: nil, # (Aktivierung erlaubt, dass z.B. zusätzliche, Billard-Kegel spezifische Spalten in der Tabelle angezeigt und gewertet werden.)
      ersatzspieler_regel: 0,
      # 0: Keine Ersatzspieler-Regelung
      # 1: Ersatzspieler NUR aus direkt nachfolgender Mannschaft möglich
      # 2: Ersatzspieler aus ALLEN nachfolgenden Mannschaften möglich
      row_type_id: nil
      # 20; 10-Ball
      # 21: 10-Ball Doppel
      # 1: 14/1e
      # 2: 8-Ball
      # 25: 8-Ball Doppel
      # 22: 8-Ball Sudden Death
      # 3: 9-Ball
      # 52: 9-Ball (5er Team)
      # 23: 9-Ball Doppel
      # 26: Ausstoßen
      # 4: Gesamtsumme
      # 5: Neue Runde
      # 51: Shootout (3er Team)
      # 24: Shootout (4er Team)
    },
    snooker: {
      substitutes: true,
      match_points: {
        win: 0,
        draw: 0,
        lost: 0
      },
      victory_to_nil: -1, # (*) Es werden {victory_to_nil}:0 Partie-Punkte bei einem Nichtantritt erfasst.
      handicap: nil, # (Diese Einstellung ermöglicht es, ein Handycap einzugeben.)
      plausi: nil, # (Warnung, falls ein Spieler mindestens zweimal in der selben Disziplin eingesetzt wird.)
      bez_partie: nil, # (Bezeicher in Rundenzeile: z.B. Frames, Legs, Partien, ...)
      bez_brett: nil, # (Bezeicher in Rundenzeile: z.B. Brett, Paarung, ...)
      rang_partie: nil, # (Aktivierung erlaubt, dass z.B. Partien, Frames oder Legs in der Tabelle als zusätzliche Spalte angezeigt und gewertet werden.)
      rang_mgd: nil, # (Aktivierung erlaubt, dass z.B. Mannschaftsgesamtdurchschnitt (Karambol-MGD) in der Tabelle als zusätzliche Spalte angezeigt und gewertet wird.)
      rang_kegel: nil, # (Aktivierung erlaubt, dass z.B. zusätzliche, Billard-Kegel spezifische Spalten in der Tabelle angezeigt und gewertet werden.)
      ersatzspieler_regel: 0,
      # 0: Keine Ersatzspieler-Regelung
      # 1: Ersatzspieler NUR aus direkt nachfolgender Mannschaft möglich
      # 2: Ersatzspieler aus ALLEN nachfolgenden Mannschaften möglich
      row_type_id: nil
      # 20; 10-Ball
      # 21: 10-Ball Doppel
      # 1: 14/1e
      # 2: 8-Ball
      # 25: 8-Ball Doppel
      # 22: 8-Ball Sudden Death
      # 3: 9-Ball
      # 52: 9-Ball (5er Team)
      # 23: 9-Ball Doppel
      # 26: Ausstoßen
      # 4: Gesamtsumme
      # 5: Neue Runde
      # 51: Shootout (3er Team)
      # 24: Shootout (4er Team)
    },
    kegel: {
      substitutes: true,
      match_points: {
        win: 0,
        draw: 0,
        lost: 0
      },
      victory_to_nil: -1, # (*) Es werden {victory_to_nil}:0 Partie-Punkte bei einem Nichtantritt erfasst.
      handicap: nil, # (Diese Einstellung ermöglicht es, ein Handycap einzugeben.)
      plausi: nil, # (Warnung, falls ein Spieler mindestens zweimal in der selben Disziplin eingesetzt wird.)
      bez_partie: nil, # (Bezeicher in Rundenzeile: z.B. Frames, Legs, Partien, ...)
      bez_brett: nil, # (Bezeicher in Rundenzeile: z.B. Brett, Paarung, ...)
      rang_partie: nil, # (Aktivierung erlaubt, dass z.B. Partien, Frames oder Legs in der Tabelle als zusätzliche Spalte angezeigt und gewertet werden.)
      rang_mgd: nil, # (Aktivierung erlaubt, dass z.B. Mannschaftsgesamtdurchschnitt (Karambol-MGD) in der Tabelle als zusätzliche Spalte angezeigt und gewertet wird.)
      rang_kegel: nil, # (Aktivierung erlaubt, dass z.B. zusätzliche, Billard-Kegel spezifische Spalten in der Tabelle angezeigt und gewertet werden.)
      ersatzspieler_regel: 0,
      # 0: Keine Ersatzspieler-Regelung
      # 1: Ersatzspieler NUR aus direkt nachfolgender Mannschaft möglich
      # 2: Ersatzspieler aus ALLEN nachfolgenden Mannschaften möglich
      row_type_id: nil
      # 20; 10-Ball
      # 21: 10-Ball Doppel
      # 1: 14/1e
      # 2: 8-Ball
      # 25: 8-Ball Doppel
      # 22: 8-Ball Sudden Death
      # 3: 9-Ball
      # 52: 9-Ball (5er Team)
      # 23: 9-Ball Doppel
      # 26: Ausstoßen
      # 4: Gesamtsumme
      # 5: Neue Runde
      # 51: Shootout (3er Team)
      # 24: Shootout (4er Team)
    },
    row: {
      type: nil, # discipline etc (row_type_id)
      home_brett: nil, # e.g home-brett 2 - visitor_brett 3 : An 2 gesetzter gegen an 3 gesetzter
      visitor_brett: nil,
      player_a: "Freilos", # Name Spieler (Heim)
      player_b: "Freilos", # Name Spieler (Gast)
      sets: nil, # Gewinnsätze (default ist 1)
      score: nil, # Gewinnspiele bzw. Ausspielziel Bälle (14.1e z.B. 120)
      ppg: nil, # Partie-Punkte G - U - V
      ppu: nil,
      ppv: nil,
      mpg: nil, # Extra Match-Punkte G - V
      mpv: nil,
      inning: nil # Ausspielziel Aufnahmen (14.1e)
    },
    rows: [
      { type: "Neue Runde", r_no: 1 },
      { type: "14/1", seqno: 1,
        home_brett: nil,
        visitor_brett: nil,
        player_a: "TBD", # Name Spieler (Heim)
        player_b: "TBD", # Name Spieler (Gast)
        sets: 1, # Gewinnsätze
        score: 100, # Gewinnspiele bzw. Ausspielziel Bälle (14.1e)
        ppg: 1, # Partie-Punkte G - U - V
        ppu: 0,
        ppv: 0,
        mpg: 3, # Match-Punkte G - V
        mpv: 0,
        inning: nil } # Ausspielziel Aufnahmen (14.1e)
    ]
  }.freeze

  DEBUG = true

  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  REFLECTION_KEYS = %w[versions league_teams parties tournaments organizer league_plan discipline season
                       league_cc].freeze
  COLUMN_NAMES = {
    "Name" => "leagues.name",
    "Organizer" => "regions.shortname", # inner join on organizer of type region
    "Season" => "seasons.name",
    "BA_ID" => "leagues.ba_id",
    "CC_ID" => "leagues.cc_id",
    "BA_ID2" => "leagues.ba_id2",
    "CC_ID2" => "leagues.cc_id2",
    "Discipline" => "disciplines.name"
  }.freeze

  def self.search_hash(params)
    {
      model: League,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: "#{[params[:sSearch], params[:search]].compact.join("&")}",
      column_names: League::COLUMN_NAMES,
      raw_sql: "(leagues.name ilike :search)
 or (regions.name ilike :search)
 or (regions.shortname ilike :search)
 or (seasons.name ilike :search)
 or (disciplines.name ilike :search)
 or (leagues.cc_id = :isearch)",
      joins: [
        :season,
        :discipline,
        "Left outer join regions on leagues.organizer_id = regions.id and leagues.organizer_type = 'Region'",
      ]
    }
  end

  def name
    "#{read_attribute(:name)}#{" #{staffel_text}" if staffel_text.present?}"
  end

  def branch
    branch = discipline
    branch = branch.super_discipline while branch.andand.super_discipline.present?
    branch
  end

  def competition
    Competition.where(super_discipline_id: discipline_id).where("name ilike '%Mannschaft%'").first
  end

  # scrape_leagues_from_cc
  def self.scrape_leagues_from_cc(region, season, opts = {})
    if region.shortname == "BBV"
      scrape_bbv_leagues(region, season, opts)
    else
      # return unless region.shortname == "BVBW"
      url = region.public_cc_url_base
      leagues_url = "#{url}sb_spielplan.php?eps=100000&s=#{season.name}"
      Rails.logger.info "reading #{leagues_url} - region #{region.shortname} league tournaments season #{season.name}"
      uri = URI(leagues_url)
      leagues_html = Net::HTTP.get(uri)
      leagues_doc = Nokogiri::HTML(leagues_html)
      table = leagues_doc.css("article table.silver")[1]

      if table.present?
        table.css("tr").each do |tr|
          cc_id2s = []
          staffel_texts = []
          next unless (a = tr.css("td a.cc_bluelink")).present?

          link = a[0]["href"]
          params = link.split("p=")[1].split(/[-|]/)
          region_cc_id = params[0].to_i
          season_name = params[2]
          league_cc_id = params[3].to_i
          next if region_cc_id != region.cc_id || season_name != season.name

          title = a[0].text.strip
          short = tr.css("td")[1].text.strip
          n_staffel = tr.css("td")[2].text.strip.to_i
          staffel_link = url + link
          Rails.logger.info "reading #{staffel_link}"
          uri = URI(staffel_link)
          staffel_html = Net::HTTP.get(uri)
          staffel_doc = Nokogiri::HTML(staffel_html)
          details_table = staffel_doc.css("aside > section > table")[0]
          branch = nil
          skip = false
          details_table.css("tr").each do |trx|
            if trx.css("td")[0].text == "Wettbewerb"
              branch_str = trx.css("td")[1].text.split(":")[0].strip
              branch = Branch.find_by_name(branch_str)
              # do NOT break here, so we can still check for 'Quelle'
            end
            if trx.css("td")[0].text == "Quelle"
              skip = true
              break
            end
          end
          next if skip

          if n_staffel > 1
            tabstrip_a = staffel_doc.css("aside > section > table.silver ul.tabstrip li a")
            tabstrip_a.each do |ax|
              cc_id2s << ax["href"].split("p=")[1].split(/[-|]/)[4].to_i
              staffel_texts << ax.text.strip
            end
          end
          cc_id2s = cc_id2s.presence || [nil]
          cc_id2s.each_with_index do |cc_id2, ix|
            # Primary lookup: Find by CC IDs (most specific and reliable)
            attrs = { cc_id: league_cc_id, organizer: region, staffel_text: staffel_texts[ix], season: season,
                      cc_id2: cc_id2 }.compact
            league = League.where(attrs).first

            unless league.present?
              # Secondary lookup: If not found by CC IDs, try by name and other attributes
              # This handles cases where cc_id might not be set yet
              attrs = { season: season, name: title, staffel_text: staffel_texts[ix],
                        discipline: branch, organizer: region }.compact
              league = League.where(attrs).first

              # If still not found, create a new league
              league ||= League.new(season: season, name: title, staffel_text: staffel_texts[ix], discipline: branch,
                                    organizer: region)
            end

            # Update league attributes - cc_id and cc_id2 are the primary identifiers
            attrs = { shortname: short, cc_id: league_cc_id, cc_id2: cc_id2, discipline: branch,
                      staffel_text: staffel_texts[ix] }.compact
            league.assign_attributes(attrs)
            league.source_url = staffel_link
            if league.changed?
              league.region_id = region.id
              league.save
            end

            if opts[:league_details]
              # Collect all records from league details for batch tagging
              league.scrape_single_league_from_cc(opts)
            end
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.info "====== problem with leagues in region #{region.name} - leagues_url: #{leagues_url} e93 \
#{e} #{e.backtrace&.to_a&.join("/n")}"
    raise StandardError, "====== problem with leagues in region #{region.name} - leagues_url: #{leagues_url} e93 \
#{e} #{e.backtrace&.to_a&.join("/n")}"
  end

  # scrape_single_league_from_cc
  def scrape_single_league_from_cc(opts = {})
    return unless opts[:league_details]
    if opts[:cleanup]
      self.parties.map{|p| p.party_games.destroy_all}
      self.parties.destroy_all
      self.league_teams.destroy_all
    end
    organizer = self.organizer
    region = organizer if organizer.is_a?(Region)
    if organizer.is_a?(Region) && organizer.shortname == "BBV"
      league_url, league_taggings = scrape_single_bbv_league(organizer, opts)
    else
      logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
      season = self.season
      organizer = self.organizer
      league_url = nil
      if organizer.blank? || !organizer.is_a?(Region)
        logger.info "===== scrape ===== Problem scraping league - e146"
        return
      end
      url = organizer.public_cc_url_base
      league_p = "sb_spielplan.php?p=#{organizer.cc_id}--#{season.name}-#{cc_id}#{"-#{cc_id2}" if cc_id2.present?}"
      league_url = url + league_p
      Rails.logger.info "reading #{league_url}"
      uri = URI(league_url)
      league_html = Net::HTTP.get(uri)
      league_doc = Nokogiri::HTML(league_html)

      # TODO what's the following code about??
      if source_url.present?
        staffel_link = source_url
        Rails.logger.info "reading #{staffel_link}"
        uri = URI(staffel_link)
        staffel_html = Net::HTTP.get(uri)
        staffel_doc = Nokogiri::HTML(staffel_html)
        details_table = staffel_doc.css("aside > section > table")[0]
        skip = false
        details_table.css("tr").each do |tr|
          next unless tr.css("td")[0].text == "Quelle"

          skip = true
          ref = tr.css("a")[0].andand["href"]
          Rails.logger.info "==== scrape ==== This league must be scraped from source #{ref}"
          break
        end
        return if skip
      end

      # scrape league teams
      team_table = league_doc.css("aside > section > table > tr > td > table")[0]
      if team_table.blank?
        Rails.logger.info "==== scrape ==== Error - No Teams for league #{name}"
        return
      end
      clubs_cache = []
      league_teams_cache = []
      league_team_players = nil
      ## scrape Team Table
      team_table.css("tr").each do |tr|
        next unless tr.css("td").count.positive?

        _rank = tr.css("td")[0].text.to_i
        team_a = tr.css("td")[1].css("a").andand[0] || tr.css("td")[2].css("a").andand[0]
        team_link = team_a["href"].gsub("mannschaftsplan", "mannschaft")
        team_url = url + team_link
        Rails.logger.info "reading #{team_url}"
        uri = URI(team_url)
        team_html = Net::HTTP.get(uri)
        team_doc = Nokogiri::HTML(team_html)
        team_club_table = team_doc.css("aside > section > table")[2]
        if team_club_table.blank?
          team_club_name = team_a.text.gsub(/\(.*\)$/, "").strip.gsub(/\s+\d+$/, "").gsub(/\s+[IVX]+$/, "").gsub("1.", "1. ").gsub("1.  ",
                                                                                                                                   "1. ")
          club = Club.where("synonyms ilike ?", "%#{team_club_name}%").to_a.find do |c|
            c.synonyms.split("\n").include?(team_club_name)
          end
        else
          team_club = team_club_table.css("td a")[0]
          team_club_name = team_club.text.strip
          team_club_link = team_club["href"]
          team_club_url = url + team_club_link
          Rails.logger.info "reading #{team_club_url}"
          uri = URI(team_club_url)
          team_club_html = Net::HTTP.get(uri)
          team_club_doc = Nokogiri::HTML(team_club_html)
          team_club_dbu_nr = nil
          team_club_doc.css("aside section table")[0].css("tr").each do |tr__|
            team_club_dbu_nr = tr__.css("td")[1].text.strip.to_i if tr__.css("td")[0].text.strip == "DBU-Nr."
          end
          params_club = team_club_link.split("p=")[1].split(/[|-]/)
          club_cc_id = params_club[3].to_i
          region_id = params_club[0].to_i
          club = team_club_dbu_nr&.positive? ? Club.where(dbu_nr: team_club_dbu_nr).first : nil
          club ||= Club.where(cc_id: club_cc_id, region_id: region_id).first
          club ||= Club.where(name: team_club_name).first
          if club.blank?
            club = Club.where("synonyms ilike ?", "%#{team_club_name}%").to_a.find do |cb|
              cb.synonyms.split("\n").include?(team_club_name)
            end
          end
        end
        if club.blank?
          Rails.logger.info "Error club #{team_club_name} unknown"
          next
        end

        if url =~ /billard-union.net/
          club.dbu_nr = team_club_dbu_nr
        else
          club.cc_id = club_cc_id
        end
        if club.changed?
          club.region_id = region.id
          club.save
        end
        clubs_cache << club if club.present?
        team_name = team_a.text.strip
        params = team_link.split("p=")[1].split(/[-|]/)
        team_cc_id = params[5].to_i
        league_team = league_teams.where(cc_id: team_cc_id).first
        league_team ||= league_teams.new(cc_id: team_cc_id)
        attrs = {
          name: team_name,
          club_id: club.id
        }
        league_team.assign_attributes(attrs)
        league_team.source_url = league_url
        league_team.region_id = region.id
        league_team.save
        league_teams_cache << league_team
        league_team_players ||= {}
        league_team_players[team_name] = {}
        # scrape players of team
        players_table = team_doc.css("aside > section > table")[2]
        if players_table.present?
          players_table.css("tr").each do |tr_p|
            next unless tr_p.css("td a").present?
            next if /^(verein-details|location)/.match?(tr_p.css("a")[0]["href"])

            a_ = tr_p.css("td > a")[1]
            player_link = a_["href"]
            fl_name = a_.text.gsub("  ", " ").strip
            params = player_link.split("p=")[1].split("-")
            player_dbu_nr = params[5].to_i
            player = league_team_players[team_name][fl_name]
            if player.blank?
              if self.organizer.shortname == "DBU"
                player = Player.find_by_dbu_nr(player_dbu_nr)
                if player.blank?
                  player = Player.find_by_fl_name_and_cc_id(fl_name, player_dbu_nr)
                  if player.blank?
                    Rails.logger.info "==== scrape ==== Player #{fl_name} with dbu_nr #{player_dbu_nr}, league cc_id: #{cc_id}, #{name} not in dbu?! Try search by name only"
                    player = Player.find_by_fl_name(fl_name)
                  end
                  if player.blank?
                    Rails.logger.info "==== scrape ==== Player #{fl_name} with dbu_nr #{player_dbu_nr}, league cc_id: #{cc_id}, #{name} not in dbu?! created temprarily"
                    player = Player.new
                    player.firstname = fl_name.split(/\s+/)[0]
                    player.lastname = fl_name.split(/\s+/)[1..].join(" ")
                    player.dbu_nr = player_dbu_nr
                    if player.new_record?
                      player.source_url ||= team_url
                    end
                    if player.changed?
                      player.region_id = region.id
                      player.save
                    end
                    sp_args = {
                      season_id: season_id,
                      player_id: player.id,
                      club_id: club.id
                    }
                    SeasonParticipation.where(sp_args).first ||
                      (sp = SeasonParticipation.new(sp_args); sp.region_id = region.id; sp.save)
                  else
                    player.assign_attributes(dbu_nr: player_dbu_nr)
                    if player.new_record?
                      player.source_url ||= team_url
                    end
                    if player.changed?
                      player.region_id = region.id
                      player.save
                    end
                  end
                end
              else
                player = Player.find_by_fl_name_and_cc_id(fl_name, player_dbu_nr)
                player ||= Player.find_by_fl_name_and_dbu_nr(fl_name, player_dbu_nr)
                player ||= Player.find_by_fl_name(fl_name)
                if player.blank?
                  msg = "==== scrape ==== Fatal ErrorPlayer #{fl_name} with cc_id in region #{self.organizer.shortname}, league cc_id: #{cc_id}, #{name} #{player_dbu_nr} not in region??!"
                  Rails.logger.info msg
                  raise StandardError, msg
                else
                  player.assign_attributes(cc_id: player_dbu_nr)
                end
              end
            end
            league_team_players[team_name][fl_name] = player

            seeding = Seeding.where(league_team: league_team, player: player).first
            seeding ||= league_team.seedings.new(player: player)
            tr_p.css("table > tr > td").each do |td|
              next unless /#{fl_name}/.match?(td.text)

              role = td.text.match(/#{fl_name}.*\((.*)\)/).andand[1]
              seeding.role = role
              break
            end
            if seeding.changed?
              seeding.region_id = region.id
              seeding.save!
            end
          end
        end
        league_team.reload
      end
      header = []
      table = league_doc.css("aside > section > table")[2]
      table = league_doc.css("aside > section > table")[3] if /Location/.match?(table.text)
      game_plan = GAME_PARAMETER_DEFAULTS[branch.name.downcase.to_sym].compact
      game_plan[:rows] = []
      disciplines = {}
      last_cc_id = 0
      remarks = nil
      non_shootout_games = 0
      # scrape game results
      shift = 0
      party_count = 0
      table.css("tr").each do |tr|
        if tr.css("th").count > 1
          header = tr.css("th").map(&:text)
          shift = tr.css("th")[0]['colspan'].to_i == 2 ? 1 : 0
        elsif tr.css("td").count.positive?
          break if tr.css("td").count < 3

          if [%w[Spieltag Termin Heim Erg. Gast
               Punkte], %w[Spieltag Termin Heim Erg. Gast Punkte Gastgeber]].include?(header)
            shift = tr.css("td")[0].text.to_i.zero? ? 1 : 0
            if shift == 1
              td_ = tr.css("td")[0]
              if (remark_a = td_.css("a")).present?
                remarks = remark_a[0]["title"].gsub("Memo: ", "")
              end
            end
            next if tr.css("td").count < 8

            day_seqno = tr.css("td")[0 + shift].text.to_i
            date = begin
                     DateTime.parse(tr.css("td")[1 + shift].inner_html.gsub("<br>", " ").gsub(" Uhr", ""))
                   rescue StandardError
                     nil
                   end
            league_team_a_name = tr.css("td")[2 + shift].text.strip
            league_team_a = league_teams_cache.find { |lt| lt.name == league_team_a_name }
            league_team_b_name = tr.css("td")[6 + shift].text.strip
            league_team_b = league_teams_cache.find { |lt| lt.name == league_team_b_name }
            next if league_team_a.nil? || league_team_b.nil?
            result_a = tr.css("td")[4 + shift].css("a")[0]
            result_text = tr.css("td")[4 + shift].text.strip
            points = tr.css("td")[7 + shift].text.strip
          elsif ["ST", "TERMIN", "HEIM", "", "GAST"] == header || ["ST", "TERMIN", "HEIM", "", "GAST", "GASTGEBER"] == header
            if shift == 1
              td_ = tr.css("td")[0]
              if (remark_a = td_.css("a")).present?
                remarks = remark_a[0]["title"].gsub("Memo: ", "")
              end
            end
            day_seqno = tr.css("td")[shift+0].text.to_i
            date = begin
                     DateTime.parse(tr.css("td")[shift+1].inner_html.gsub("<br>", " ").gsub(" Uhr", ""))
                   rescue StandardError
                     nil
                   end
            league_team_a_name = tr.css("td")[shift+2].text.strip
            league_team_a = league_teams_cache.find { |lt| lt.name == league_team_a_name }
            league_team_b_name = tr.css("td")[shift+6].text.strip
            league_team_b = league_teams_cache.find { |lt| lt.name == league_team_b_name }
            next if league_team_a.nil? || league_team_b.nil?
            result_a = tr.css("td")[shift+4].css("a")[0]
            result_text = tr.css("td")[shift+4].text.strip
            points = tr.css("td")[shift+8].andand.text.andand.strip
          else
            Rails.logger.info "Error - ScrapeError problem with header #{header}"
            next
          end
          party_url = league_url
          # scrape game result details
          if result_a.present?
            result = result_a.text
            remarks = nil
            club = nil
            game_report_link = result_a.andand["href"]
            params = game_report_link.split("p=")[1].split(/[-|]/)
            party_cc_id = params[5].to_i # 10--2022/2023-46-0-4181
            party_cc_id ||= last_cc_id + 1
            # Find party by teams/date, regardless of cc_id
            party = parties.where(
              day_seqno: day_seqno,
              league_team_a: league_team_a,
              league_team_b: league_team_b
            ).first
            # If a result/cc_id is now available, update the party
            if party && party.cc_id.nil? && party_cc_id.present?
              party.assign_attributes(cc_id: party_cc_id, data: { result: result, points: points }.compact)
              party.save if party.changed?
            elsif party.nil?
              party = parties.new(
                day_seqno: day_seqno,
                league_team_a: league_team_a,
                league_team_b: league_team_b,
                cc_id: party_cc_id,
                data: { result: result, points: points }.compact
              )
              party.save
            end
            last_cc_id = party_cc_id
            game_report_url = url + game_report_link
            Rails.logger.info "reading #{game_report_url}"
            uri = URI(game_report_url)
            game_report_html = Net::HTTP.get(uri)
            party_url = game_report_url
            game_report_doc = Nokogiri::HTML(game_report_html)
            game_report_table = game_report_doc.css("aside > section > table")[2]
            td_ = game_report_table.css("tr > td").find { |td| td.text =~ /Gastgeber:/ }
            if td_.present?
              club_name = td_.css("strong")[0].text.strip.gsub("1.", "1. ").gsub("1.  ", "1. ").gsub(/\s\s+/, " ")
              club = clubs_cache.find { |c| c.synonyms.split("\n").include?(club_name) }
              club ||= Club.where("synonyms ilike '%#{club_name}%'").first
              if club.blank?
                Rails.logger.info "Format Error 0 Party[#{party&.id}]"
                next
              end
              location_a = td_.css("a")[0]
              location_link = location_a["href"]
              location_text = td_.text
              _t, _club_name, location_name, location_street, location_town, location_tel =
                location_text.match(/Gastgeber: (.*) Location:\s*(.*) - (.*) in ([^(]*)(\(.*\))/).to_a.map(&:strip)
              if location_name.present?
                location_params = location_link.split("p=")[1].split(/[-|]/)
                location_dbu_nr = location_params[1].to_i
                location = Location.where("address ilike ?", "#{location_street}%").first
                unless location.present?
                  location = Location.new(
                    name: location_name,
                    address: "#{location_street}, #{location_town}#{" #{location_tel}".presence}",
                    organizer: club
                  )
                end
                location.dbu_nr = location_dbu_nr if url =~ /billard-union.net/
                location.source_url ||= url + location_link unless url =~ /billard-union.net/
                if location.changed?
                  location.region_id = region.id
                  location.save
                end
                club_location = ClubLocation.where(club: club, location: location).first
                unless club_location.present?
                  (cl = ClubLocation.new(club: club, location: location); cl.region_id = region.id; cl.save)
                end
              end
            end
            if party.blank? || party.party_games.blank? || !opts[:optimize_api_access]
              party ||= parties.new(
                cc_id: party_cc_id,
                day_seqno: day_seqno,
                league_team_a: league_team_a,
                league_team_b: league_team_b
              )
              party_attrs = {
                day_seqno: day_seqno,
                date: date,
                remarks: { remarks: remarks.to_s },
                cc_id: party_cc_id,
                data: { result: result, points: points }.compact,
                league_team_a: league_team_a,
                league_team_b: league_team_b,
                source_url: party_url,
                host_league_team: league_teams_cache.find { |lt| lt.club_id == club.andand.id } || league_team_a,
                location: league_team_a.andand.club.andand.location
              }.compact
              party.assign_attributes(party_attrs)
              if party.changed?
                party.region_id = region.id
                party.save
              end
              party_count += 1
              if opts[:only_first_n_parties].present? && party_count > opts[:only_first_n_parties].to_i
                break
              end

              Party.where({
                            day_seqno: day_seqno,
                            league_team_a: league_team_a,
                            league_team_b: league_team_b,
                            cc_id: nil,
                            league: self
                          }).destroy_all

              # read Game Report
              game_detail_table = game_report_doc.css("aside > section > table")[3]
              if /MGD \(Heim\)/.match?(game_detail_table.text)
                game_detail_table = game_report_doc.css("aside > section > table")[4]
              end
              structure = ""
              seqno = nil
              party_games = {}
              players_a = []
              players_b = []
              row_index = -1
              game_seqno = 0
              # scrape party game details
              games_per_round = 0
              tables = game_plan[:tables].presence || 0
              game_detail_table.css("tr").each do |tr_g|
                if tr_g.css("th").count.positive?
                  if tr_g.css("th").count == 1 && tr_g.css("th").text.strip == "SPIELBERICHT"
                    structure = ""
                  else
                    header_g = tr_g.css("th").map(&:text)
                    if header_g == %w[Spieltag Termin Heim Erg. Gast Punkte]
                      header_g
                    elsif header_g == ["Partie-Nr.", "Heim-Mannschaft", "", "Gast-Mannschaft", "Datum"]
                      structure = "party"
                    elsif header_g & ["", "Brett", "Heim-Spieler", "Erg.", "Gast-Spieler",
                                      "Punkte"] == ["", "Brett", "Heim-Spieler", "Erg.", "Gast-Spieler", "Punkte"] ||
                      header_g & ["", "Paarung", "Heim-Spieler", "Erg.", "Gast-Spieler",
                                  "Punkte"] == ["", "Paarung", "Heim-Spieler", "Erg.", "Gast-Spieler", "Punkte"]
                      game_plan[:bez_brett] = header_g[header_g.index("Paarung") || header_g.index("Brett")]
                      raise StandardError "Format Error 1 Party[#{party.id}]" unless (m = header_g[1].match(/Runde (\d+)/))

                      structure = "runde+brett"
                      r_no = m[1].to_i

                      seqno = nil
                      row_index += 1
                      game_plan[:rows][row_index] = { type: "Neue Runde", r_no: r_no }
                      tables = [tables, games_per_round].max
                      games_per_round = 0

                    elsif header_g & ["", "Heim-Spieler", "Erg.", "Gast-Spieler",
                                      "Punkte"] == ["", "Heim-Spieler", "Erg.", "Gast-Spieler", "Punkte"]
                      raise StandardError "Format Error 2 Party[#{party.id}]" unless (m = header_g[1].match(/Runde (\d+)/))

                      structure = "runde"
                      r_no = m[1].to_i
                      seqno = nil
                      row_index += 1
                      game_plan[:rows][row_index] = { type: "Neue Runde", r_no: r_no }
                      tables = [tables, games_per_round].max
                      games_per_round = 0

                    else
                      raise StandardError "Format Error 3 Party[#{party.id}]"
                    end
                  end
                elsif tr_g.text.match(/(MGD \(Heim\)|MGD \(Gast\)|BED)/).present?
                  case tr_g.text
                  when /MGD \(Heim\)/
                    # TODO: MDG
                  when /MGD \(Gast\)/
                    # TODO: MDG
                  when /BED/
                    # TODO: BED
                  else
                    raise StandardError, "Format Error Party[#{party.id}]"
                  end
                elsif tr_g.text.strip.blank?
                  # ignore
                elsif structure == "party"
                  party_attrs.merge!(
                    party_no: tr_g.css("td")[0].text.strip.to_i,
                    reported_at: (
                      DateTime.parse(tr_g.css("td")[8].text.strip) unless /Termin folgt/.match?(tr_g.css("td")[8].text))
                  )
                elsif %w[runde runde+brett].include?(structure)

                  if structure == "runde" && tr_g.css("td")[2]&.text&.match(/\d-\d/)
                    structure = "runde+brett"
                  end
                  shift2 = structure == "runde+brett" ? 1 : 0
                  seqno = tr_g.css("td")[0].text.strip.to_i if tr_g.css("td")[0].text.strip.present?
                  if tr_g.css("td")[0].text.strip.blank? && tr_g.css("td")[1].text.strip.present?
                    if /Bälle:|Punkte:/.match?(tr_g.text)
                      result_detail = tr_g.text.strip.split(/\u00A0+/).map { |s| s.split(/\s+/) }.to_h
                      party_games[seqno][:data][:result].merge!(result_detail).compact!
                      game_plan[:rang_mgd] = true
                      dis_name = game_plan[:rows][row_index][:type]
                      max_balls = (result_detail["Bälle:"] || result_detail["Punkte:"]).split(/\s*:\s*/).map(&:to_i).max
                      disciplines[dis_name][:score] = max_balls if disciplines[dis_name][:score].to_i < max_balls
                      if result_detail["Aufn.:"].present?
                        innings = result_detail["Aufn.:"].split(/\s*:\s*/).map(&:to_i).first
                        if disciplines[dis_name][:inning].to_i < innings
                          disciplines[dis_name][:inning] = innings
                          disciplines[dis_name][:inning_occurence] = 1
                        elsif disciplines[dis_name][:inning].to_i == innings
                          disciplines[dis_name][:inning_occurence] += 1
                        end
                      end
                    end
                  elsif tr_g.css("td")[0].text.strip.blank? && tr_g.css("td")[1].text.strip.blank?
                    if /Frame \d+:/.match?(tr_g.text)
                      res = tr_g.text.strip.split(":").map(&:strip)
                      party_games[seqno].merge!(
                        res[0] => res[1]
                      )
                    elsif /Bälle:|Punkte:/.match?(tr_g.text)
                      map_ = tr_g.text.strip.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
                                 .split(/\u00A0+/u) # Split on any positive number of NBSP
                                 .reject { |s| s =~ /\(x\d+\)/u }
                                 .map { |s| s.split(/\s+/u) }
                      Rails.logger.info "map is '#{map_.inspect}'"
                      result_detail = map_.to_h
                      party_games[seqno][:data][:result].merge!(result_detail).compact!
                      game_plan[:rang_mgd] = true
                      dis_name = game_plan[:rows][row_index][:type]
                      max_balls = (result_detail["Bälle:"].presence || result_detail["Punkte:"].presence).split(/\s*:\s*/).map(&:to_i).max
                      disciplines[dis_name][:score] = max_balls if disciplines[dis_name][:score].to_i < max_balls
                      innings = result_detail["Aufn.:"].to_s.split(/\s*:\s*/).map(&:to_i).first.to_i
                      if innings.positive?
                        if disciplines[dis_name][:inning].to_i < innings
                          disciplines[dis_name][:inning] = innings
                          disciplines[dis_name][:inning_occurence] = 1
                        elsif disciplines[dis_name][:inning].to_i == innings
                          disciplines[dis_name][:inning_occurence] += 1
                        end
                      end
                    else
                      player_a_fl_name = tr_g.css("td")[2].andand.text.andand.strip
                      player_b_fl_name = tr_g.css("td")[3].andand.text.andand.strip
                      player_a = league_team_players[league_team_a.name][player_a_fl_name]
                      if player_a.blank?
                        player_a = Player.joins(:season_participations).where(season_participations: {
                          club_id: league_team_a.club_id, season_id: season_id
                        }).where(fl_name: player_a_fl_name).first
                        league_team_players[league_team_a.name][player_a_fl_name] = player_a
                      end
                      player_b = league_team_players[league_team_b.name][player_b_fl_name]
                      if player_b.blank?
                        player_b = Player.joins(:season_participations).where(season_participations: {
                          club_id: league_team_b.club_id, season_id: season_id
                        }).where(fl_name: player_b_fl_name).first
                        league_team_players[league_team_b.name][player_b_fl_name] = player_b
                      end
                      players_a << player_a
                      players_b << player_b
                      party_games[seqno].merge!(
                        player_a_id: players_a.compact,
                        player_b_id: players_b.compact
                      )
                    end
                  elsif tr_g.css("td")[0].text.strip == "Endstand:"
                    row_index += 1
                    game_plan[:rows][row_index] = { type: "Gesamtsumme" }
                  else
                    players_a = []
                    players_b = []
                    discipline_name = tr_g.css("td")[1].text.strip
                    discipline = Discipline.where("synonyms ilike ?", "%#{discipline_name}%").to_a.find do |dis|
                      dis.synonyms.split("\n").include?(discipline_name)
                    end
                    raise StandardError, "ERROR discipline #{discipline_name} unknown Party[#{party&.id}]" if discipline.blank?

                    disciplines[discipline_name] ||= {}
                    addx = /:/.match?(tr_g.css("td")[5].text.strip) ? 1 : 0
                    point_relult = tr_g.css("td")[4 + addx].text.strip.split(/\s*:\s*/).map(&:to_i)
                    max_game_points = point_relult.max
                    min_game_points = point_relult.min
                    draw_game_points = point_relult[0] == point_relult[1] ? point_relult[0] : 0
                    row_index += 1
                    game_seqno += 1
                    home_brett = visitor_brett = nil
                    if /-/.match?(tr_g.css("td")[2].text.strip)
                      home_brett, visitor_brett = tr_g.css("td")[2].text.strip.split(/\s*-\s*/).map(&:to_i)
                    end
                    game_plan[:rows][row_index] = {
                      type: discipline_name,
                      seqno: game_seqno,
                      home_brett: home_brett,
                      game_points: {
                        win: max_game_points,
                        draw: draw_game_points,
                        lost: min_game_points
                      },
                      visitor_brett: visitor_brett,
                      player_a: "TBD",
                      player_b: "TBD"
                    }
                    games_per_round += 1
                    if /shootout/i.match?(discipline_name)
                      game_plan[:victory_to_nil] = [game_plan[:victory_to_nil].to_i, non_shootout_games].max
                      non_shootout_games = 0
                    else
                      non_shootout_games += 1
                    end

                    player_a_fl_name = tr_g.css("td")[2 + shift2].text.strip
                    player_b_fl_name = tr_g.css("td")[4 + shift2].text.strip
                    result = tr_g.css("td")[3 + shift2].text.strip
                    result = "0:0" if result == ":"

                    if result.present?
                      sets = result.split(/\s*:\s*/).map(&:to_i).max
                      dis_name = game_plan[:rows][row_index][:type]
                      if disciplines[dis_name][:sets].blank? && disciplines[dis_name][:sets_no].blank? && disciplines[dis_name][:sets].to_i < sets
                        disciplines[dis_name][:sets] = sets
                        disciplines[dis_name][:sets_occurence] = 1
                      elsif disciplines[dis_name][:sets].present? && disciplines[dis_name][:sets].to_i != sets
                        disciplines[dis_name][:sets_no] = party.cc_id
                      elsif disciplines[dis_name][:sets].present? && disciplines[dis_name][:sets].to_i == sets
                        disciplines[dis_name][:sets_occurence] += 1
                      end
                    end

                    points = tr_g.css("td")[5 + shift2].text.strip
                    point_values = points.split(/\s*:\s*/).map(&:to_i)
                    if point_values.present?
                      if point_values[0] == point_values[1] && (point_values[0]).positive?
                        disciplines[discipline_name][:ppu] = point_values[0]
                      elsif point_values.max > 1
                        disciplines[discipline_name][:ppg] =
                          ([disciplines[discipline_name][:ppg].to_i] + point_values).max
                        disciplines[discipline_name][:ppv] =
                          ([disciplines[discipline_name][:ppv].to_i] + point_values).min
                      end
                    end
                    player_a = nil
                    if league_team_a.present?
                      player_a = league_team_players[league_team_a.name].andand[player_a_fl_name]
                      if player_a.blank?
                        player_a = Player.joins(:season_participations).where(season_participations: {
                          club_id: league_team_a.club_id, season_id: season_id
                        }).where(fl_name: player_a_fl_name).first
                        if player_a.present? && league_team_a.present?
                          league_team_players[league_team_a.name][player_a_fl_name] =
                            player_a
                        end
                      end
                    end
                    player_b = nil
                    if league_team_b.present?
                      if league_team_b.present?
                        player_b = league_team_players[league_team_b.name].andand[player_b_fl_name]
                      end
                      if player_b.blank?
                        player_b = Player.joins(:season_participations).where(season_participations: {
                          club_id: league_team_b.club_id, season_id: season_id
                        }).where(fl_name: player_b_fl_name).first
                        if player_b.present? && league_team_b.present?
                          league_team_players[league_team_b.name][player_b_fl_name] =
                            player_b
                        end
                      end
                    end
                    players_a << player_a
                    players_b << player_b
                    players_a.compact!
                    players_b.compact!
                    party_games[seqno] ||= {}
                    party_games[seqno].merge!(
                      seqno: seqno,
                      discipline_id: discipline.id,
                      data: { result: { "Ergebnis:" => result, "Punkte:" => points } },
                      player_a_id: players_a.compact,
                      player_b_id: players_b.compact,
                      name: "Spiel #{seqno}::#{discipline.name}"
                    ).compact!
                  end
                else
                  raise StandardError, "Unexpected Format Error Party[#{party.id}]"
                end
              end
              game_plan[:tables] = tables
              # save party games
              party_games.each do |seqno2, data|
                attrs = {
                  party_id: party.id,
                  discipline_id: data[:discipline_id],
                  seqno: seqno2,
                  player_a_id: Player.team_from_players(data[:player_a_id].compact).andand.id,
                  player_b_id: Player.team_from_players(data[:player_b_id].compact).andand.id,
                  data: data[:data],
                  name: data[:name]
                }
                party_game = PartyGame.where(
                  party_id: party.id,
                  seqno: seqno2
                ).first || PartyGame.new(party_id: party.id, seqno: seqno2)
                party_game.assign_attributes(attrs)
                if party_game.changed?
                  party_game.region_id = region.id
                  party_game.save
                end
              end
              # look for shootout
              res = party.data[:points].andand.split(":")&.map(&:strip)&.map(&:to_i)&.sort
              if res.present?
                game_plan[:match_points][:win] = [game_plan[:match_points][:win].to_i, res[1]].max
                game_plan[:match_points][:lost] = [game_plan[:match_points][:lost].to_i, res[0]].min
                party_games_select = party_games.select { |_k, v| v[:name] =~ /shootout/i }
                if party_games_select.present?
                  data_result = party_games_select.to_a[0][1][:data][:result]["Ergebnis:"]
                  if data_result != "0:0"
                    game_plan[:extra_shootout_match_points] = {
                      win: res[1] - res[0],
                      lost: 0
                    }
                    game_plan[:match_points][:draw] = res.min
                  end
                end
              end
            end
          else
            party_cc_id = last_cc_id + 1
            last_cc_id = party_cc_id
            party_attrs = {
              day_seqno: day_seqno,
              remarks: { remarks: remarks.to_s },
              data: { result: result_text }.compact,
              cc_id: party_cc_id,
              league_team_a_id: league_team_a.andand.id,
              league_team_b_id: league_team_b.andand.id,
              source_url: party_url,
              host_league_team: nil,
              location: location || league_team_a.andand.club.andand.location
            }.compact
            party = Party.where(party_attrs).first
            party ||= Party.new(league_id: id)
            party.assign_attributes(party_attrs.merge(date: date))
            if party.changed?
              party.region_id = region.id
              party.save!
            end
            Party.where(party_attrs.merge(league_id: id, cc_id: nil)).destroy_all
          end
          party
        end
      end

      if game_plan[:rows].present?
        disciplines.each do |k, v|
          v_ = v.dup
          if v_[:inning_occurence].present?
            v_.delete(:inning) if v_[:inning_occurence] < 3
            v_.delete(:inning_occurence)
          end
          if v_[:sets_occurence].present?
            if v_[:sets_occurence] < 3 # || v_[:sets_no] TODO e.g. in Partie 2202 wurden nur 8 Sätze im 9-Ball gespielt!!
              v_.delete(:sets)
            end
            v_.delete(:sets_occurence)
            v_.delete(:sets_no)
          end
          game_plan[:rows] = game_plan[:rows].map do |row|
            row_ = row
            row_ = row_.merge(v_).compact if row_[:type] == k
            row_.sort.to_h
          end
        end
        game_plan = game_plan.sort.to_h
        footprint = Digest::MD5.hexdigest(game_plan.inspect)
        gp_name = "#{name} - #{branch.name} - #{self.organizer.shortname}"
        gp = GamePlan.find_by_name(gp_name) || GamePlan.new(name: gp_name)
        gp.assign_attributes(footprint: footprint, data: game_plan)
        gp.data_will_change! if gp.changes["data"].present? && gp.changes["data"][0] != gp.changes["data"][1]
        if gp.changed?
          gp.region_id = region.id
          gp.save
        end
        self.game_plan = gp
        save!
      end
    end
    return
  rescue StandardError => e
    Rails.logger.info "==== scrape ==== Fatal Error league_url: #{league_url} #{e}, #{e.backtrace&.join("\n")}"
  end

  def cc_id_link
    "#{organizer.public_cc_url_base}sb_spielplan.php?p=#{organizer.region_cc.andand.cc_id}--#{season.name}-#{cc_id}#{
      "-#{cc_id2}" if cc_id2.present?}"
  end

  def source
    season.id > 13 ? "ClubCloud" : "BillardArea"
  end

  @@scraping = []

  def self.scraping
    @@scraping
  end

  def self.set_scraping(ix, val)
    return unless val && @@scraping[ix].blank?

    Rails.logger.info "========== start scraping #{ix}"
    @@scraping[ix] ||= val
  end

  def fix_seqnos
    seqno = 0
    date = nil
    parties.order(:date, :id).each do |party|
      if party.date != date
        seqno += 1
        date = party.date
      end
      party.update(day_seqno: seqno)
    end
  end

  def self.logger
    DEBUG_LOGGER
  end

  # Gibt die Tabelle für Karambol-Ligen zurück
  def standings_table_karambol
    teams = league_teams.to_a
    stats = teams.map do |team|
      parties_home = parties.where(league_team_a: team)
      parties_away = parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      partien_gewonnen = 0
      partien_verloren = 0
      partien_str = "0:0"

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        left, right = result.split(":").map(&:to_i)
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        partien_gewonnen += team_for
        partien_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      partien_str = "#{partien_gewonnen}:#{partien_verloren}"
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        partien: partien_str
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  end

  # Gibt die Tabelle für Snooker-Ligen zurück
  def standings_table_snooker
    teams = league_teams.to_a
    stats = teams.map do |team|
      parties_home = parties.where(league_team_a: team)
      parties_away = parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      frames_gewonnen = 0
      frames_verloren = 0
      frames_str = "0:0"

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        left, right = result.split(":").map(&:to_i)
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        frames_gewonnen += team_for
        frames_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      frames_str = "#{frames_gewonnen}:#{frames_verloren}"
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        frames: frames_str
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  end

  # Gibt die Tabelle für Pool-Ligen zurück
  def standings_table_pool
    teams = league_teams.to_a
    stats = teams.map do |team|
      parties_home = parties.where(league_team_a: team)
      parties_away = parties.where(league_team_b: team)
      parties_all = parties_home + parties_away
      spiele = parties_all.size
      gewonnen = 0
      unentschieden = 0
      verloren = 0
      punkte = 0
      diff = 0
      partien_gewonnen = 0
      partien_verloren = 0
      partien_str = "0:0"

      parties_all.each do |party|
        # Annahme: Ergebnis steht in party.data[:result] oder party.data["result"] als "x:y"
        result = party.data["result"] || party.data[:result]
        next unless result.present? && result.include?(":")
        left, right = result.split(":").map(&:to_i)
        if party.league_team_a_id == team.id
          team_for = left
          team_against = right
        else
          team_for = right
          team_against = left
        end
        diff += team_for - team_against
        partien_gewonnen += team_for
        partien_verloren += team_against
        if team_for > team_against
          gewonnen += 1
          punkte += 2
        elsif team_for == team_against
          unentschieden += 1
          punkte += 1
        else
          verloren += 1
        end
      end
      partien_str = "#{partien_gewonnen}:#{partien_verloren}"
      {
        team: team,
        name: team.name,
        spiele: spiele,
        gewonnen: gewonnen,
        unentschieden: unentschieden,
        verloren: verloren,
        punkte: punkte,
        diff: diff,
        partien: partien_str
      }
    end
    # Sortierung: Punkte DESC, dann Diff DESC
    stats.sort_by.with_index { |row, idx| [-row[:punkte], -row[:diff], idx] }.each_with_index.map do |row, ix|
      row.merge(platz: ix + 1)
    end
  end

  # Gibt den Spielplan gruppiert nach Hin- und Rückrunde zurück
  def schedule_by_rounds
    all_parties = parties.order(:day_seqno, :date).to_a
    max_seqno = all_parties.map(&:day_seqno).max || 0
    half = (max_seqno / 2.0).ceil
    {
      "Hinrunde" => all_parties.select { |p| p.day_seqno && p.day_seqno <= half },
      "Rückrunde" => all_parties.select { |p| p.day_seqno && p.day_seqno > half }
    }
  end

  private

  def self.scrape_bbv_leagues(region, season, opts = {})
    url = "https://bbv-billard.liga.nu"
    %w[Pool Snooker Karambol].each do |branch_str|
      branch = Branch.find_by_name(branch_str)
      leagues_url = "https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/leaguePage?championship=BBV%20#{branch_str}%#{season.name.gsub("/20", "/")}"
      Rails.logger.info "reading #{leagues_url}"
      uri = URI(leagues_url)
      leagues_html = Net::HTTP.get(uri)
      leagues_html = leagues_html.force_encoding('ISO-8859-1').encode('UTF-8')
      leagues_doc = Nokogiri::HTML(leagues_html)
      league_table = leagues_doc.css("table")[0]
      cols = league_table.css("td")
      cols.each do |td|
        header = td.css("h2")[0].text
        td.css("a").each do |league_a|
          league_url = url + league_a.attributes["href"]
          league_shortname = league_a.text.strip
          league_doc, league_uri = get_league_doc(league_url)
          league_data = league_doc.css("h1")[0].inner_html.split('<br>').map(&:strip)
          name_arr = league_data[1].split(/\s+/)
          league_name = name_arr[0]
          staffel_text = name_arr[1..].join(" ")
          attrs = { organizer: region, staffel_text: staffel_text, name: league_name, season: season,
          }.compact
          league = League.where(attrs).first || League.new(attrs)

          attrs = { shortname: league_shortname, discipline: branch }.compact
          league.assign_attributes(attrs)
          league.source_url = league_uri
          if league.changed?
            records_to_tag |= Array(league)
            league.save
          end
          records_to_tag |= Array(league.scrape_single_league_from_cc(opts.merge(league_doc: league_doc))) if opts[:league_details]
        end
      end
    end
    return records_to_tag
  end

  def scrape_single_bbv_league(region, opts = {})
    url = "https://bbv-billard.liga.nu"
    records_to_tag = []
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    season = self.season
    league_url = self.source_url
    league_doc = opts[:league_doc]
    league_doc, league_uri = get_league_doc(league_url) unless league_doc.present?
    # scrape league teams with results
    records_to_tag |= Array(scrape_bbv_league_teams(league_doc, league_url, url))
    parties_table_url = url + league_doc.css("#sub-navigation a").select { |a| a.text =~ /Spielplan \(Gesamt\)/ }[0].attributes["href"].value
    parties_table_url

    [league_url, records_to_tag]
  end

  # scrape bbv league teams with results
  def scrape_bbv_league_teams(league_doc, league_url, url)
    team_table_url = league_url
    records_to_tag = []
    team_table_doc = league_doc
    html = team_table_doc.css("table")[0]
    headers = html.css("th").map(&:text)
    html.css("tr").each do |tr|
      next if tr.css("td").count == 0
      args = tr.css("td").map(&:inner_html)
      rang = args[1].to_i
      if tr.css("td")[2].css("a")[0].present?
        team_url = url + tr.css("td")[2].css("a")[0].andand.attributes.andand["href"]
        Rails.logger.info "reading #{team_url}"
        team_uri = URI(team_url)
        team_html = Net::HTTP.get(team_uri).gsub("//--", "--").
          gsub('id="banner-groupPage-content"', "").
          gsub(/<meta name="uLigaStatsRefUrl"\s*\/>/, "").
          gsub('</meta>', '')
        team_doc = Nokogiri::HTML.fragment(team_html)
        club_url = url + team_doc.css("#content-row1 a:nth-child(1)")[0].attributes["href"]
        club_cc_id = club_url.match(/club=(\d+)/)[1].to_i
        club = Club.where(region: organizer, cc_id: club_cc_id).first
        team_name = tr.css("td")[2].css("a")[0].text.strip
        team_cc_id = team_url.match(/teamtable=(\d+)/)[1]
      else
        team_name = tr.css("td")[2].text.strip
        club = Club.where(region: organizer).where("clubs.name ilike '%#{team_name.gsub(/ [IV]+$/, '')}%'").first
        Rails.logger.info "===== scrape ===== scrape leagues - cannot match club from Teamname #{team_name}, league: #{self.name} #{self.staffel_text}"
      end
      parties = args[3].to_i
      wins = args[4].to_i
      draws = args[5].to_i
      losts = args[6].to_i
      result = args[7].strip
      diff = args[8].strip
      points = args[9].strip
      data = {
        parties: parties,
        wins: wins,
        draws: draws,
        losts: losts,
        result: result,
        diff: diff,
        points: points
      }
      league_team = league_teams.where(cc_id: team_cc_id).first
      league_team ||= league_teams.new(cc_id: team_cc_id)
      attrs = {
        name: team_name,
        club_id: club&.id,
        data: data
      }
      league_team.assign_attributes(attrs)
      league_team.source_url = league_url
      if league_team.changed?
        records_to_tag |= Array(league_team)
        league_team.save
      end
    end
    return records_to_tag
  end

  def self.get_league_doc(league_url)
    Rails.logger.info "reading #{league_url}"
    league_uri = URI(league_url)
    # fix some unused faulty code
    league_html = Net::HTTP.get(league_uri).gsub("//--", "--").
      gsub('id="banner-groupPage-content"', "").
      gsub('<meta name="uLigaStatsRefUrl"/>', "").
      gsub('</meta>', '')
    # league_html = league_html.force_encoding('ISO-8859-1').encode('UTF-8')
    league_doc = Nokogiri::HTML.fragment(league_html)
    return league_doc, league_uri
  end
end
