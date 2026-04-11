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
    scope: [:cc_id2, :organizer_id, :organizer_type, :season_id],
    message: "must be unique within the same organizer (cc_id + cc_id2 - season_id combination)"
   }, if: -> { cc_id.present? && organizer_type == 'Region' }

  # Secondary uniqueness: Ensure no duplicate leagues with same name and staffel
  # This is mainly for cases where cc_id might not be set yet
  validates :name, uniqueness: {
    scope: [:season_id, :organizer_id, :organizer_type, :staffel_text],
    message: "must be unique within the same region, season, and staffel"
  }, if: -> { organizer_type == 'Region' && cc_id.blank? }

  DBU_ID = Region.find_by_shortname("DBU")&.id.freeze

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
              Rails.logger.info "League[#{league.attributes.inspect}]"
              league.save!
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

  def self.scrape_leagues_optimized(region, season, opts = {})
    Rails.logger.info "===== scrape ===== Starting optimized league scraping for region #{region.shortname}"

    if region.shortname == "BBV"
      # BBV uses a different scraping method, use the original for now
      scrape_leagues_from_cc(region, season, opts)
    else
      url = region.public_cc_url_base
      leagues_url = "#{url}sb_spielplan.php?eps=100000&s=#{season.name}"
      Rails.logger.info "reading #{leagues_url} - region #{region.shortname} league tournaments season #{season.name}"
      uri = URI(leagues_url)
      leagues_html = Net::HTTP.get(uri)
      leagues_doc = Nokogiri::HTML(leagues_html)
      table = leagues_doc.css("article table.silver")[1]

      if table.present?
        processed_leagues = 0
        skipped_leagues = 0

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

          # Check if we need to scrape this league
          league = League.find_by(cc_id: league_cc_id, organizer: region, season: season)

          if league.present?
            last_sync = league.sync_date || 1.year.ago
            force_sync = opts[:force] || last_sync < 1.day.ago
            has_unreported_party_games = league.parties.joins(:party_games).where(party_games: { result: nil }).exists?

            if force_sync || has_unreported_party_games
              Rails.logger.info "===== scrape ===== Syncing league #{league.name} (last sync: #{last_sync}, unreported party games: #{has_unreported_party_games})"
              league.scrape_league_optimized(opts)
              processed_leagues += 1
            else
              Rails.logger.info "===== scrape ===== Skipping league #{league.name} - last sync: #{last_sync}, no unreported party games"
              skipped_leagues += 1
            end
          else
            # New league, need to scrape it fully
            Rails.logger.info "===== scrape ===== New league #{title}, scraping fully"
            scrape_league_details(region, season, title, short, n_staffel, staffel_link, league_cc_id, opts)
            processed_leagues += 1
          end
        end

        Rails.logger.info "===== scrape ===== Region #{region.shortname}: Processed #{processed_leagues} leagues, skipped #{skipped_leagues} leagues"
      end
    end
  rescue StandardError => e
    Rails.logger.info "====== problem with leagues in region #{region.name} - leagues_url: #{leagues_url} e93 \
#{e} #{e.backtrace&.to_a&.join("/n")}"
    raise StandardError, "====== problem with leagues in region #{region.name} - leagues_url: #{leagues_url} e93 \
#{e} #{e.backtrace&.to_a&.join("/n")}"
  end

  def self.scrape_league_details(region, season, title, short, n_staffel, staffel_link, league_cc_id, opts)
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
      end
      if trx.css("td")[0].text == "Quelle"
        skip = true
        break
      end
    end
    return if skip

    cc_id2s = []
    staffel_texts = []
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

  def scrape_league_optimized(opts = {})
    # Check if we need to sync league teams (only if no party games have been reported)
    # result is stored in party_games.data JSON, not a separate column
    has_reported_party_games = parties.joins(:party_games).where("party_games.data IS NOT NULL AND party_games.data NOT IN ('null', '{}', '')").exists?

    if !has_reported_party_games
      Rails.logger.info "===== scrape ===== Syncing league teams for league #{name} (no reported party games)"
      scrape_league_teams_optimized(opts)
    else
      Rails.logger.info "===== scrape ===== Skipping league teams for league #{name} (has reported party games)"
    end

    # Always check for new party games
    scrape_party_games_optimized(opts)
  end

  def scrape_league_teams_optimized(opts = {})
    # Only sync league teams if no party games have been reported
    # result is stored in party_games.data JSON, not a separate column
    return if parties.joins(:party_games).where("party_games.data IS NOT NULL AND party_games.data NOT IN ('null', '{}', '')").exists?

    Rails.logger.info "===== scrape ===== Syncing league teams for league #{name}"
    # This would call the existing league team scraping logic
    # For now, we'll use the existing method
    scrape_single_league_from_cc(opts.merge(league_details: true))
  end

  def scrape_party_games_optimized(opts = {})
    Rails.logger.info "===== scrape ===== Checking for new party games in league #{name}"
    # This would call the existing party game scraping logic
    # For now, we'll use the existing method
    scrape_single_league_from_cc(opts.merge(league_details: true))
  end

  # scrape_single_league_from_cc
  def scrape_single_league_from_cc(opts = {})
    League::ClubCloudScraper.call(league: self, **opts)
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
    League::StandingsCalculator.new(self).karambol
  end

  # Gibt die Tabelle für Snooker-Ligen zurück
  def standings_table_snooker
    League::StandingsCalculator.new(self).snooker
  end

  # Gibt die Tabelle für Pool-Ligen zurück
  def standings_table_pool
    League::StandingsCalculator.new(self).pool
  end

  # Gibt den Spielplan gruppiert nach Hin- und Rückrunde zurück
  def schedule_by_rounds
    League::StandingsCalculator.new(self).schedule_by_rounds
  end

  def reconstruct_game_plan_from_existing_data
    League::GamePlanReconstructor.call(league: self, operation: :reconstruct)
  end

  private

  # Thin private delegation for characterization tests that call this via .send
  def analyze_game_plan_structure(party, game_plan, disciplines)
    League::GamePlanReconstructor.new(league: self).send(:analyze_game_plan_structure, party, game_plan, disciplines)
  end

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

  def self.reconstruct_game_plans_for_season(season, opts = {})
    League::GamePlanReconstructor.call(season: season, operation: :reconstruct_for_season, **opts)
  end

  def self.delete_game_plans_for_season(season, opts = {})
    League::GamePlanReconstructor.call(season: season, operation: :delete_for_season, **opts)
  end
end
