# frozen_string_literal: true

# == Schema Information
#
# Table name: region_ccs
#
#  id         :bigint           not null, primary key
#  base_url   :string
#  context    :string
#  name       :string
#  public_url :string
#  shortname  :string
#  username   :string
#  userpw     :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  cc_id      :integer
#  region_id  :integer
#
# Indexes
#
#  index_region_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#  index_region_ccs_on_context            (context) UNIQUE
#
class RegionCc < ApplicationRecord
  include LocalProtector
  belongs_to :region
  has_many :branch_ccs

  alias_attribute :fedId, :cc_id

  REPORT_LOGGER_FILE = "#{Rails.root}/log/report.log"
  REPORT_LOGGER = Logger.new(REPORT_LOGGER_FILE)

  PUBLIC_ACCESS = {
    "Einzel" => "sb_meisterschaft.php"
  }

  # PHPSESSID = "3e7da06b0149fe5ad787246fc7a0e2b4"
  BASE_URL = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"

  before_save :set_paper_trail_whodunnit

  def self.logger
    REPORT_LOGGER
  end

  def self.save_log(name)
    FileUtils.mv(REPORT_LOGGER_FILE, "#{Rails.root}/log/#{name}.log")
    REPORT_LOGGER.reopen
  end

  # -------------------------------------------------------------------------
  # Lazy client accessor — per D-06: passes self credentials to ClubCloudClient
  # -------------------------------------------------------------------------
  def club_cloud_client
    @club_cloud_client ||= RegionCc::ClubCloudClient.new(
      base_url: base_url,
      username: username,
      userpw: userpw
    )
  end

  # -------------------------------------------------------------------------
  # HTTP delegation wrappers — backward compatibility for direct callers
  # -------------------------------------------------------------------------
  def get_cc(action, get_options = {}, opts = {})
    club_cloud_client.get(action, get_options, opts)
  end

  def post_cc(action, post_options = {}, opts = {})
    club_cloud_client.post(action, post_options, opts)
  end

  def post_cc_with_formdata(action, post_options = {}, opts = {})
    club_cloud_client.post_with_formdata(action, post_options, opts)
  end

  def get_cc_with_url(action, url, get_options = {}, opts = {})
    club_cloud_client.get_with_url(action, url, get_options, opts)
  end

  # -------------------------------------------------------------------------
  # League Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_leagues(opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_leagues, **opts)
  end

  def sync_league_teams(league_cc, opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_league_teams, league_cc: league_cc, **opts)
  end

  def sync_league_teams_new(league_cc, opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_league_teams_new, league_cc: league_cc, **opts)
  end

  def sync_league_plan(league, opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_league_plan, league: league, **opts)
  end

  def sync_team_players(league_team, opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_team_players, league_team: league_team, **opts)
  end

  def sync_team_players_structure(opts = {})
    RegionCc::LeagueSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_team_players_structure, **opts)
  end

  # -------------------------------------------------------------------------
  # Club Sync
  # -------------------------------------------------------------------------
  def sync_clubs(opts = {})
    RegionCc::ClubSyncer.call(region_cc: self, client: club_cloud_client, **opts)
  end

  # -------------------------------------------------------------------------
  # Branch Sync
  # -------------------------------------------------------------------------
  def sync_branches(opts = {})
    RegionCc::BranchSyncer.call(region_cc: self, client: club_cloud_client, **opts)
  end

  # -------------------------------------------------------------------------
  # Tournament Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_tournaments(opts = {})
    RegionCc::TournamentSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_tournaments, **opts)
  end

  def sync_tournament_ccs(opts = {})
    RegionCc::TournamentSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_tournament_ccs, **opts)
  end

  def sync_tournament_series_ccs(opts = {})
    RegionCc::TournamentSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_tournament_series_ccs, **opts)
  end

  def sync_championship_type_ccs(opts = {})
    RegionCc::TournamentSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_championship_type_ccs, **opts)
  end

  def fix_tournament_structure(opts = {})
    RegionCc::TournamentSyncer.call(region_cc: self, client: club_cloud_client, operation: :fix_tournament_structure, **opts)
  end

  # -------------------------------------------------------------------------
  # Registration Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_registration_list_ccs(opts = {})
    RegionCc::RegistrationSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_registration_list_ccs, **opts)
  end

  def sync_registration_list_ccs_detail(season, branch_cc, opts = {})
    RegionCc::RegistrationSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_registration_list_ccs_detail, season: season, branch_cc: branch_cc, **opts)
  end

  # -------------------------------------------------------------------------
  # Competition Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_competitions(opts = {})
    RegionCc::CompetitionSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_competitions, **opts)
  end

  def sync_seasons_in_competitions(opts = {})
    RegionCc::CompetitionSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_seasons_in_competitions, **opts)
  end

  # -------------------------------------------------------------------------
  # Party Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_parties(opts = {})
    RegionCc::PartySyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_parties, **opts)
  end

  def sync_party_games(parties_todo_ids, opts = {})
    RegionCc::PartySyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_party_games, parties_todo_ids: parties_todo_ids, **opts)
  end

  # -------------------------------------------------------------------------
  # Game Plan Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_game_plans(opts = {})
    RegionCc::GamePlanSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_game_plans, **opts)
  end

  def sync_game_details(opts = {})
    RegionCc::GamePlanSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_game_details, **opts)
  end

  # -------------------------------------------------------------------------
  # Metadata Sync — dispatcher pattern per D-04
  # -------------------------------------------------------------------------
  def sync_category_ccs(opts = {})
    RegionCc::MetadataSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_category_ccs, **opts)
  end

  def sync_group_ccs(opts = {})
    RegionCc::MetadataSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_group_ccs, **opts)
  end

  def sync_discipline_ccs(opts = {})
    RegionCc::MetadataSyncer.call(region_cc: self, client: club_cloud_client, operation: :sync_discipline_ccs, **opts)
  end

  # -------------------------------------------------------------------------
  # Structure orchestrators — STAY IN MODEL (call multiple syncers)
  # -------------------------------------------------------------------------

  def synchronize_league_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    leagues_region_todo = League
                          .joins(league_teams: :club)
                          .where(season: season, organizer_type: "Region", organizer_id: region.id)
                          .where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] })
                          .where("clubs.region_id = ?", region.id).uniq
    leagues_todo_ids = leagues_region_todo.to_a.map(&:id)
    leagues_done, errMsg = sync_leagues(opts)
    raise_err_msg("synchronize_league_structure", errMsg) if errMsg.present?
    leagues_done_ids = leagues_done.map(&:id)
    leagues_still_todo_ids = leagues_todo_ids - leagues_done_ids
    unless leagues_still_todo_ids.blank?
      leagues_still_todo_ids.each do |league_id|
        league = League[league_id]
        if league.blank?
          raise_err_msg("synchronize_league_structure", "no league with id #{league_id}")
        else
          LeagueCc.create_from_ba(league, opts)
        end
      end
    end
    league_ids_overdone = leagues_done_ids - leagues_todo_ids
    return if league_ids_overdone.blank?

    msg = "more league_ids with context #{opts[:context].upcase} than expected in CC: #{League.where(id: league_ids_overdone).map do |league|
                                                                                          "#{league.name}[#{league.id}] - #{league.discipline.andand.name}"
                                                                                        end }"
    RegionCc.logger.info msg
    Rails.logger.info msg
  end

  def synchronize_league_plan_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    force_update = opts[:armed]
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    leagues_region_todo = League.joins(league_teams: :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where(
      "clubs.region_id = ?", region.id
    ).where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] }).uniq
    leagues_todo_ids = leagues_region_todo.to_a.map(&:id)
    leagues_done, errMsg = sync_league_plan(opts)
    raise_err_msg("synchronize_league_structure", errMsg) if errMsg.present?
    leagues_done_ids = leagues_done.map(&:id)
    leagues_still_todo_ids = leagues_todo_ids - leagues_done_ids
    unless leagues_still_todo_ids.blank?
      leagues_still_todo_ids.each do |league_id|
        league = League[league_id]
        if league.blank?
          raise_err_msg("synchronize_league_structure", "no league with id #{league_id}")
        else
          next if league.discipline_id.blank?

          if force_update
            LeagueCc.create_league_plan_from_ba(league, opts)
          else
            msg = "REPORT WOULD CREATE LeagueCc Plan from BA: #{league.attributes}"
            RegionCc.logger.info msg
            Rails.logger.info msg
          end
        end
      end
    end
    league_ids_overdone = leagues_done_ids - leagues_todo_ids
    return if league_ids_overdone.blank?

    msg = "more league_ids with context #{opts[:context].upcase} than expected in CC: #{League.where(id: league_ids_overdone).map do |league|
                                                                                          "#{league.name}[#{league.id}] - #{league.discipline.andand.name}"
                                                                                        end }"
    RegionCc.logger.info msg
    Rails.logger.info msg
  end

  def synchronize_tournament_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    tournament_region_todo = Tournament
                             .where(season: season, organizer_type: "Region", organizer_id: region.id)
                             .where.not(tournaments: { ba_id: opts[:exclude_tournament_ba_ids] })
    tournaments_todo_ids = tournament_region_todo.to_a.map(&:id)
    tournaments_done, errMsg = sync_tournaments(opts)
    raise_err_msg("synchronize_tournament_structure", errMsg) if errMsg.present?
    tournaments_done_ids = tournaments_done.map(&:id)
    tournaments_still_todo_ids = tournaments_todo_ids - tournaments_done_ids
    branch_cc_ids = []
    unless tournaments_still_todo_ids.blank?
      tournaments_still_todo_ids.each do |tournament_id|
        tournament = Tournament[tournament_id]
        next if tournament.discipline.root.name == "Pool" || tournament.discipline.root.name == "Snooker"

        begin
          if tournament.blank?
            raise_err_msg("synchronize_tournament_structure", "no tournament with id #{tournament_id}")
          else
            RegistrationCc.create_from_ba(tournament, opts)
            branch_cc_ids |= [tournament.discipline.root.branch_cc.cc_id]
          end
        rescue Exception => e
          Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
        end
      end
    end
    branch_cc_ids.each do |branch_cc_id|
      branch_cc = BranchCc.find_by_cc_id(branch_cc_id)
      sync_registration_list_ccs_detail(season, branch_cc, opts.merge(update_from_cc: false, release: true))
    end
    unless tournaments_still_todo_ids.blank?
      tournaments_still_todo_ids.each do |tournament_id|
        tournament = Tournament[tournament_id]
        next if tournament.discipline.root.name == "Pool" || tournament.discipline.root.name == "Snooker"

        if tournament.blank?
          raise_err_msg("synchronize_tournament_structure", "no tournament with id #{tournament_id}")
        else
          TournamentCc.create_from_ba(tournament, opts)
        end
      end
    end
    tournament_ids_overdone = tournaments_done_ids - tournaments_todo_ids
    return if tournament_ids_overdone.blank?

    msg = "more tournament_ids with context #{opts[:context].upcase} than expected in CC: #{Tournament.where(id: tournament_ids_overdone).map do |tournament|
                                                                                              "#{tournament.title}[#{tournament.id}] - #{tournament.discipline.andand.name}"
                                                                                            end }"
    RegionCc.logger.info msg
    Rails.logger.info msg
  end

  # -------------------------------------------------------------------------
  # Non-sync utility methods (keep in model — not ClubCloud sync)
  # -------------------------------------------------------------------------

  # Discovers the admin ClubCloud URL from the public website's "Anmeldung" link
  # Returns the discovered URL or nil if not found
  def discover_admin_url_from_public_site
    unless region.present?
      Rails.logger.warn "[discover_admin_url] No region association found"
      return nil
    end

    unless region.public_cc_url_base.present?
      Rails.logger.warn "[discover_admin_url] No public_cc_url_base for region: #{region.shortname}"
      return nil
    end

    public_url = region.public_cc_url_base.chomp("/")
    Rails.logger.info "[discover_admin_url] Scraping public site: #{public_url}"

    begin
      uri = URI(public_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER if http.use_ssl?
      http.open_timeout = 5
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri)
      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn "[discover_admin_url] Failed to fetch public site: #{response.code}"
        return nil
      end

      doc = Nokogiri::HTML(response.body)

      # Look for the "Anmeldung" (Login) link in the navigation
      anmeldung_link = doc.css('a[title*="Anmeldung"]').first

      if anmeldung_link && anmeldung_link["href"].present?
        discovered_url = anmeldung_link["href"].chomp("/")
        Rails.logger.info "[discover_admin_url] Discovered admin URL from Anmeldung link: #{discovered_url}"
        return discovered_url
      end

      # Fallback: Look for any link pointing to club-cloud.de
      club_cloud_link = doc.css('a[href*="club-cloud.de"]').first
      if club_cloud_link && club_cloud_link["href"].present?
        discovered_url = club_cloud_link["href"].chomp("/")
        Rails.logger.info "[discover_admin_url] Discovered admin URL from club-cloud.de link: #{discovered_url}"
        return discovered_url
      end

      Rails.logger.warn "[discover_admin_url] No Anmeldung or club-cloud.de link found on public site"
      nil
    rescue StandardError => e
      Rails.logger.error "[discover_admin_url] Error scraping public site: #{e.message}"
      Rails.logger.error "[discover_admin_url] Backtrace: #{e.backtrace.first(3).join("\n")}"
      nil
    end
  end

  # Ensures base_url is set correctly for admin operations
  # Auto-discovers from public site if needed
  def ensure_admin_base_url!
    if base_url.present? && !base_url.include?("ndbv.de") && base_url.include?("club-cloud.de")
      return base_url
    end

    Rails.logger.info "[ensure_admin_base_url] Current base_url is invalid (#{base_url}), attempting auto-discovery..."

    discovered_url = discover_admin_url_from_public_site
    target_url = discovered_url.presence || BASE_URL

    begin
      if base_url != target_url
        Rails.logger.info "[ensure_admin_base_url] Updating base_url from '#{base_url}' to '#{target_url}'"
        update_column(:base_url, target_url)
        reload
      end
    rescue StandardError => e
      Rails.logger.warn "[ensure_admin_base_url] Could not update base_url in database: #{e.message}"
      Rails.logger.warn "[ensure_admin_base_url] Using fallback URL: #{target_url}"
      self.base_url = target_url
    end

    base_url
  end

  def fix(opts = {})
    armed = opts.delete(:armed)
    raise ArgumentError unless opts[:name].present?

    if armed
      RegionCc.logger.info "NOT_IMPLEMENTED fix region_name to \"#{opts[:name]}\""
    else
      RegionCc.logger.info "WILL fix region_name to \"#{opts[:name]}\""
    end
  rescue Exceptions => e
    e
  end

  # Class-level sync for all regions from ClubCloud (not delegated — uses class context)
  def self.sync_regions(opts = {})
    armed = opts[:armed].present?
    regions = []
    _, doc = RegionCc.new(base_url: RegionCc::BASE_URL).get_cc("showClubList", {}, opts)
    if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
      RegionCc.logger.error msg
      return nil
    else
      selector = doc.css('select[name="fedId"]')[0]
      options_tags = selector.css("option")
      options_tags.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*) \((.*)\)/)
        region_name = match[1]
        shortname = match[2]
        region = Region.find_by_shortname(shortname)
        args = {
          cc_id: cc_id,
          region_id: region.id,
          context: region.shortname.downcase,
          shortname: shortname,
          name: region_name,
          base_url: BASE_URL
        }
        region_cc = RegionCc.find_by_cc_id(cc_id) || RegionCc.new(args)
        region_cc.assign_attributes(args)
        region_cc.save
        regions.push(region)

        if region_name != region.name
          RegionCc.logger.warn "REPORT! [sync_regions] Name des Regionalverbandes unterschiedlich: CC: #{region_name} BA: #{region.name}"
          region_cc.fix(name: region.name, armed: armed)
        end
      end
    end
    regions
  end

  private

  def raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg} #{caller}"
    raise ArgumentError, msg, caller
  end
end
