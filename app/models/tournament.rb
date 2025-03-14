# frozen_string_literal: true

require "net/http"
# require 'dnssd'

# == Schema Information
#
# Table name: tournaments
#
#  id                             :bigint           not null, primary key
#  accredation_end                :datetime
#  admin_controlled               :boolean          default(FALSE), not null
#  age_restriction                :string
#  allow_follow_up                :boolean          default(TRUE), not null
#  ba_state                       :string
#  balls_goal                     :integer
#  color_remains_with_set         :boolean          default(TRUE), not null
#  continuous_placements          :boolean          default(FALSE), not null
#  data                           :text
#  date                           :datetime
#  end_date                       :datetime
#  fixed_display_left             :string
#  gd_has_prio                    :boolean          default(FALSE), not null
#  handicap_tournier              :boolean
#  innings_goal                   :integer
#  kickoff_switches_with          :string
#  location_text                  :text
#  manual_assignment              :boolean          default(FALSE)
#  modus                          :string
#  organizer_type                 :string
#  plan_or_show                   :string
#  player_class                   :string
#  sets_to_play                   :integer          default(1), not null
#  sets_to_win                    :integer          default(1), not null
#  shortname                      :string
#  single_or_league               :string
#  source_url                     :string
#  state                          :string
#  sync_date                      :datetime
#  team_size                      :integer          default(1), not null
#  time_out_warm_up_first_min     :integer          default(5)
#  time_out_warm_up_follow_up_min :integer          default(3)
#  timeout                        :integer          default(45)
#  timeouts                       :integer          default(0), not null
#  title                          :string
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
#  ba_id                          :integer
#  discipline_id                  :integer
#  league_id                      :integer
#  location_id                    :integer
#  organizer_id                   :integer
#  region_id                      :integer
#  season_id                      :integer
#  tournament_plan_id             :integer
#
# Indexes
#
#  index_tournaments_on_ba_id  (ba_id) UNIQUE
#
class Tournament < ApplicationRecord
  include LocalProtector
  include SourceHandler
  DEBUG_LOGGER = Logger.new("#{Rails.root}/log/debug.log")

  include AASM

  before_save :set_paper_trail_whodunnit
  MIN_ID = 50_000_000

  belongs_to :discipline, optional: true
  belongs_to :region, optional: true
  belongs_to :season
  belongs_to :tournament_plan, optional: true
  belongs_to :league, optional: true
  has_many :seedings, -> { order(position: :asc) }, as: :tournament, class_name: "Seeding", dependent: :destroy
  has_many :games, as: :tournament, class_name: "Game", dependent: :destroy
  has_many :teams, dependent: :destroy
  has_one :tournament_monitor
  has_one :tournament_cc, class_name: "TournamentCc", foreign_key: :tournament_id, dependent: :destroy
  has_one :setting
  # noinspection RailsParamDefResolve
  belongs_to :organizer, polymorphic: true
  belongs_to :location, optional: true
  has_one :tournament_local, dependent: :nullify

  scope :active_manual_assignment, -> { where(state: "tournament_started").where(manual_assignment: true) }

  #   data:
  #     {:table_ids=>["2", "4"],
  #      :balls_goal=>0,
  #      :innings_goal=>15,
  #      :timeout=>0,
  #      :timeouts=>0,
  #      :time_out_warm_up_first_min=>5,
  #      :time_out_warm_up_follow_up_min=>3},
  #
  serialize :data, coder: JSON, type: Hash

  NAME_DISCIPLINE_MAPPINGS = {
    "9-Ball" => "9-Ball",
    "8-Ball" => "8-Ball",
    "14.1" => "14.1 endlos",
    "47/2" => "Cadre 47/2",
    "71/2" => "Cadre 71/2",
    "35/2" => "Cadre 35/2",
    "52/2" => "Cadre 52/2",
    "Kl.*I.*Freie" => "Freie Partie groß",
    "Freie.*Kl.*I" => "Freie Partie groß",
    "Einband.*Kl.*I" => "Einband groß",
    ".*Kl.*I.*Einband" => "Einband groß",
    "Einband" => "Einband klein",
    "Freie Partie" => "Freie Partie klein"
  }.freeze

  REFLECTIONS = %w[versions
                   discipline
                   region
                   season
                   tournament_plan
                   league
                   seedings
                   games
                   teams
                   party_games
                   tournament_monitor
                   tournament_cc
                   setting
                   organizer
                   location
                   tournament_local
                   parties].freeze

  COLUMN_NAMES = { # TODO: FILTERS
                   "ID" => "tournaments.id",
                   "CC_ID" => "tournaments.cc_id",
                   "Title" => "tournaments.title",
                   "Shortname" => "tournaments.shortname",
                   "Date" => "tournaments.date::date",
                   "Discipline" => "disciplines.name",
                   "Region" => "regions.shortname",
                   "Organization" => "regions.shortname",
                   "Season" => "seasons.name",
                   "date" => "tournaments.date::date"
  }.freeze

  def self.search_hash(params)
    {
      model: Tournament,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: Tournament::COLUMN_NAMES,
      raw_sql: "(tournaments.ba_id = :isearch)
or (tournaments.title ilike :search)
or (tournaments.shortname ilike :search)
or (seasons.name ilike :search)",
      joins: [
        'INNER JOIN "regions" ON ("regions"."id" = "tournaments"."organizer_id" AND "tournaments"."organizer_type" = \'Region\')', :season, :discipline
      ]
    }
  end

  validates_each :data do |record, attr, _value|
    table_ids = Array(record.send(attr)[:table_ids])
    if table_ids.present?
      incomplete = table_ids.length != record.tournament_plan.andand.tables.to_i &&
        !record.manual_assignment && record.tournament_plan.andand.tables.to_i < 999
      heterogen = Table.where(id: table_ids).all.map(&:location_id).uniq.length > 1
      inconsistent = table_ids != table_ids.uniq
      record.errors.add(attr, I18n.t("table_assignments_incomplete")) if incomplete
      record.errors.add(attr, I18n.t("table_assignments_heterogen")) if heterogen
      record.errors.add(attr, I18n.t("table_assignments_inconsistent")) if inconsistent
    end
  end

  %i[timeouts timeout gd_has_prio admin_controlled sets_to_play sets_to_win
     team_size kickoff_switches_with allow_follow_up
     fixed_display_left color_remains_with_set].each do |meth|
    define_method(meth) do
      id.present? && id < Tournament::MIN_ID && tournament_local.present? ? tournament_local.send(meth) : read_attribute(meth)
    end

    define_method(:"#{meth}=") do |value|
      if new_record?
        write_attribute(meth, value)
      elsif id < Tournament::MIN_ID
        tol = tournament_local.presence || create_tournament_local(
          timeouts: read_attribute(:timeouts).to_i,
          timeout: read_attribute(:timeout).to_i,
          gd_has_prio: !read_attribute(:gd_has_prio).present?,
          admin_controlled: !read_attribute(:admin_controlled).present?,
          sets_to_play: read_attribute(:sets_to_play) || 1,
          sets_to_win: read_attribute(:sets_to_win).presence || 1,
          team_size: read_attribute(:team_size).presence || 1,
          kickoff_switches_with: read_attribute(:kickoff_switches_with),
          allow_follow_up: !read_attribute(:allow_follow_up).present?,
          fixed_display_left: read_attribute(:fixed_display_left),
          color_remains_with_set: !read_attribute(:color_remains_with_set).present?
        )
        tol.update(meth => value)
      else
        write_attribute(meth, value)
      end
    end
  end

  aasm column: "state", skip_validation_on_save: true do
    state :new_tournament, initial: true, after_enter: [:reset_tournament]
    state :accreditation_finished
    state :tournament_seeding_finished
    state :tournament_mode_defined
    state :tournament_started_waiting_for_monitors
    state :tournament_started
    state :tournament_finished
    state :results_published
    state :closed
    before_all_events :before_all_events
    event :finish_seeding do
      transitions from: %i[new_tournament accreditation_finished tournament_seeding_finished],
                  to: :tournament_seeding_finished
    end
    event :finish_mode_selection do
      transitions from: %i[new_tournament tournament_seeding_finished tournament_mode_defined],
                  to: :tournament_mode_defined
    end
    event :start_tournament! do
      transitions from: %i[tournament_started tournament_mode_defined tournament_started_waiting_for_monitors],
                  to: :tournament_started_waiting_for_monitors
    end
    event :signal_tournament_monitors_ready do
      transitions from: %i[tournament_started tournament_mode_defined tournament_started_waiting_for_monitors],
                  to: :tournament_started
    end
    event :reset_tmt_monitor do
      transitions to: :new_tournament, guard: :tournament_not_yet_started
    end
    event :forced_reset_tournament_monitor do
      transitions to: :new_tournament
    end
    event :finish_tournament do
      transitions to: :tournament_finished
    end

    event :have_results_published do
      transitions from: :tournament_finished, to: :results_published
    end
  end

  before_save do
    self.date = Time.at(0) if date.blank?
    self.organizer = region if organizer.blank?
    %w[balls_goal innings_goal time_out_warm_up_first_min
       time_out_warm_up_follow_up_min kickoff_switches_with fixed_display_left] +
      %w[timeouts timeout gd_has_prio admin_controlled sets_to_play sets_to_win
         team_size kickoff_switches_with allow_follow_up
         fixed_display_left color_remains_with_set].each do |meth|
        if data[meth].present?
          data_will_change!
          write_attribute(meth, data.delete(meth))
        end
      end
  end

  def cc_id
    tournament_cc.andand.cc_id
  end

  def self.logger
    DEBUG_LOGGER
  end

  def initialize_tournament_monitor
    Tournament.logger.info "[initialize_tournament_monitor]..."
    TournamentMonitor.transaction do
      # http = TCPServer.new nil, 80
      # DNSSD.announce http, 'carambus server'
      # Setting.key_set_val(:carambus_server_status, "ready to accept connections from scoreboards")
      games.where("games.id >= #{Game::MIN_ID}").destroy_all
      create_tournament_monitor unless tournament_monitor.present?
      Tournament.logger.info "state:#{state}...[initialize_tournament_monitor]"
    rescue StandardError => e
      Tournament.logger.info "...[initialize_tournament_monitor] StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
      Rails.logger.error("Some problem occurred when creating TournamentMonitor - Tournament resetted")
      reset_tournament
    end
  end

  def t_no_from(table)
    data["table_ids"].to_a.each_with_index do |table_id, ix|
      return ix + 1 if table_id.to_i == table.id
    end
    1
  end

  def player_controlled?
    # players can advance from Game-Finished-OK without admin or referee interaction?
    !admin_controlled?
  end

  def match_location_from_location_text
    lt = location_text
    name, _address, _zipcode, _city, _tel = lt.split('\n')
    Location.find_by_synonyms(name)
  end

  def scrape_single_tournament_public(opts = {})
    nbsp = ["c2a0"].pack("H*").force_encoding("UTF-8")
    return -1 if organizer_type != "Region"
    return if Jumpstart.config.carambus_api_url.present?

    region = organizer
    url = organizer.public_cc_url_base
    region_cc = region.region_cc
    tournament_doc = opts[:tournament_doc]
    region_cc_cc_id = region_cc.cc_id
    tc = tournament_cc
    tournament_cc_id = tc.andand.cc_id
    tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}-#{tournament_cc_id}-0--2-1-100000-"
    unless tournament_doc.present?
      if tournament_cc_id.blank?
        tournament_link_ = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}--0--2-1-100000-"
        Rails.logger.info "reading #{url + tournament_link_}"
        uri = URI(url + tournament_link_)
        tournament_html_ = Net::HTTP.get(uri)
        tournament_doc_ = Nokogiri::HTML(tournament_html_)
        tournament_cc_id = nil
        tournament_doc_.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
          next unless tr.css("a")[0].text.gsub(nbsp, " ").strip == title

          tournament_link_ = tr.css("a")[0].attributes["href"].value
          params = tournament_link_.split("p=")[1].split("-")
          tournament_cc_id = params[3].to_i
          break
        end
        tc = TournamentCc.find_by_cc_id_and_context(tournament_cc_id, region_cc.context)
        tc ||= create_tournament_cc!
        tc.assign_attributes(name: title, season: season.name, context: region_cc.context, cc_id: tournament_cc_id,
                             tournament_id: id)
        tc.save!
        reload
      else
        unless tournament_cc.andand.name == title
          raise StandardError,
                "Fatal mismatch Tournament#title: #{title} and TournamenCc#name: #{tournament_cc.andand.name}"
        end
      end
      tournament_link = "sb_meisterschaft.php?p=#{region_cc_cc_id}--#{season.name}-#{tournament_cc_id}----1-100000-"
      Rails.logger.info "reading #{url + tournament_link}"
      uri = URI(url + tournament_link)
      tournament_html = Net::HTTP.get(uri)
      Rails.logger.info "===== scrape =========================== SCRAPING TOURNAMENT '#{url + tournament_link}'"
      tournament_doc = Nokogiri::HTML(tournament_html)
    end
    self.source_url = url + tournament_link
    # details
    detail_table = tournament_doc.css("aside table.silver")[0]
    branch_cc = nil
    discipline = nil
    detail_table.css("tr").each do |detail_tr|
      next unless detail_tr.css("td")[0].present?

      case detail_tr.css("td")[0].text.gsub(nbsp, " ").strip
      when "Kürzel"
        self.shortname = tc.shortname = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
      when "Datum"
        ht = detail_tr.css("td")[1].inner_html
        date_time = DateTime.parse(ht.match(/.*Spielbeginn am (.*) Uhr.*/)[1].andand.gsub("um ", ""))
        tc.tournament_start = date_time
        self.date = date_time
      when "Location"
        ht = detail_tr.css("td")[1].inner_html
        location = nil
        location_name, location_address = ht.match(%r{<strong>(.*)</strong><br>(.*)})[1..2]
        street = location_address.split("<br>").first.split(",").first.strip
        location = Location.where("address ilike ?", "#{street}%").first if street.present?
        if !location.present? && location_name.present?
          (location = Location.create!(name: location_name, address: location_address, organizer: self))
        end
        self.location = tc.location = location
      when "Meldeschluss"
        text = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        date_time = DateTime.parse(text)
        self.accredation_end = date_time
      when "Sparte"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        branch_cc = BranchCc.where(name:, context: region_cc.context).first
        if branch_cc.present?
          tc.branch_cc_id = branch_cc.id
        else
          Rails.logger.info "===== scrape ===== Problem Branch name #{name} db-unknown - should not happen here!"
        end
      when "Kategorie"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        category_cc = CategoryCc.where(name:, context: region_cc.context).first
        if category_cc.present?
          tc.category_cc_id = category_cc.id
        else
          tc.category_cc_name = name
        end
      when "Meisterschaftstyp"
        name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        championship_type_cc = ChampionshipTypeCc.where(name:, context: region_cc.context).first
        if championship_type_cc.present?
          tc.championship_type_cc_id = championship_type_cc.id
        else
          tc.championship_type_cc_name = name
        end
      when "Disziplin"
        discipline_name = detail_tr.css("td")[1].text.gsub(nbsp, " ").strip
        discipline = Discipline.where("synonyms ilike ?", "%#{discipline_name}%").to_a.find do |dis|
          dis.synonyms.split("\n").include?(discipline_name)
        end
        unless discipline.present?
          discipline = Discipline.create(name: discipline_name, super_discipline_id: branch_cc.andand.id)
        end
        tc.discipline_id = self.discipline_id = discipline.id
      else
        next
      end
    end
    tc.save
    save!
    player_list = {}
    registration_link = tournament_link.gsub("meisterschaft", "meldeliste")
    Rails.logger.info "reading #{url + registration_link}"
    uri = URI(url + registration_link)
    registration_html = Net::HTTP.get(uri)
    registration_doc = Nokogiri::HTML(registration_html)
    registration_table = registration_doc.css("aside table.silver table")[0]
    _header = []
    if registration_table.present?
      registration_table.css("tr")[1..].each_with_index do |tr, ix|
        if tr.css("th").count > 1
          _header = tr.css("th").map(&:text)
        elsif tr.css("td").count.positive?
          _n = tr.css("td")[0].text.to_i
          player_fullname = tr.css("td")[1].text.gsub(nbsp, " ").strip
          player_lname, player_fname = player_fullname.match(/(.*), (.*)/)[1..2]
          club_name = tr.css("td")[3].text.gsub(nbsp, " ").strip.gsub("1.", "1. ").gsub("1.  ", "1. ")
          player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname,
                                                                         season, region,
                                                                         club_name, self,
                                                                         true, true, ix)
          player_list[player.fl_name] = [player, club] if player.present?
        end
      end
    end
    # Meldeliste
    if opts[:reload_game_results]
      reload.seedings.destroy_all
    else
      reload.seedings.where.not(player: player_list.values.map { |v| v[0] }).each(&:destroy)
      # reload.seedings.where.not(player: player_list.values.map { |v| v[0] }).destroy_all
      reload.seedings.where(player: nil).destroy_all
    end
    # Teilnehmerliste
    # player_list = {}
    tournament_doc.css("aside .stanne table.silver table").each do |table|
      next unless table.css("tr th")[0].andand.text.gsub(nbsp, " ").strip == "TEILNEHMERLISTE"

      table.css("tr")[2..].each_with_index do |tr, ix|
        _n = tr.css("td")[0].text.to_i
        player_lname, player_fname, club_name = tr.css("td")[2].inner_html
                                                               .match(%r{<strong>(.*), (.*)</strong><br>(.*)})[1..3]
        club_name = club_name.andand.gsub("1.", "1. ").andand.gsub("1.  ", "1. ")
        player, club, _seeding, _state_ix = Player.fix_from_shortnames(player_lname, player_fname, season, region,
                                                                       club_name.strip, self,
                                                                       true, true, ix)
        player_list[player.fl_name] = [player, club]
      end
    end
    return if discipline&.name == "Biathlon"

    # Ergebnisse
    result_link = tournament_link.gsub("meisterschaft", "einzelergebnisse")
    result_url = url + result_link
    Rails.logger.info "reading #{result_url}"
    uri = URI(result_url)
    result_html = Net::HTTP.get(uri)
    result_doc = Nokogiri::HTML(result_html)
    table = result_doc.css("aside table.silver")[1]
    if table.present?
      group_options = result_doc.css('select[name="groupItemId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      group_option_values = group_options.values
      group_cc = tc.group_cc
      unless group_cc.present?
        GroupCc.where(branch_cc: tc.branch_cc).each do |gcc|
          if JSON.parse(gcc.data)["positions"].andand.values == group_option_values
            group_cc = gcc
            break
          end
        end
      end
      unless group_cc.present?
        group_cc = GroupCc.create!(
          context: region_cc.context,
          name: "Unknown Group - scraped from TournamentCc[#{tc.id}]",
          display: "Gruppen",
          status: "Freigegeben",
          branch_cc_id: tc.branch_cc_id,
          data: { "positions" => group_options }.to_json
        )
        tc.assign_attributes(group_cc: group_cc)
      end
      player_options = result_doc.css('select[name="teilnehmerId"] > option').each_with_object({}) do |o, memo|
        memo[o["value"]] = o.text unless o["value"] == "*"
      end
      player_options.each do |k, v|
        lastname, firstname = v.split(",").map(&:strip)
        firstname.gsub!(/\s*\((.*)\)/, "")
        fl_name = "#{firstname} #{lastname}".strip
        player = player_list[fl_name].andand[0]
        if player.present?
          player.assign_attributes(cc_id: k.to_i) unless organizer.shortname == "DBU"
          player.source_url = result_url unless organizer.shortname == "DBU"
          player.save
        else
          Rails.logger.info("===== scrape ===== Inconsistent Playerlist Player #{[k, v].inspect}")
        end
      end
      games.destroy_all if opts[:reload_game_results]
      group = nil
      frame1_lines = result_lines = td_lines = 0
      result = nil
      no = nil
      playera_fl_name = nil
      playerb_fl_name = nil
      frames = []
      frame_points = []
      innings = []
      hs = []
      hb = []
      mp = []
      header = []
      gd = []
      points = []
      frame_result = []
      table.css("tr").each do |tr|
        frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no,
          player_list, playera_fl_name, playerb_fl_name, points, result, result_lines, result_url,
          td_lines, _tr = parse_table_tr(
          frame1_lines, frame_points, frame_result, frames, gd, group, hb,
          header, hs, mp, innings, nbsp, no, player_list, playera_fl_name, playerb_fl_name,
          points, result, result_lines, result_url, td_lines, tr
        )
      end
      if td_lines.positive? && no.present?
        handle_game(frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
      end
    end

    # Rangliste
    ranking_link = tournament_link.gsub("meisterschaft", "einzelrangliste")
    Rails.logger.info "reading #{url + ranking_link}"
    uri = URI(url + ranking_link)
    ranking_html = Net::HTTP.get(uri)
    ranking_doc = Nokogiri::HTML(ranking_html)
    ranking_table = ranking_doc.css("aside table.silver table")[0]
    header = []
    if ranking_table.present?
      ranking_table.css("tr")[1..].each do |tr|
        if tr.css("th").count > 1
          header = []
          tr.css("th")[0..].each do |th|
            header << th.text
            colspan = th.attributes["colspan"].andand.value.to_i
            next unless colspan > 1

            (2..colspan).each do
              header << ""
            end
          end
        elsif tr.css("td").count.positive?
          rang = g = v = rp = quote = points = innings = gd = bed = hs = hb = mp = player_fl_name = nil
          header.each_with_index do |h, ii|
            case h
            when /\A(rang)\z/i
              rang = tr.css("td")[ii].text.to_i
            when /\A(rp)\z/i
              rp = tr.css("td")[ii].text.to_i
            when /\A(name|teilnehmer)\z/i
              player_fl_name = tr.css("td")[ii].css("a").text.gsub(nbsp, " ").gsub(/\s*\((.*)\)/, "").strip
            when /\A(g|f)\z/i
              g = tr.css("td")[ii].text.to_i
            when /\A(v)\z/i
              v = tr.css("td")[ii].text.to_i
            when /\A(quote)\z/i
              quote = tr.css("td")[ii].text
            when /\A(punkte)\z/i
              points = tr.css("td")[ii].text.to_i
            when /\A(aufn\.)\z/i
              innings = tr.css("td")[ii].text.to_i
            when /\A(hb)\z/i
              hb = tr.css("td")[ii].text
            when /\A(bed)\z/i
              bed = tr.css("td")[ii].text.to_f.round(2)
            when /\A(gd)\z/i
              gd = tr.css("td")[ii].text.to_f.round(2)
            when /\A(hs)\z/i
              hs = tr.css("td")[ii].text
            when /\A(mp)\z/i
              mp = tr.css("td")[ii].text.to_i
            end
          end
          seeding = seedings.where(player: player_list[player_fl_name][0]).first
          if seeding.blank?
            Rails.logger.info("===== scrape ===== seeding of player #{player_fl_name} should exist!")
          else
            seeding.assign_attributes(
              data: {
                "result" =>
                  { "Gesamtrangliste" =>
                      { "Rang" => rang,
                        "RP" => rp,
                        "Name" => player_list[player_fl_name][0].fullname,
                        "Club" => player_list[player_fl_name].andand[1].andand.shortname,
                        "Punkte" => points,
                        "Frames" => frame_points,
                        "Aufn." => innings,
                        "G" => g,
                        "V" => v,
                        "Quote" => quote,
                        "GD" => gd,
                        "BED" => bed,
                        "HS" => hs,
                        "HB" => hb }.compact }
              }
            )
            seeding.save
          end
        end
      rescue StandardError => e
        Rails.logger.info("===== scrape ===== something wrong: #{e} #{e.backtrace}")
      end
    end

    save!
    tc.save!
  rescue StandardError => e
    Tournament.logger.info "===== scrape =====  StandardError #{e}:\n#{e.backtrace.to_a.join("\n")}"
    reset_tournament
  end

  def scrape_single_tournament(opts = {})
    reset_tournament
    logger = opts[:logger] || Logger.new("#{Rails.root}/log/scrape.log")
    game_details = opts.key?(:game_details) ? opts[:game_details] : true
    season = self.season
    region = self.region
    region ||= organizer
    url = "https://#{region.shortname.downcase}.billardarea.de"
    if single_or_league == "single"
      begin
        url_tournament = "/cms_#{single_or_league}/show/#{ba_id}"
        Rails.logger.info "reading #{url + url_tournament} - \"#{title}\" season #{season.name}"
        uri = URI(url + url_tournament)
        res = Net::HTTP.post_form(uri, "data[Season][check]" => "87gdsjk8734tkfdl",
                                  "data[Season][season_id]" => season.ba_id.to_s)
        doc = Nokogiri::HTML(res.body)
        doc.css(".element").each do |element|
          label = element.css("label").text.gsub(nbsp, " ").strip
          value = Array(element.css(".field")).map(&:text).map(&:strip).join("\n")
          mappings = {
            "Meisterschaft" => :title,
            "Datum" => :data, # 13.05.2021	(09:00 Uhr) - 14.05.2021
            "Meldeschluss" => :accredation_end, # 27.10.2020 (23:59 Uhr)
            "Kurzbezeichnung" => :shortname,
            "Disziplin" => :discipline,
            "Spielmodus" => :modus,
            "Altersklasse" => :age_restriction,
            "Spiellokal" => :location_text
          }
          case label
          when "Datum"
            date_begin, time_begin, date_end =
              value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?(?:\s+-\s+(\d+\.\d+\.\d+))?.*/).to_a[1..]
            self.date = DateTime.parse(date_begin + (" #{time_begin}" if time_begin.present?).to_s)
            self.end_date = DateTime.parse(date_end) if date_end.present?
          when "Meldeschluss"
            date_begin, time_begin = value.match(/\s*(\d+\.\d+\.\d+)\s*(?:\((.*) Uhr\))?.*/).to_a[1..]
            self.accredation_end = DateTime.parse(date_begin + (" #{time_begin}" if time_begin.present?).to_s)
          when "Disziplin"
            discipline = Discipline.find_by_name(value)
            discipline = Discipline.create(name: value) if discipline.blank? && value.present?
            self.discipline_id = (discipline || Discipline.find_by_name("-")).andand.id
          else
            update_attribute(mappings[label], value)
          end
        end
      rescue StandardError
        return
      end
      self.data = {}
      save!
      if game_details
        # Setzliste
        # seedings_prev = self.seedings
        self.seedings = []
        table = doc.css("#tabs-3 .matchday_table")[0]
        if table.present?
          states = %w[FG NG ENA UNA DIS]
          state_ix = 0
          seeding = nil
          table.css("td").each_with_index do |td, ix|
            parse_table_td(ix, logger, region, season, seeding, state_ix, states, td)
          end
        else
          table
        end
        #
        # no_show_ups = seedings_prev - self.seedings
        # no_show_ups.each do |seeding|
        #   seeding.status = "UNA"
        # end
        reload
        # Results
        games.where("games.id >= #{Game::MIN_ID}").destroy_all
        reload
        table = doc.css("#tabs-2 .matchday_table")[0]
        keys = table.css("tr th div").map(&:text).map { |s| s.split("\n").first }
        table.css("tr").each do |row|
          game = nil
          data = {}
          row.css("td").each_with_index do |f, ix|
            data[keys[ix]] = f.text.gsub(nbsp, " ").strip
            next unless keys[ix] == "#"

            seqno = f.text.gsub(nbsp, " ").strip.to_i
            game = Game.find_by_seqno_and_tournament_id(seqno, id)
            game.updated_at = Time.now if game.present? && opts(:touch_games)
            game ||= Game.new(tournament_id: id, seqno:)
          end
          next unless game.andand.seqno.present?
          next unless game.present?

          game.gname = data["Gr."]
          game.data = data
          game.save!
          Game.fix_participation(game, opts)
        end

        # Rankings
        groups = doc.css("#tabs-1 fieldset legend").map(&:text).map { |s| s.split("\n").first }
        seedings_hash = seedings.includes(:player).each_with_object({}) do |seeding_, memo|
          memo["#{seeding_.player.lastname}, #{seeding_.player.firstname}"] = seeding_
        end
        result = {}
        group_results = {}
        doc.css("#tabs-1 fieldset table").each_with_index do |table_, ix|
          group = groups[ix]
          keys = table_.css("tr th").map(&:text).map { |s| s.split("\n").first }
          table_.css("tr").each do |row|
            result_row = {}
            row.css("td").each_with_index do |f, ix_|
              result_row[keys[ix_]] = f.text.gsub(nbsp, " ").strip
            end
            next unless result_row.present?

            group_results[group] ||= {}
            group_results[group][result_row["Name"]] = result_row
            result[result_row["Name"]] ||= {}
            result[result_row["Name"]][group] = result_row
          end
        end
        group_results_ranked = {}
        groups.each do |group|
          group_results_ranked[group] = group_results[group].to_a.sort_by do |a|
            -(a[1]["Punkte"].to_i * 10_000.0 + a[1]["GD"].to_f)
          end.to_h
          group_results_ranked[group].keys.each_with_index do |name, ix|
            group_results_ranked[group][name]["Rank"] = ix + 1
            result[name][group] = group_results_ranked[group][name]
          end
        end
        seedings_hash.each do |name, seeding_|
          data = seeding_.data || {}
          data["result"] = result[name]
          seeding_.data_will_change!
          seeding_.data = data
          seeding_.save!
        end
      end
    else
      table
    end
    update_columns(sync_date: Time.now)
  end

  def fix_location_from_location_text
    location_name = location_text.split("\n").first
    return unless location_name.present?
    return unless location.present?

    nil unless /#{location_name}/.match?(location.synonyms)
    # done
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end

  def reset_tournament
    Tournament.logger.info "[reset_tournament]..."
    # called from state machine only
    # use direct only for testing purposes
    if tournament_monitor.present?
      table_monitors = tournament_monitor.table_monitors
      tournament_monitor.destroy
      table_monitors.each do |tm|
        tm.reload.reset_table_monitor
      end
    end
    unless (organizer.is_a? Club) || (id.present? && id > Seeding::MIN_ID)
      seedings.where("seedings.id >= #{Seeding::MIN_ID}").destroy_all
      unless new_record?
        reload.seedings.order(:position).each_with_index do |s, ix|
          s.unprotected = true
          s.position = ix + 1
          s.save
          s.unprotected = false
        end
      end
    end
    games.where("games.id >= #{Game::MIN_ID}").destroy_all
    unless new_record? || (id.present? && id > Seeding::MIN_ID)
      self.unprotected = true
      data_will_change!
      assign_attributes(tournament_plan_id: nil, state: "new_tournament", data: {})
      save
      self.unprotected = false
      # finish_mode_selection!
      # reload
      # reorder_seedings
    end
    Tournament.logger.info "state:#{state}...[reset_tournament]"
  end

  def reorder_seedings
    l_seeding_ids = seeding_ids
    l_seeding_ids.each_with_index do |seeding_id, ix|
      Seeding.find_by_id(seeding_id).update_columns(position: ix + 1)
    end
    reload
  end

  def tournament_not_yet_started
    !tournament_started
  end

  def tournament_started
    games.where("games.id >= #{Game::MIN_ID}").present?
  end

  def date_str
    return unless date.present?

    "#{date.to_s(:db)}#{" - #{end_date.to_date.to_s(:db)}" if end_date.present?}"
  end

  def name
    title || shortname
  end

  private

  def parse_table_tr(frame1_lines, frame_points, frame_result, frames, gd, group, hb,
                     header, hs, mp, innings, nbsp, no,
                     player_list, playera_fl_name, playerb_fl_name,
                     points, result, result_lines, result_url, td_lines, tr)
    if tr.css("th").count == 1
      group_ = tr.css("th").text.gsub(nbsp, " ").strip
      if group.present? && no.present? && group_.present? && group_ != 0 && group != group_
        handle_game(frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      group = group_
    elsif tr.css("th").count > 1
      header = tr.css("th").map(&:text)
    elsif tr.css("td").count.positive?
      no_ = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      if no.present? && no_.present? && no_ != 0 && no != no_
        handle_game(frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name,
                    playerb_fl_name, frame_points, points, result)
        result = nil
        playera_fl_name = nil
        playerb_fl_name = nil
        frames = []
        frame_points = []
        innings = []
        hs = []
        gd = []
        hb = []
        points = []
        frame_result = []
        no = nil
      end
      td_lines += 1
      case header
      when %w[Partie Begegnung Partien Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant0(nbsp, points, result_lines, tr)
      when %w[Partie Begegnung Frames HB Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_frames(frame_points, hb, nbsp, tr)
        result_lines += 1
      when %w[Partie Begegnung Partien Ergebnis]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_parties(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Begegnung Erg.]
        no, playera_fl_name, playerb_fl_name, result =
          result_with_party(nbsp, points, tr)
        result_lines += 1
      when %w[Partie Frame Begegnung HB Erg.]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
      when ["Partie", "Frame", "Begegnung", "Aufn.", "", "", "Erg."]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines =
          result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
      when %w[Partie Frame Begegnung Erg.]
        if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
          result_lines += 1
          result = tr.css("td")[1].text.gsub(nbsp, " ").strip
        elsif tr.css("td").count == 4
          frames << tr.css("td")[1].text.to_i
          frame_result << tr.css("td")[3].text.gsub(nbsp, " ").strip
        else
          frame1_lines, no, playera_fl_name, playerb_fl_name =
            variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
        end
      when %w[Partie Begegnung Planzeit]
        frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs =
          variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
      when %w[Partie Begegnung Pkt. Aufn. HS GD Erg.], %w[Partie Begegnung Punkte Aufn. HS GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          Variant4(gd, hs, innings, nbsp, points, result_lines, tr)

      when ["Partie", "Begegnung", "Pkt.", "Aufn.", "", "", "Erg."]
        no, playera_fl_name, playerb_fl_name, result, result_lines = variant5(innings, nbsp, points, result_lines, tr)

      when %w[Partie Frame Begegnung Pkt. Aufn. HS GD Erg.]
        # TODO: Begegnung??
        if tr.css("td").count >= 3
          frame1_lines, frame_result, no =
            variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
        end
      when %w[Partie Begegnung Aufn. HS GD Erg.], %w[Partie Begegnung Aufn. HS GD Ergebnis]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant7(gd, hs, innings, nbsp, points, result_lines, tr)
      when %w[Partie Begegnung GD Erg.]
        no, playera_fl_name, playerb_fl_name, result, result_lines =
          variant8(gd, nbsp, points, result_lines, tr)
      else
        Rails.logger.info("===== scrape ===== unknown header #{header.inspect}")
      end
    end
    [frame1_lines, frame_points, frame_result, frames, gd, group, hb, header, hs, mp, innings, nbsp, no, player_list,
     playera_fl_name, playerb_fl_name, points, result, result_lines, result_url, td_lines, tr]
  end

  def variant0(nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant8(gd, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    gd << tr.css("td")[4].text.gsub(nbsp, " ").strip
    result = tr.css("td")[5].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant7(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant6(frame1_lines, frames, gd, hs, innings, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[5].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[6].text.gsub(nbsp, " ").strip
    frame_result = tr.css("td")[7].text.gsub(nbsp, " ").strip
    [frame1_lines, frame_result, no]
  end

  def variant5(innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def Variant4(gd, hs, innings, nbsp, points, result_lines, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
    hs << tr.css("td")[6].text.gsub(nbsp, " ").strip
    gd << tr.css("td")[7].text.gsub(nbsp, " ").strip
    result = tr.css("td")[8].text.gsub(nbsp, " ").strip
    result_lines += 1
    [no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def variant3(frame1_lines, frames, header, nbsp, innings, points, gd, hs, result_lines, result_url, tr)
    if tr.css("td").count == 3 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Endergebnis|Ergebnis):/
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5 && tr.css("td")[0].text.gsub(nbsp, " ").strip =~ /(Frame|Satz)/
      frames << tr.css("td")[0].text.to_i
      frame1_lines += 1
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    elsif tr.css("td").count == 5
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      playera_fl_name = (tr.css("td")[1].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a1, b1, c1 = tr.css("td")[1].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      playerb_fl_name = (tr.css("td")[3].inner_html.gsub(%r{</?strong>}, "").split("<br>")[0].presence || "Freilos").gsub(
        /\s*\((.*)\)/, ""
      )
      a2, b2, c2 = tr.css("td")[3].inner_html.gsub(%r{</?strong>},
                                                   "").split("<br>")[1].andand.match(%r{<i>(?:HS: (\d+); )?Aufn.: (\d+); Ø: ([\d.]+)</i>}).andand[1..]
      hs << "#{a1}/#{a2}"
      innings << "#{b1}/#{b2}"
      gd << "#{c1}/#{c2}"
      points << tr.css("td")[2].text.gsub(nbsp, "").strip
    else
      Rails.logger.info("===== scrape ===== Error: unexpected input #{header.inspect}, #{tr.inspect}, url: #{result_url}")
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines, innings, points, gd, hs]
  end

  def variant2(frame1_lines, frame_result, frames, nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    frames << tr.css("td")[1].text.to_i
    frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
    playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[3].text.gsub(nbsp, " ").strip
    frame_result << tr.css("td")[5].text.gsub(nbsp, " ").strip
    [frame1_lines, no, playera_fl_name, playerb_fl_name]
  end

  def result_with_party_variant2(frame1_lines, frame_result, frames, innings, nbsp, points, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 7
      frames << tr.css("td")[1].text.to_i
      innings << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      innings << tr.css("td")[5].text.gsub(nbsp, " ").strip
      points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[8].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party_variant(frame1_lines, frame_points, frame_result, frames, hb, nbsp, result_lines, tr)
    if tr.css("td").count == 2 && tr.css("td")[0].text.gsub(nbsp, " ").strip == "Ergebnis:"
      result_lines += 1
      result = tr.css("td")[1].text.gsub(nbsp, " ").strip
    elsif tr.css("td").count == 5
      frames << tr.css("td")[1].text.to_i
      hb << tr.css("td")[3].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[4].text.gsub(nbsp, " ").strip
    else
      no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
      frames << tr.css("td")[1].text.to_i
      frame1_lines += 1 if tr.css("td")[1].text.to_i == 1
      playera_fl_name = (tr.css("td")[2].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      playerb_fl_name = (tr.css("td")[4].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
      # innings << tr.css('td')[5].text.gsub(nbsp, " ").strip
      frame_points << tr.css("td")[3].text.gsub(nbsp, " ").strip
      hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
      frame_result << tr.css("td")[6].text.gsub(nbsp, " ").strip
    end
    [frame1_lines, no, playera_fl_name, playerb_fl_name, result, result_lines]
  end

  def result_with_party(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_parties(nbsp, points, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    points << tr.css("td")[2].text.gsub(nbsp, " ").strip
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    result = tr.css("td")[4].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def result_with_frames(frame_points, hb, nbsp, tr)
    no = tr.css("td")[0].text.to_i if tr.css("td")[0].text.present?
    playera_fl_name = (tr.css("td")[1].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    playerb_fl_name = (tr.css("td")[3].text.gsub(nbsp, " ").strip.presence || "Freilos").gsub(/\s*\((.*)\)/, "")
    frame_points << tr.css("td")[4].text.gsub(nbsp, " ").strip
    hb << tr.css("td")[5].text.gsub(nbsp, " ").strip
    result = tr.css("td")[6].text.gsub(nbsp, " ").strip
    [no, playera_fl_name, playerb_fl_name, result]
  end

  def parse_table_td(ix, logger, region, season, seeding, state_ix, states, td)
    l_state_ix = state_ix
    if td.css("div").present?
      lastname, firstname, club_str =
        td.css("div").text.gsub(nbsp, " ").strip
          .match(/(.*),\s*(.*)\s*\((.*)\)/).to_a[1..].map(&:strip)
      _player, club, _seeding, _state_ix = Player.fix_from_shortnames(lastname, firstname, season, region,
                                                                      club_str, self,
                                                                      true, true, ix)
      if club.present?
        season_participations = SeasonParticipation.joins(:player).joins(:club).joins(:season).where(
          seasons: { id: season.id }, players: { fl_name: "#{firstname} #{lastname}".strip }
        )
        if season_participations.count == 1
          season_participation = season_participations.first
          player = season_participation&.player
          if player.present?
            unless season_participation&.club_id == club.id
              real_club = season_participations.first&.club
              if real_club.present?
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} not active in Club #{club_str} [#{club.ba_id}], Region #{region.shortname}, season #{season.name}!"
                logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fixed: Player #{lastname}, #{firstname} is active in Club #{real_club.shortname} [#{real_club.ba_id}], Region #{real_club.region&.shortname}, season #{season.name}!"

                _sp = SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player.id, season.id,
                                                                                      real_club.id) ||
                  SeasonParticipation.create(player_id: player.id, season_id: season.id, club_id: real_club.id,
                                             position: ix + 1)
              end
            end
            seeding = Seeding.find_by_player_id_and_tournament_id(player.id, id) ||
              Seeding.create(player_id: player.id, tournament_id: id)
            seeding_ids.delete(seeding.id)
          end
        elsif season_participations.count.zero?
          players = Player.where(type: nil).where(firstname:, lastname:)
          if players.count.zero?
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Player #{lastname}, #{firstname} not found in club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}! Not found anywhere - typo?"
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed - added Player Player #{lastname}, #{firstname} active to club #{club_str} [#{club.ba_id}] , Region #{region.shortname}, season #{season.name}"
            player_fixed = Player.create(lastname:, firstname:, club_id: club.id)
            player_fixed.update(ba_id: 999_000_000 + player_fixed.id)
            SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                            club.id) ||
              SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
            seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id) ||
              Seeding.create(player_id: player_fixed.id, tournament_id: id)
            seeding_ids.delete(seeding.id)
          elsif players.count == 1
            player_fixed = players.first
            if player_fixed.present?
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                              club.id) ||
                SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} set active in Club #{club_str} [#{club.ba_id}], region #{region.shortname} and season #{season.name}"
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id) ||
                Seeding.create(player_id: player_fixed.id, tournament_id: id)
              seeding_ids.delete(seeding.id)
            end
          elsif players.count > 1
            clubs_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end
            club_fixed_str = players.map(&:club).map do |c|
              "#{c.shortname} [#{c.ba_id}]"
            end.first
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - Fatal: Ambiguous: Player #{lastname}, #{firstname} not active everywhere but exists in Clubs [#{clubs_str}] "
            logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Assume Player #{lastname}, #{firstname} is active in Clubs [#{club_fixed_str}] "
            player_fixed = players.first
            if player_fixed.present? && club.present?
              SeasonParticipation.find_by_player_id_and_season_id_and_club_id(player_fixed.id, season.id,
                                                                              club.id) ||
                SeasonParticipation.create(player_id: player_fixed.id, season_id: season.id, club_id: club.id)
              seeding = Seeding.find_by_player_id_and_tournament_id(player_fixed.id, id) ||
                Seeding.create(player_id: player_fixed.id, tournament_id: id)
              seeding_ids.delete(seeding.id)
            end
          end
        elsif season_participations.map(&:club_id).uniq.include?(club.id)
          # (ambiguous clubs)
          season_participation = season_participations.where(club_id: club.id).first
          player = season_participation&.player
          if player.present?
            _seeding = Seeding.find_by_player_id_and_tournament_id(player.id, id) ||
              Seeding.create(player_id: player.id, tournament_id: id)
          end
        else
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence: Player #{lastname}, #{firstname} is not active in Club[#{club.ba_id}] #{club_str}, region #{region.shortname} and season #{season.name}"
          fixed_season_participation = season_participations.last
          fixed_club = fixed_season_participation.club
          fixed_player = fixed_season_participation.player
          logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fixed: Player #{lastname}, #{firstname} playing for Club[#{fixed_club.ba_id}] #{fixed_club.shortname}, region #{fixed_club.region.shortname} and season #{season.name}"
          SeasonParticipation.find_by_player_id_and_season_id_and_club_id(fixed_player.id, season.id,
                                                                          fixed_club.id) ||
            SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id,
                                       club_id: fixed_club.id)
          seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, id) ||
            Seeding.create(player_id: fixed_player.id, tournament_id: id)
          seeding_ids.delete(seeding.id)
        end
      else
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - fatal: Club #{club_str}, region #{region.shortname} not found!! Typo?"
        fixed_club = region.clubs.create(name: club_str, shortname: club_str)
        fixed_player = fixed_club.players.create(firstname:, lastname:)
        fixed_club.update(ba_id: 999_000_000 + fixed_club.id)
        fixed_player.update(ba_id: 999_000_000 + fixed_player.id)
        SeasonParticipation.create(player_id: fixed_player.id, season_id: season.id, club_id: fixed_club.id)

        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Club #{club_str} created in region #{region.shortname}"
        logger.info "==== scrape ==== [scrape_tournaments] Inkonsistence - temporary fix: Player #{lastname}, #{firstname} playing for Club #{club_str}"
        seeding = Seeding.find_by_player_id_and_tournament_id(fixed_player.id, id) ||
          Seeding.create(player_id: fixed_player.id, tournament_id: id)
        seeding_ids.delete(seeding.id)
      end
    elsif /X/.match?(td.text.gsub(nbsp, " ").strip)
      if seeding.present?
        seeding.update_attribute(:ba_state, states[l_state_ix])
      else
        logger.info "==== scrape ==== [scrape_tournaments] Fatal 501 - seeding nil???"
        Kernel.exit(501)
      end
    end
  end

  def handle_game(frame_result, frames, gd, group, hs, hb, mp, innings, no, player_list, playera_fl_name, playerb_fl_name,
                  frame_points, points, result)
    game = games.where(seqno: no).first
    data = if frames.count > 1
             frame_data = []
             frames.each_with_index do |_frame, ix|
               frame_data << {
                 "Frame" => frames[ix],
                 "Punkte" => points[ix].presence || frame_points[ix],
                 "Aufn." => innings[ix],
                 "HS" => hs[ix],
                 "HB" => hb[ix],
                 "Durchschnitt" => gd[ix],
                 "FrameResult" => frame_result[ix]
               }.compact
             end
             {
               "Gruppe" => group,
               "Partie" => no,
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname,
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname,
               "Disziplin" => discipline.andand.name,
               "Ergebnis" => result
             }.compact.merge(frames: frame_data)
           else
             {
               "Gruppe" => group,
               "Partie" => no,
               "Frame" => frames[0],
               "Heim" => player_list[playera_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Gast" => player_list[playerb_fl_name].andand[0].andand.fullname.presence || "Freilos",
               "Disziplin" => discipline.andand.name,
               "Punkte" => points[0].presence || frame_points[0],
               "MP" => mp[0],
               "Aufn." => innings[0],
               "HS" => hs[0],
               "HB" => hb[0],
               "Durchschnitt" => gd[0],
               "FrameResult" => frame_result[0],
               "Ergebnis" => result
             }.compact
           end
    if game.present?
      game.assign_attributes(tournament: self,
                             data: data,
                             seqno: no,
                             gname: group)
      game.save!
    else
      game = Game.create!(
        tournament: self,
        data: data,
        seqno: no,
        gname: group
      )
    end
    unless game.game_participations.empty? &&
      player_list[playera_fl_name].present? &&
      player_list[playerb_fl_name].present?
      return
    end

    game.game_participations.create!(
      player_id: player_list[playera_fl_name][0].id,
      role: "Heim",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[0].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[0].andand.strip,
              "GD" => gd[0].to_s.split("/")[0].andand.strip,
              "HS" => hs[0].to_s.split("/")[0].andand.strip }.compact },
      result: points[0].to_s.split(":")[0].andand.strip,
      innings: innings[0].to_s.split("/")[0].andand.strip,
      gd: gd[0].to_s.split("/")[0].andand.strip,
      hs: hs[0].to_s.split("/")[0].andand.strip
    )
    game.game_participations.create!(
      player_id: player_list[playerb_fl_name][0].id,
      role: "Gast",
      data:
        { "results" =>
            { "Gr." => group,
              "Ergebnis" => points[0].to_s.split(":")[1].andand.strip,
              "Aufnahme" => innings[0].to_s.split("/")[1].andand.strip,
              "GD" => gd[0].to_s.split("/")[1].andand.strip,
              "HS" => hs[0].to_s.split("/")[1].andand.strip }.compact },
      result: points[0].to_s.split(":")[1].andand.strip,
      innings: innings[0].to_s.split("/")[1].andand.strip,
      gd: gd[0].to_s.split("/")[1].andand.strip,
      hs: hs[0].to_s.split("/")[1].andand.strip
    )
  end

  def before_all_events
    Tournament.logger.info "[tournament] #{aasm.current_event.inspect}"
  end
end
