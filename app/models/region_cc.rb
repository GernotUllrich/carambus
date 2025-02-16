require "net/http/post/multipart"
require "stringio"
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

  DEBUG = true

  STATUS_MAP = {
    active: 1,
    passive: 2
  }.freeze

  before_save :set_paper_trail_whodunnit
  PATH_MAP = { # maps to path and read_only {true|false}|}
    "home" => ["", true],
    # "showClubList" => "/admin/approvement/player/showClubList.php",
    "createLeagueSave" => ["/admin/league/createLeagueSave.php", false],
    # fedId: 20
    # branchId: 10
    # subBranchId: 2
    # seasonId: 11
    # seasonId: 11
    # leagueName: Oberliga Dreiband
    # leagueShortName: OD
    # reportId: 20
    # prefix: 0
    # staffelName:
    # sportdistrictId: 0
    # sbut:
    "showLeagueList" => ["/admin/report/showLeagueList.php", true],
    "showLeague" => ["/admin/league/showLeague.php", true],

    "admin_report_showLeague" => ["/admin/report/showLeague.php", true],
    # branchId: 6
    # fedId: 20
    # subBranchId: 1
    # seasonId: 8
    # leagueId: 34
    "admin_report_showLeague_create_team" => ["/admin/report/showLeague_create_team.php", false],
    # teamCounter: 2
    # fedId: 20
    # leagueId: 32
    # branchId: 6
    # subBranchId: 1
    # seasonId: 8
    "spielbericht_anzeigen" => ["/admin/reportbuilder2/spielbericht_anzeigen.php", true],
    # p=#{fedId}-#{branchId}-#{cc_id}-&    cc_id vom GamePlanCc
    "showTeam" => ["/admin/announcement/team/showTeam.php", true],
    # fedId: 20,
    # branchId: 6,
    # subBranchId: 1,
    # sportDistrictId: *,
    # clubId: 1004,
    # originalBranchId: 6,
    # seasonId: 1,
    # teamId: 98
    "editTeam" => ["admin/announcement/team/editTeamCheck.php", false],
    "showClubList" => ["/admin/announcement/team/showClubList.php", true],
    # fedId: 20
    # branchId: 6
    # subBranchId: 11
    # sportDistrictId: *
    # statusId: 1   (1 = active)
    "showLeague_show_teamplayer" => ["/admin/report/showLeague_show_teamplayer.php", true],
    # GET
    # p: 187
    "showLeague_add_teamplayer" => ["/admin/report/showLeague_add_teamplayer.php", false],
    # fedId: 20,
    # leagueId: 34,
    # staffelId: 0,
    # branchId: 6,
    # subBranchId: 1,
    # seasonId: 8,
    # p: 187,
    # passnr: 221109,
    "showAnnounceList" => ["/admin/announcement/team/showAnnounceList.php", true],
    # fedId: 20
    # branchId: 10
    # subBranchId: 2
    # sportDistrictId: *
    # clubId: 1011
    # originalBranchId: 10
    # seasonId: 45
    "spielbericht" => ["/admin/bm_mw/spielbericht.php", true],
    # errMsgNew:
    # matchId: 572
    # teamId: 189
    # woher: 1
    # firstEntry: 1
    #  ODER ?!
    # sortKey: NAME
    # branchid: 6
    # woher: 1
    # wettbewerb: 1
    # sportkreis: *
    # saison: 2010/2011
    # partienr: 4003
    # seekBut:
    "showLeague_create_team_save" => ["/admin/report/showLeague_create_team_save.php", false],
    # fedId: 20
    # leagueId: 61
    # branchId: 10
    # subBranchId: 2
    # seasonId: 11
    # ncid: 1573   TODO was ist ncid
    # sbut:
    "spielberichte" => ["/admin/reportbuilder2/spielberichte.php", true],
    # GET Request
    # p: "#{fedId}-#{branchId}"
    "spielberichtCheck" => ["/admin/bm_mw/spielberichtCheck.php", true],
    "spielberichtSave" => ["/admin/bm_mw/spielberichtSave.php", false],
    # "errMsgNew:
    #  fedId: 20
    #  branchId: 6
    #  subBranchId: 1
    #  wettbewerb: 1
    #  leagueId: 34
    #  seasonId: 8
    #  teamId: 185
    #  matchId: 571
    #  saison: 2010/2011
    #  partienr: 4003
    #  woher: 1
    #  woher2: 1
    #  editBut: "
    #  TODO ODER MIT GET-REQUEST??
    #
    # a: 703     party_cc.match_id
    # b: 2        ???
    # c: 193>    team cc_id

    # memo: Die Partien von Florian Knipfer wurden aus der Wertung gestrichen, wegen Einsatz als Ersatz-Spieler in der Bundesliga !!
    # protest:
    # zuNullTeamId: 0
    # wettbewerb: 1
    # partienr: 4004
    # saison:
    # 572-1-1-1-pid1: 10130
    # 572-1-1-1-pid2: 10353
    # 572-1-1-sc1: 125
    # 572-1-1-sc2: 70
    # 572-1-1-in1: 46
    # 572-1-1-in2: 45
    # 572-1-1-br1: 13
    # 572-1-1-br2: 10
    # 572-1-1-vo1:
    # 572-1-1-vo2:
    # 572-2-1-1-pid1: 10243
    # 572-2-1-1-pid2: 0
    # 572-2-1-sc1: 0
    # 572-2-1-sc2: 0
    # 572-2-1-in1:
    # 572-2-1-in2:
    # 572-2-1-br1:
    # 572-2-1-br2:
    # 572-2-1-vo1:
    # 572-2-1-vo2:
    # 572-3-1-1-pid1: 0
    # 572-3-1-1-pid2: 10121
    # 572-3-1-sc1: 9
    # 572-3-1-sc2: 4
    # 572-3-1-in1:
    # 572-3-1-in2:
    # 572-3-1-br1:
    # 572-3-1-br2:
    # 572-3-1-vo1:
    # 572-3-1-vo2:
    # 572-4-1-1-pid1: 0
    # 572-4-1-1-pid2: 10108
    # 572-4-1-sc1: 2
    # 572-4-1-sc2: 8
    # 572-4-1-in1:
    # 572-4-1-in2:
    # 572-4-1-br1:
    # 572-4-1-br2:
    # 572-4-1-vo1:
    # 572-4-1-vo2:
    # 572-6-1-1-pid1: 0
    # 572-6-1-1-pid2: 0
    # 572-6-1-sc1: 8
    # 572-6-1-sc2: 4
    # 572-6-1-in1:
    # 572-6-1-in2:
    # 572-6-1-br1:
    # 572-6-1-br2:
    # 572-6-1-vo1:
    # 572-6-1-vo2:
    # 572-7-1-1-pid1: 0
    # 572-7-1-1-pid2: 10108
    # 572-7-1-sc1: 9
    # 572-7-1-sc2: 6
    # 572-7-1-in1:
    # 572-7-1-in2:
    # 572-7-1-br1:
    # 572-7-1-br2:
    # 572-7-1-vo1:
    # 572-7-1-vo2:
    # 572-8-1-1-pid1: 10130
    # 572-8-1-1-pid2: 10121
    # 572-8-1-sc1: 7
    # 572-8-1-sc2: 5
    # 572-8-1-in1:
    # 572-8-1-in2:
    # 572-8-1-br1:
    # 572-8-1-br2:
    # 572-8-1-vo1:
    # 572-8-1-vo2:
    # 572-9-1-1-pid1: 10243
    # 572-9-1-1-pid2: 0
    # 572-9-1-sc1:
    # 572-9-1-sc2:
    # 572-9-1-in1:
    # 572-9-1-in2:
    # 572-9-1-br1:
    # 572-9-1-br2:
    # 572-9-1-vo1:
    # 572-9-1-vo2:
    "massChangingCheck" => ["/admin/report/massChangingCheck.php", true],
    # fedId: 20,
    # leagueId: 34,
    # branchId: 6,
    # subBranchId: 1,
    # seasonId: 8,
    # staffelId:
    "massChangingCheckAuth" => ["/admin/report/massChangingCheckAuth.php", true],
    # https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/report/massChangingCheckAuth.php?

    # teamCounter: 10
    # fedId: 20
    # leagueId: 36
    # branchId: 6
    # subBranchId: 1
    # seasonId: 8
    # editAll:
    # matchId: 715
    "showCategoryList" => ["/admin/einzel/category/showCategoryList.php", true],
    # fedId: 20
    # branchId: 10
    "showCategory" => ["/admin/einzel/category/showCategory.php", true],
    # fedId: 20
    # branchId: 6
    # catId: 14
    "editCategoryCheck" => ["/admin/einzel/category/editCategoryCheck.php", true],
    # fedId: 20
    # branchId: 6
    # catId: 14
    "showTypeList" => ["/admin/einzel/type/showTypeList.php", true],
    # fedId: 20
    # branchId: 10
    "showType" => ["/admin/einzel/type/showType.php", true],
    # fedId: 20
    # branchId: 10
    # season: 2011/2012
    "showSerienList" => ["/admin/einzel/serie/showSerienList.php", true],
    # fedId: 20
    # branchId: 10
    "showSerie" => ["/admin/einzel/serie/showSerie.php", true],
    # fedId: 20
    # branchId: 10
    # season: 2022/2023
    # serienId: 4
    "showGroupList" => ["/admin/einzel/gruppen/showGroupList.php", true],
    # branchId: 10
    "showGroup" => ["/admin/einzel/gruppen/showGroup.php", true],
    # branchId: 10
    "showMeldelistenList" => ["/admin/einzel/meldelisten/showMeldelistenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    "showMeldeliste" => ["/admin/einzel/meldelisten/showMeldeliste.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meldelisteId: 66
    "showMeisterschaftenList" => ["/admin/einzel/meisterschaft/showMeisterschaftenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meisterTypeId: *
    # t: 2
    "showMeisterschaft" => ["/admin/einzel/meisterschaft/showMeisterschaft.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meisterschaftId: 66
    "club-showMeldelistenList" => ["/admin/einzel/clubmeldung/showMeldelistenList.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    "club-showMeldeliste" => ["/admin/einzel/clubmeldung/showMeldeliste.php", true],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # catId: *
    # season: 2010/2011
    # meldelisteId: 66
    "createMeldelisteSave" => ["/admin/einzel/meldelisten/createMeldelisteSave.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # selectedDisciplinId: 13
    # selectedCatId: 17
    # meldelistenName: 5. Petit Prix Einband Vorrunde 1
    # meldeschluss: 29.01.2011
    # stichtag: 01.01.2011
    # save:
    "createMeldelisteCheck" => ["/admin/einzel/meldelisten/createMeldelisteCheck.php", false],
    # branchId: 6
    # fedId: 20
    # disciplinId: *
    # catId: *
    # season: 2022/2023
    # create:
    "releaseMeldeliste" => ["/admin/einzel/meldelisten/releaseMeldeliste.php", false],
    # branchId: 10,
    # fedId: cc_id,
    # season: season.name,
    # meldelisteId: cc_id_ml
    # release: ""
    "createMeisterschaftSave" => ["/admin/einzel/meisterschaft/createMeisterschaftSave.php", false],
    "editMeisterschaftCheck" => ["/admin/einzel/meisterschaft/editMeisterschaftCheck.php", false],
    "editMeisterschaftSave" => ["/admin/einzel/meisterschaft/editMeisterschaftSave.php", false],
    "deleteMeldeliste" => ["/admin/einzel/meldelisten/deleteMeldeliste.php", false],
    "deleteErgebnis" => ["/admin/einzel/meisterschaft/deleteErgebnis.php", false],
    "showErgebnisliste" => ["/admin/einzel/meisterschaft/showErgebnisliste.php", false],
    "importErgebnisseStep1" => ["/admin/einzel/meisterschaft/importErgebnisseStep1.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # ibut
    "importErgebnisseStep2" => ["/admin/einzel/meisterschaft/importErgebnisseStep2.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # importFile - filename="result3.csv"
    # saveBut
    "importErgebnisseStep3" => ["/admin/einzel/meisterschaft/importErgebnisseStep3.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: *
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # saveBut
    "importRangliste1" => ["/admin/einzel/meisterschaft/importRangliste1.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # importBut
    "importRangliste2" => ["/admin/einzel/meisterschaft/importRangliste2.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    # ranglistenimport - filename="rangliste3.csv"
    # importBut
    "showRangliste" => ["/admin/einzel/meisterschaft/showRangliste.php", false],
    # fedId: 20
    # branchId: 10
    # disciplinId: 9
    # season: 2010/2011
    # catId: *
    # meisterTypeId: *
    # meisterschaftsId: 109
    "releaseRangliste.php" => ["/admin/einzel/meisterschaft/releaseRangliste.php.php", false],
    #  fedId: 20
    #  branchId: 10
    #   disciplinId: 9
    #   season: 2010/2011
    #   catId: *
    #   meisterTypeId: *
    #   meisterschaftsId: 109
    #   releaseBut
    "suche" => ["suche.php", true]
    # c:
    # f:
    # 10
    # v:
    # Gerd
    # n:
    # Schmitz
    # pa:
    # lastPageNo:
    # nextPageNo:
    # 1
    # pno:
    # s:
  }.freeze

  PUBLIC_ACCESS = {
    "Einzel" => "sb_meisterschaft.php"
    # b:
    # s:
    # 2022/2023
    # c:
    # d:
    # t:
    # 0
    # eps:
    # 100000
    # lastPageNo:
    # nextPageNo:
    # 1
    # pno:
    # aa:
    # 6
  }

  # PHPSESSID = "3e7da06b0149fe5ad787246fc7a0e2b4"
  BASE_URL = "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"

  def self.logger
    REPORT_LOGGER
  end

  def self.save_log(name)
    FileUtils.mv(REPORT_LOGGER_FILE, "#{Rails.root}/log/#{name}.log")
    REPORT_LOGGER.reopen
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

  def post_cc_with_formdata(action, post_options = {}, opts = {})
    dry_run = opts[:armed].blank?
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      read_only_action = PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{PATH_MAP[action][0]} with payload #{post_options}" if DEBUG
      else
        # read_only
        RegionCc.logger.debug "[#{action}] #{if dry_run
                                               "WILL"
                                             end} POST #{action} #{PATH_MAP[action][0]} with payload #{post_options}"
      end
      doc = nil
      res = nil
      if !dry_run || read_only_action
        ## f = FormData.new
        ## f.append(post_options.reject { |_k, v| v.blank? })
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        # http.set_debug_output($stdout) # Logger.new("foo.log") works too
        req = Net::HTTP::Post::Multipart.new(uri.request_uri, post_options)
        ## req = f.post_request(uri.request_uri)
        req["cookie"] = "PHPSESSID=#{opts[:session_id]}"
        # req['Content-Type'] = 'application/x-www-form-urlencoded'
        # req.content_type = f.content_type
        # req.content_length = f.size
        # req.body_stream = f
        req["referer"] = referer if referer.present?
        req["cache-control"] = "max-age=0"
        req["upgrade-insecure-requests"] = "1"
        req["accept-language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6"
        req["accept"] =
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        # req.set_form_data(post_options.reject { |_k, v| v.blank? })
        # sleep(0.5)
        res = http.request(req)
        doc = if res.message == "OK"
                Nokogiri::HTML(res.body)
              else
                Nokogiri::HTML(res.message)
              end
      end
    end
    [res, doc]
  end

  def post_cc(action, post_options = {}, opts = {})
    dry_run = opts[:armed].blank?
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if PATH_MAP[action].present?
      url = base_url + PATH_MAP[action][0]
      read_only_action = PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{PATH_MAP[action][0]} with payload #{post_options}" if DEBUG
      else
        # read_only
        RegionCc.logger.debug "[#{action}] #{if dry_run
                                               "WILL"
                                             end} POST #{action} #{PATH_MAP[action][0]} with payload #{post_options}"
      end
      doc = nil
      res = nil
      if !dry_run || read_only_action
        uri = URI(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        req = Net::HTTP::Post.new(uri.request_uri)
        req["cookie"] = "PHPSESSID=#{opts[:session_id]}"
        req["Content-Type"] = "application/x-www-form-urlencoded"
        req["referer"] = referer if referer.present?
        req["cache-control"] = "max-age=0"
        req["upgrade-insecure-requests"] = "1"
        req["accept-language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6"
        req["accept"] =
          "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
        req.set_form_data(post_options.reject { |_k, v| v.blank? })
        # sleep(0.5)
        res = http.request(req)
        doc = if res.message == "OK"
                Nokogiri::HTML(res.body)
              else
                Nokogiri::HTML(res.message)
              end
      end
    end
    [res, doc]
  end

  def get_cc(action, get_options = {}, opts = {})
    raise ArgumentError, "Unknown Action", caller unless PATH_MAP[action].present?

    get_options[:referer] ||= ""
    url = base_url + PATH_MAP[action][0]
    get_cc_with_url(action, url, get_options, opts)
  end

  def get_cc_with_url(action, url, get_options = {}, opts = {})
    referer = base_url + get_options.delete(:referer)
    Rails.logger.debug "[get_cc] GET #{action} with payload #{get_options}" if DEBUG
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req = Net::HTTP::Get.new(uri.path)
    req.set_form_data(get_options)
    # instantiate a new Request object
    req = Net::HTTP::Get.new(uri.path + ("?" unless /\?$/.match?(uri.path)).to_s + req.body)
    req["cookie"] = "PHPSESSID=#{opts[:session_id]}" if opts[:session_id].present?
    req["referer"] = referer if referer.present?
    res = http.request(req)
    doc = if res.message == "OK"
            Nokogiri::HTML(res.body)
          else
            Nokogiri::HTML(res.message)
          end
    [res, doc]
  end

  def synchronize_league_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    leagues_region_todo = League
                          .joins(league_teams: :club)
                          .where(season: season, organizer_type: "Region", organizer_id: region.id)
                          .where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] })
                          .where("clubs.region_id = ?", region.id).uniq
    # TODO: forget DBU leagues for now
    # dbu_region = Region.find_by_shortname('DBU')
    # dbu_leagues_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: dbu_region.id).where(
    #   'clubs.region_id = ?', region.id
    # ).uniq
    # leagues_todo_ids = (leagues_region_todo.to_a + dbu_leagues_todo.to_a).map(&:id)
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
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    leagues_region_todo = League.joins(league_teams: :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where(
      "clubs.region_id = ?", region.id
    ).where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] }).uniq
    # TODO: forget DBU leagues for now
    # dbu_region = Region.find_by_shortname('DBU')
    # dbu_leagues_todo = League.joins(league_teams: :club).where(season: season, organizer_type: 'Region', organizer_id: dbu_region.id).where(
    #   'clubs.region_id = ?', region.id
    # ).uniq
    # leagues_todo_ids = (leagues_region_todo.to_a + dbu_leagues_todo.to_a).map(&:id)
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
          next if league.discipline_id.blank? # TODO: TEST RENOVE ME

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
    ReagionCc.logger.info msg
    Rails.logger.info msg
  end

  def sync_team_players_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    region_cc = Region.where(shortname: opts[:context].upcase).first.region_cc
    League.where(season: season, organizer_type: "Region", organizer_id: region.id).each do |league|
      next if opts[:exclude_league_ba_ids].include?(league.ba_id)
      next if league.discipline_id.blank? # TODO: TEST REMOVE ME

      # next unless league.ba_id == 4869
      league_team_players = {}
      league.parties.each do |party|
        league_team_players[party.league_team_a_id] ||= []
        league_team_players[party.league_team_b_id] ||= []
        party.party_games.each do |party_game|
          unless league_team_players[party.league_team_a_id].include?(party_game.player_a_id)
            league_team_players[party.league_team_a_id].push(party_game.player_a_id)
          end
          unless league_team_players[party.league_team_b_id].include?(party_game.player_b_id)
            league_team_players[party.league_team_b_id].push(party_game.player_b_id)
          end
        end
      end
      league_team_player_object_hash = {}
      league_team_players.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        next unless league_team.present?

        league_team_player_object_hash[league_team.id] ||= []
        league_team_players[lt_id].each do |p_id|
          player = Player[p_id]
          league_team_player_object_hash[league_team.id].push(player)
        end
      end
      league_team_player_object_hash.each_key do |lt_id|
        league_team = LeagueTeam[lt_id]
        next unless league_team.present?

        league_team_cc = league_team.league_team_cc
        if league_team_cc.present?

          league_team_players_todo = league_team_player_object_hash[lt_id]
          league_team_player_done = region_cc.sync_team_players(league_team, opts)
          league_team_player_still_todo = league_team_players_todo - league_team_player_done
          league_team_player_still_todo.each do |player|
            next if player.andand.ba_id.blank? || player.ba_id.to_i > 999_000_000

            args = { fedId: league_team_cc.fedId,
                     leagueId: league_team_cc.leagueId,
                     staffelId: 0,
                     branchId: league_team_cc.branchId,
                     subBranchId: league_team_cc.subBranchId,
                     seasonId: league_team_cc.seasonId,
                     p: league_team_cc.p,
                     passnr: player.ba_id,
                     referer: "/admin/bm_mw/spielberichtCheck.php?" }
            if true
              _, doc = region_cc.post_cc(
                "showLeague_add_teamplayer",
                args,
                opts
              )
              err_msg = doc.css('input[name="errMsg"]')[0].andand["value"]
              if err_msg.present?
                RegionCc.logger.info "REPORT! ERROR LeagueTeam #{league_team.andand.name} Player #{player.fullname} DBU-NR=#{player.ba_id} not in CC!"
              end
            else
              RegionCc.logger.info "REPORT! #{league.season.name}, #{league.name}, LeagueTeam: #{league_team.andand.name} Player: #{player.fullname} DBU-NR=#{player.ba_id} fehlt!!"
            end
          end
        else
          RegionCc.logger.info "REPORT! [synchronize_team_players_structure] LeagueTeam #{league_team.andand.name} in Liga #{league_team.league.andand.name} nicht in CC"
        end
      end
    end
  end

  def sync_category_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = post_cc("showCategoryList", { fedId: cc_id, branchId: branch_cc.cc_id }, opts)
      options = doc.css("select[name=\"catId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        name = option.text.strip
        status = sex = max_age = min_age = nil
        category_cc = CategoryCc.find_or_initialize_by(cc_id: cc_id)
        _, doc_cat = post_cc("showCategory", { fedId: cc_id, branchId: branch_cc.cc_id, catId: cc_id }, opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Kategorie/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
            if m = name.match(/(.*) \(\d+-\d+\)/)
              name = m[1]
            end
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td > table > tr > td")[1].text.gsub(/^ /, "").strip
          elsif /Geschlecht/.match?(tr.css("td")[0].text.strip)
            sex = CategoryCc::SEX_MAP_REVERSE[tr.css("td")[2].text.strip]
          elsif /Alter/.match?(tr.css("td")[0].text.strip)
            m = tr.css("td")[2].text.strip.match(/(\d+)\s*-\s*(\d+)/)
            min_age = m[1].to_i
            max_age = m[2].to_i
          end
        end
        category_cc.update(context: opts[:context], branch_cc_id: branch_cc.id, name: name, sex: sex, min_age: min_age,
                           max_age: max_age, status: status)
        CategoryCc.last
      end
    end
  end

  def sync_group_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = post_cc("showGroupList", { branchId: branch_cc.cc_id }, opts)
      options = doc.css("select[name=\"groupId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        name = option.text.strip
        status = ""
        display = ""
        pos_hash = {}
        group_cc = GroupCc.find_or_initialize_by(cc_id: cc_id)
        _, doc_cat = post_cc("showGroup", { branchId: branch_cc.cc_id, groupId: cc_id }, opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Name/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td")[2].text.strip
          elsif /Darstellung/.match?(tr.css("td")[0].text.strip)
            display = tr.css("td")[2].text.strip
          elsif /Runden|Gruppen/.match?(tr.css("td")[0].text.strip)
            positions = tr.css("td > table > tr")
            positions.each do |position|
              pos = position.css("td").andand[0].andand.text.andand.to_i
              val = position.css("td").andand[1].andand.text
              pos_hash[pos.to_i] = val if pos.present?
            end
          end
        end
        group_cc.update(context: opts[:context], branch_cc_id: branch_cc.id, name: name, status: status,
                        display: display, data: { positions: pos_hash }.to_json)
      end
    end
  end

  def sync_discipline_ccs(opts)
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = post_cc("createMeldelisteCheck",
                       { branchId: branch_cc.cc_id, fedId: region_cc.cc_id, disciplinId: "*", catId: "*", season: season.name, create: "" }, opts)
      options = doc.css("select[name=\"selectedDisciplinId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        @strip = option.text.strip
        name = @strip
        discipline_cc = DisciplineCc.find_or_initialize_by(cc_id: cc_id)
        discipline = Discipline.find_by_name(name.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein").gsub("5-Kegel", "5 Kegel").gsub("14/1 endlos", "14.1 endlos").gsub("15-reds", "Snooker").gsub(
                                               "Billard Kegeln", "Billard-Kegeln"
                                             ))
        discipline_cc.update(context: region.shortname.downcase, name: name, branch_cc_id: branch_cc.id,
                             discipline_id: discipline.andand.id)
      end
    end
  end

  def sync_tournament_series_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    season = Season.find_by_name(opts[:season_name])
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = post_cc("showSerienList", { fedId: cc_id, branchId: branch_cc.cc_id, season: opts[:season_name] }, opts)
      options = doc.css("select[name=\"serienId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        args = { season: season.name, branch_cc_id: branch_cc.id }
        pos_hash = {}
        tournament_series_cc = TournamentSeriesCc.find_or_initialize_by(cc_id: cc_id)

        _, doc_cat = post_cc("showSerie",
                             { fedId: region_cc.cc_id, branchId: branch_cc.cc_id, season: opts[:season_name], serienId: cc_id, show: "", referer: "/admin/einzel/serie/showSerienList.php?branchId=#{branch_cc.cc_id}&fedId=#{cc_id}&season=#{opts[:season_name]}" }, opts.merge)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Status/.match?(tr.css("td")[0].text.strip)
            args.merge!(status: tr.css("td")[2].text.strip.gsub(/^ /, "").strip)
          elsif /Turnier-Serie/.match?(tr.css("td")[0].text.strip)
            args.merge!(name: tr.css("td")[2].text.strip)
          elsif /Serienwertung/.match?(tr.css("td")[0].text.strip)
            args.merge!(series_valuation: tr.css("td")[2].text.strip.to_i)
          elsif /Turniere anzeigen/.match?(tr.css("td")[0].text.strip)
            args.merge!(no_tournaments: tr.css("td")[2].text.strip.to_i)
          elsif /Punkte-Formel/.match?(tr.css("td")[0].text.strip)
            args.merge!(point_formula: tr.css("td")[2].text.strip.match(/([^(]*)\(.*/).andand[1].andand.gsub(/ /,
                                                                                                             " ").andand.strip.to_s)
          elsif /Minimal-Punktzahl/.match?(tr.css("td")[0].text.strip)
            args.merge!(min_points: tr.css("td")[2].text.strip.to_i)
          elsif /Rundung Punktzahl/.match?(tr.css("td")[0].text.strip)
            args.merge!(point_fraction: tr.css("td")[2].text.strip.to_i)
          elsif /Verein/.match?(tr.css("td")[0].text.strip)
            if m = tr.css("td")[2].text.strip.match(/.*\((\d+)\).*/)
              club_cc_id = m[1].to_i
              args.merge!(club_id: Club.find_by_cc_id(club_cc_id))
            end
          elsif /Jackpot \(manuell\)/.match?(tr.css("td")[0].text.strip)
            if m = tr.css("td")[2].text.strip.match(/(\d+,\d+).*/)
              args.merge!(point_fraction: m[1].tr(",", ".").to_f)
            end
          elsif /Mannschaften/.match?(tr.css("td")[0].text.strip)
            zeilen = tr.css("table > tr.odd td")
            zeilen.each do |_zeile|
              pos_hash[]
            end
          end
        end
        tournament_series_cc.update(args)
      end
    end
  end

  def sync_registration_list_ccs_detail(season, branch_cc, opts)
    _, doc = post_cc("showMeldelistenList",
                     { fedId: cc_id, branchId: branch_cc.cc_id, disciplinId: "*", catId: "*", season: season.name }, opts)
    options = doc.css("select[name=\"meldelisteId\"] > option")
    options.each do |option|
      cc_id_ml = option["value"].to_i
      name = option.text.strip
      status = ""
      deadline = Date.today
      qualifying_date = Date.today
      discipline_id = nil
      category_cc_id = nil
      pos_hash = {}
      registration_list_cc = RegistrationListCc.find_or_initialize_by(cc_id: cc_id_ml)
      # if branch_cc.cc_id == 10 && season.name == "2010/2011"
      #   _, doc_cat = post_cc('deleteMeldeliste', { branchId: 10, fedId: cc_id, season: season.name, meldelisteId: cc_id_ml }, opts)
      #   next
      # end
      next if !registration_list_cc.new_record? && opts[:update_from_cc].blank?

      _, doc_cat = post_cc("showMeldeliste",
                           { fedId: cc_id, branchId: branch_cc.cc_id, disciplinId: "*", meldelisteId: cc_id_ml, catId: "*", season: season.name }, opts)
      lines = doc_cat.css("tr.tableContent > td > table > tr")
      begin
        lines.each do |tr|
          if /Meldungen/.match?(tr.css("td")[0].text.strip)
            positions = tr.css("td > table > tr")
            positions.each do |position|
              pos = position.css("td").andand[0].andand.text.andand.to_i
              val = position.css("td").andand[1].andand.text
              pos_hash[pos.to_i] = val if pos.present?
            end
          elsif /Meldeliste/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Disziplin/.match?(tr.css("td")[0].text.strip)
            d_name = tr.css("td")[2].text.strip.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein").gsub("5-Kegel", "5 Kegel").gsub("14/1 endlos", "14.1 endlos").gsub("15-reds", "Snooker").gsub(
              "Billard Kegeln", "Billard-Kegeln"
            )
            discipline_id = Discipline.find_by_name(d_name).andand.id
          elsif /Kategorie/.match?(tr.css("td")[0].text.strip)
            k_name = tr.css("td")[2].text.strip
            m = k_name.match(/(.*) \(\d+-\d+\)/)
            category_cc_id = CategoryCc.where(context: context, branch_cc_id: branch_cc.id, name: m[1]).first.andand.id
          elsif /Meldeschluss/.match?(tr.css("td")[0].text.strip)
            deadline = tr.css("td")[2].text.strip
            deadline = Date.parse(deadline) if /\d\d\.\d\d\.\d\d\d\d/.match?(deadline)
          elsif /Stichtag/.match?(tr.css("td")[0].text.strip)
            qualifying_date = tr.css("td")[2].text.strip
            if m = qualifying_date.match(/(\d\d\.\d\d\.\d\d\d\d).*/)
              qualifying_date = Date.parse(m[1])
            end
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td")[2].text.strip.gsub(/^ /, "").strip
          end
        end
        if opts[:release] && status != "Freigegeben"
          _, doc = post_cc("releaseMeldeliste",
                           { branchId: branch_cc.cc_id, fedId: branch_cc.region_cc.cc_id, season: season.name, meldelisteId: registration_list_cc.cc_id, release: "" }, opts)
        end
        registration_list_cc.update(season_id: season.id, discipline_id: discipline_id, category_cc_id: category_cc_id,
                                    context: context, branch_cc_id: branch_cc.id, name: name, status: "Freigegeben", deadline: deadline, qualifying_date: qualifying_date)
      rescue Exception
        Rails.logger.error "Error"
      end
    end
  end

  def sync_registration_list_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    season = Season.find_by_name(opts[:season_name])
    region_cc = region.region_cc
    if opts[:branch_cc_cc_id].present?
      branch_cc = BranchCc.find_by_cc_id(opts[:branch_cc_cc_id].to_i)
      sync_registration_list_ccs_detail(season, branch_cc, opts) if branch_cc.present?
    else
      region_cc.branch_ccs.each do |branch_cc|
        sync_registration_list_ccs_detail(season, branch_cc, opts)
      end
    end
  end

  def sync_tournament_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    season_name = opts[:season_name]
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      next if branch_cc.name == "Pool" || branch_cc.name == "Snooker" # TODO: remove restriction on branch

      _, doc = post_cc("showMeisterschaftenList", {
                         fedId: region_cc.cc_id,
                         branchId: branch_cc.cc_id,
                         disciplinId: "*",
                         catId: "*",
                         meisterTypeId: "*",
                         season: season.name,
                         t: 1
                       }, opts)
      if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
        RegionCc.logger.error msg
        return [[], msg]
      end
      options = doc.css("a.cc_bluelink")
      options.each do |option|
        if m = option["href"].match(/.*\?p=([^&]*)&/)
          cc_id = m[1].split("-")[6].to_i
          args = {}
          pos_hash = {}
          tournament_cc = TournamentCc[cc_id]
          next if tournament_cc.present? && !opts[:update_from_cc]

          tournament_cc = TournamentCc.find_or_initialize_by(cc_id: cc_id)
          _, doc_cat = get_cc("showMeisterschaft", { p: m[0] }, opts)
          lines = doc_cat.css("tr.tableContent > td > table > tr")
          lines.each do |tr|
            if /Meldungen/.match?(tr.css("td")[0].text.strip)
              positions = tr.css("td > table > tr")
              positions.each do |position|
                pos = position.css("td").andand[0].andand.text.andand.to_i
                val = position.css("td").andand[1].andand.text
                pos_hash[pos.to_i] = val if pos.present?
              end
            elsif tr.css("td")[0].text.strip == "Meisterschaft"
              args.merge!(name: tr.css("td")[2].text.strip)
            elsif /Kurzbezeichner/.match?(tr.css("td")[0].text.strip)
              args.merge!(shortname: tr.css("td")[2].text.strip)
            elsif /Turnier-Serie/.match?(tr.css("td")[0].text.strip)
              unless /Keine Serien-Zuordnung vorhanden/.match?(tr.css("td")[2].text.gsub(/ /, "").strip)
                ts_name = tr.css("td")[2].text.gsub(/ /, "").strip
                tournament_series_cc = TournamentSeriesCc.where(name: ts_name, branch_cc_id: branch_cc.id,
                                                                season: season.name).first
                args.merge!(tournament_series_cc_id: tournament_series_cc.id)
              end
            elsif /Disziplin/.match?(tr.css("td")[0].text.strip)
              d_name = tr.css("td")[2].text.strip.gsub("(großes Billard)", "groß").gsub("(kleines Billard)", "klein")
              args.merge!(discipline_id: Discipline.find_by_name(d_name).andand.id)
            elsif /Melde-Regel/.match?(tr.css("td")[0].text.strip)
              args.merge!(registration_rule: TournamentCc::REGISTRATION_RULES_INV[tr.css("td")[2].text.strip])
            elsif /Sortierung nach/.match?(tr.css("td")[0].text.strip)
              # args.merge!(sorting_by: tr.css("td")[2].text.strip)
            elsif /Startgeld/.match?(tr.css("td")[0].text.strip)
              args.merge!(entry_fee: tr.css("td")[2].text.strip.tr(",", ".").to_f)
            elsif /Meisterschaftstyp/.match?(tr.css("td")[0].text.strip)
              name, shortname = tr.css("td")[2].text.strip.match(/\s*(.*)\s*\((.*)\)/)[1..2]
              name = name.gsub(/ /, "").strip
              shortname = shortname.gsub(/ /, "").strip
              championship_type_cc = ChampionshipTypeCc.where(name: name, shortname: shortname,
                                                              branch_cc_id: branch_cc.id).first
              args.merge!(championship_type_cc_id: championship_type_cc.andand.id)
            elsif /Meisterschaftsgruppe/.match?(tr.css("td")[0].text.strip)
              group_cc = GroupCc.where(name: tr.css("td")[2].text.strip, branch_cc_id: branch_cc.id).first
              args.merge!(group_cc_id: group_cc.andand.id)
            elsif /Kategorie/.match?(tr.css("td")[0].text.strip)
              k_name = tr.css("td")[2].text.strip
              if m = k_name.match(/(.*) \(\d+-\d+\)/)
                args.merge!(category_cc_id: CategoryCc.where(context: opts[:context], branch_cc_id: branch_cc.id,
                                                             name: m[1]).first.andand.id)
              end
            elsif /Datum/.match?(tr.css("td")[0].text.strip)
              args[:tournament_start] = tr.css("td")[2].text.strip
              if m = args[:tournament_start].match(/(\d+\.\d+\.\d+).* \(Spielbeginn am \d+\.\d+\.\d+ um (\d+:\d+) Uhr\)/)
                args.merge!(tournament_start: DateTime.parse("#{m[1]} #{m[2]}"))
              end
            elsif /Location/.match?(tr.css("td")[0].text.strip)
              args.merge!(location_text: tr.css("td")[2].inner_html.strip)
            elsif /Status/.match?(tr.css("td")[0].text.strip)
              args.merge!(status: tr.css("td")[2].text.strip.gsub(/^ /, "").strip)
            end
          end
          if args[:name].present?
            tournament_cc.update(args.merge(cc_id: cc_id, season: season.name, branch_cc_id: branch_cc.id))
            tournament_cc.attributes
          end
        end
      rescue Exception => e
        Rails.logger.error "Errror: #{e} #{e.backtrace.join("\n")}"
      end
    end
  end

  def sync_championship_type_ccs(opts)
    region = Region.find_by_shortname(opts[:context].upcase)
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      _, doc = post_cc("showTypeList", { fedId: cc_id, branchId: branch_cc.cc_id }, opts)
      options = doc.css("select[name=\"typeId\"] > option")
      options.each do |option|
        cc_id = option["value"].to_i
        name = option.text.strip
        shortname = ""
        status = ""
        championship_type_cc = ChampionshipTypeCc.find_or_initialize_by(cc_id: cc_id)
        _, doc_cat = post_cc("showType", { fedId: cc_id, branchId: branch_cc.cc_id, typeId: cc_id }, opts)
        lines = doc_cat.css("tr.tableContent > td > table > tr")
        lines.each do |tr|
          if /Meisterschaftstyp/.match?(tr.css("td")[0].text.strip)
            name = tr.css("td")[2].text.strip
          elsif /Status/.match?(tr.css("td")[0].text.strip)
            status = tr.css("td > table > tr > td")[1].text.gsub(/^ /, "").strip
          elsif /Kurzbezeichnung/.match?(tr.css("td")[0].text.strip)
            shortname = tr.css("td")[2].text.strip
          end
        end
        championship_type_cc.update(context: opts[:context], branch_cc_id: branch_cc.id, name: name,
                                    shortname: shortname, status: status)
        ChampionshipTypeCc.last
      end
    end
  end

  def sync_game_plans(opts = {})
    Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)

    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      # get game_plan definitions
      branch = branch_cc.discipline
      _, doc = region_cc.get_cc(
        "spielberichte",
        { p: "#{branch_cc.fedId}-#{branch_cc.branchId}" }, opts
      )
      doc.text
      tables = doc.css("form > table > tr > td > table > tr > td > table > tr > td > table")
      tables.each do |table|
        next unless table.css("> tr > th")[1].andand.text == "Spielbericht"

        table.css("> tr").each_with_index do |tr, _ix|
          tds = tr.css("> td")
          next if tds.blank?

          name = tds[1].text
          link = tds[1].css("a")[0]["href"]
          cc_id = link.match(/spielbericht_anzeigen.*=\d+-\d+-(\d+)-.*$/)[1]
          game_plan_cc = GamePlanCc.find_by_cc_id(cc_id)
          game_plan_cc ||= GamePlanCc.new(name: name, cc_id: cc_id, branch_cc_id: branch_cc.id,
                                          discipline_id: branch.id)

          # read single game plan

          _, doc2 = region_cc.get_cc(
            "spielbericht_anzeigen",
            { p: "#{branch_cc.fedId}-#{branch_cc.branchId}-#{cc_id}-" },
            opts
          )
          lines = []
          tables = doc2.css("form > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table > tr > td > table")
          tables.each do |table|
            next if table.css("> tr > th")[0].andand.text == "Partie-Nr."

            try do
              table.css("> tr").each_with_index do |tr, _ix|
                tds = tr.css("> td")
                if tds.blank?
                  ths = tr.css("> th")
                  ths.text
                  lines.push(ths[1].text)
                else
                  next if tds[1].text.blank?

                  lines.push(tds[1].text)
                end
              end
              unless game_plan_cc.data["games"] == lines
                game_plan_cc.deep_merge_data!({ "games" => lines })
                game_plan_cc.save!
              end
            rescue StandardError => e
              Rails.logger.info "#{e} #{e.backtrace.join("\n")}"
            end
          end
        end
      end
    end
  end

  def sync_game_details(opts = {})
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)
    opts[:done_ids] = []
    region_cc = region.region_cc
    region_cc.branch_ccs.each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.where.not(name: opts[:exclude_season_names]).each do |season_cc|
          next unless season_cc.name == season.name

          season_cc.league_ccs.order(cc_id: :asc).each do |league_cc|
            next if branch_cc.name == "Snooker" # TODO: TEST REMOVE ME
            next if branch_cc.name == "Pool" # TODO: TEST REMOVE ME
            # next if league_cc.league.discipline_id.blank? # TODO TEST REMOVE ME
            next if opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)

            league_cc.party_ccs.joins(:party).where.not(parties: { id: opts[:done_ids] }).uniq.each do |party_cc|
              # next unless league_cc.league_id == 3512
              # next unless party_cc.match_id == 3028
              party = party_cc.party
              # next unless party.ba_id == 81118
              # Kernel.sleep(0.5)
              if party.no_show_team_id.present?
                zuNullTeam = party.no_show_team_id == party.league_team_a.id ? party.league_team_b.id : party.league_team_a.id
              end
              params = {
                "memo" => party.remarks.andand.deep_stringify_keys.andand["remarks"].to_s.encode(Encoding::ISO_8859_1),
                "protest" => party.remarks.andand.deep_stringify_keys.andand["protest"].to_s.encode(Encoding::ISO_8859_1),
                "zuNullTeamId" => (LeagueTeam[zuNullTeam] if party.no_show_team_id.present?).andand.cc_id.to_i,
                "saveBut" => "",
                "woher" => 1,
                "matchId" => party_cc.match_id,
                "errMsgNew" => "",
                "teamId" => party_cc.league_team_a_cc.cc_id,
                "firstEntry" => 1,
                "wettbewerb" => party_cc.subBranchId,
                "partienr" => party_cc.cc_id
              }
              discipline_synonyms = {
                "14/1e" => "14.1 endlos",
                "15-reds" => "Snooker",
                "Dreiband (gr)" => "Dreiband groß",
                "Dreiband (kl)" => "Dreiband klein",
                "Einband (kl)" => "Einband klein",
                "Freie Partie (kl)" => "Freie Partie klein",
                "Cadre 35/2" => "Cadre 52/2"
              }
              if params["zuNullTeamId"].to_i > 0
                params["protest"] = ":: zu Null Ergebnis.".encode(Encoding::ISO_8859_1) if params["protest"].blank?
              elsif params["protest"].present?
                if /:0/.match?(party.data[:result])
                  params["zuNullTeamId"] = party.league_team_a.league_team_cc.cc_id
                elsif /0:/.match?(party.data[:result])
                  params["zuNullTeamId"] = party.league_team_b.league_team_cc.cc_id
                end
              else
                game_lines = league_cc.game_plan_cc.data["games"]
                pg_line_ix = 0
                party.party_games.each_with_index do |pg, _ix|
                  while pg_line_ix < game_lines.count && ((game_lines[pg_line_ix] =~ /Runde/) || (pg.discipline.name != game_lines[pg_line_ix] && pg.discipline.name != discipline_synonyms[game_lines[pg_line_ix]]))
                    pg_line_ix += 1
                  end
                  sc_ = pg.data[:result][pg.data[:result].keys[0]].gsub("Bälle (x0.00):",
                                                                        "").split(":").map(&:@strip).map(&:to_i)
                  in_ = if pg.data[:result].keys[1].present?
                          pg.data[:result][pg.data[:result].keys[1]].gsub(
                            "Aufn. (x0.00):", ""
                          ).split(":").map(&:@strip).map(&:to_i)
                        else
                          []
                        end
                  br_ = if pg.data[:result].keys[2].present?
                          pg.data[:result][pg.data[:result].keys[2]].gsub("HS:",
                                                                          "").split(":").map(&:@strip).map(&:to_i)
                        else
                          []
                        end

                  # 2:0 => 1:0, 1:0
                  # 2:1 => 1:0, 0:1, 1:0
                  player_a_noshow = player_b_noshow = false
                  if pg.player_a.andand.cc_id.blank?
                    if pg.player_a.blank? || pg.player_a.lastname == "Freilos"
                      player_a_noshow = true
                    else
                      player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: pg.player_a.firstname,
                                                                                   lastname: pg.player_a.lastname).first
                      if player.present?
                        pg.update(player_a_id: player.id)
                        pg.reload
                      else
                        # TODO: THIS IS DUPLICATE CODE !!!
                        words_firstname = pg.player_a.firstname.split(/\s+/)
                        words_lastname = Array(pg.player_a.lastname)
                        player = nil
                        while words_firstname.count > 0
                          player_firstname = words_firstname.join(" ")
                          player_lastname = words_lastname.join(" ")
                          if player.blank?
                            player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: player_firstname,
                                                                                         lastname: player_lastname).first
                          end
                          break if player.present?

                          take_last_word_from_firstname = words_firstname.pop
                          words_lastname.unshift(take_last_word_from_firstname)

                        end
                        if player.present?
                          pg.update(player_a_id: player.id)
                          pg.reload
                        else
                          RegionCc.logger.info "REPORT! Spieler hat keine PASS-NR: #{pg.player_a.fullname}[#{pg.player_a.id} -  ba_id: #{pg.player_a.ba_id}, team: #{pg.party.league_team_a.name}]"
                        end
                      end
                    end
                  end
                  if pg.player_b.andand.cc_id.blank?
                    if pg.player_b.blank? || pg.player_b.lastname == "Freilos"
                      player_b_noshow = true
                    else
                      player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: pg.player_b.firstname,
                                                                                   lastname: pg.player_b.lastname).first
                      if player.present?
                        pg.update(player_b_id: player.id)
                        pg.reload
                      else
                        words_firstname = pg.player_b.firstname.split(/\s+/)
                        words_lastname = Array(pg.player_b.lastname)
                        player = nil
                        while words_firstname.count > 0
                          player_firstname = words_firstname.join(" ")
                          player_lastname = words_lastname.join(" ")
                          if player.blank?
                            player = Player.where(type: nil).where.not(cc_id: nil).where(firstname: player_firstname,
                                                                                         lastname: player_lastname).first
                          end
                          break if player.present?

                          take_last_word_from_firstname = words_firstname.pop
                          words_lastname.unshift(take_last_word_from_firstname)

                        end
                        if player.present?
                          pg.update(player_b_id: player.id)
                          pg.reload
                        else
                          RegionCc.logger.info "REPORT! Spieler hat keine PASS-NR: #{pg.player_b.fullname}[#{pg.player_b.id} -  ba_id: #{pg.player_b.ba_id}, team: #{pg.party.league_team_b.name}]"
                        end
                      end
                    end
                  end
                  add_pg = {
                    "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid1" => pg.player_a.andand.cc_id.to_i,
                    "#{party_cc.match_id}-#{pg_line_ix}-1-1-pid2" => pg.player_b.andand.cc_id.to_i
                  }
                  if branch_cc.name == "Pool" || branch_cc.name == "Karambol"
                    if player_a_noshow && player_b_noshow && pg.party.data[:result] =~ /0:0/
                      RegionCc.logger.info "REPORT keine Ergebnisse - noch nicht gespielt? wer ist Gewinner?"
                    elsif player_a_noshow && sc_[0].to_i == 0
                      if /0:/.match?(pg.party.data[:result])
                        # team a nicht angetreten
                        if party.remarks.andand.deep_stringify_keys.andand["protest"].blank?
                          if party.remarks.andand.deep_stringify_keys.andand["remarks"].blank?
                            unless params["memo"].present?
                              add_pg["memo"] =
                                ":: Mannschaft #{party.league_team_a.name} nicht angetreten".encode(Encoding::ISO_8859_1)
                            end
                            unless params["memo"].present?
                              add_pg["protest"] =
                                ":: Mannschaft #{party.league_team_b.name} gewinnt mit einem zu Null Ergebnis. [Es werden keine Spiele gespeichert.]".encode(Encoding::ISO_8859_1)
                            end
                            add_pg["zuNullTeamId"] = party.league_team_b.league_team_cc.cc_id
                          else
                            RegionCc.logger.info "manual check"
                          end
                        else
                          RegionCc.logger.info "manual check"
                        end
                      end
                      unless add_pg["zuNullTeamId"].to_i > 0
                        if sc_[1].to_i > 0
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] = sc_[1].presence
                        else
                          unless params["memo"].present?
                            add_pg["memo"] =
                              ":: Mannschaft #{party.league_team_a.name} nicht vollständig angetreten".encode(Encoding::ISO_8859_1)
                          end
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] =
                            (/14/.match?(game_lines[pg_line_ix]) ? 125 : 7)
                        end
                      end
                    elsif player_b_noshow && sc_[1].to_i == 0

                      if /:0/.match?(pg.party.data[:result])
                        # team b nicht angetreten
                        if party.remarks.andand.deep_stringify_keys.andand["protest"].blank?
                          if party.remarks.andand.deep_stringify_keys.andand["remarks"].blank?
                            unless params["memo"].present?
                              add_pg["memo"] =
                                ":: Mannschaft #{party.league_team_b.name} nicht angetreten".encode(Encoding::ISO_8859_1)
                            end
                            unless params["memo"].present?
                              add_pg["protest"] =
                                ":: Mannschaft #{party.league_team_a.name} gewinnt mit einem zu Null Ergebnis. [Es werden keine Spiele gespeichert.]".encode(Encoding::ISO_8859_1)
                            end
                            add_pg["zuNullTeamId"] = party.league_team_a.league_team_cc.cc_id
                          else
                            RegionCc.logger.info "manual check"
                          end
                        else
                          RegionCc.logger.info "manual check"
                        end
                      end
                      unless add_pg["zuNullTeamId"].to_i > 0
                        if sc_[0].to_i > 0
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] = sc_[0].presence
                        else
                          unless params["memo"].present?
                            add_pg["memo"] =
                              ":: Mannschaft #{party.league_team_b.name} nicht vollständig angetreten".encode(Encoding::ISO_8859_1)
                          end
                          add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] =
                            (/14/.match?(game_lines[pg_line_ix]) ? 125 : 7)
                        end
                      end
                    else
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc1"] = sc_[0].presence if sc_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-sc2"] = sc_[1].presence if sc_[1].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-in1"] = in_[0].presence if in_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-in2"] = in_[1].presence if in_[1].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-br1"] = br_[0].presence if br_[0].present?
                      add_pg["#{party_cc.match_id}-#{pg_line_ix}-1-br2"] = br_[1].presence if br_[1].present?
                    end
                  elsif branch_cc.name == "Snooker"
                    c1 = sc_[0]
                    c2 = sc_[1]
                    n_games = c1 + c2
                    (1..n_games).each do |ii|
                      if c1 >= c2
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1"] = 1 unless player_a_noshow
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2"] = 0
                        c1 -= 1
                      else
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc1"] = 0
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-sc2"] = 1 unless player_b_noshow
                        c2 -= 1
                      end
                      next unless ii == n_games

                      if in_[0].present? && !player_a_noshow
                        add_pg["#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br1"] =
                          in_[0].presence
                      end
                      if in_[1].present? && !player_b_noshow
                        add_pg.merge!("#{party_cc.match_id}-#{pg_line_ix}-#{ii}-br2" => in_[1].presence)
                      end
                    end
                  end
                  params.merge!(add_pg)
                  pg_line_ix += 1
                  break if pg_line_ix > game_lines.count || params["zuNullTeamId"].to_i > 0
                end
              end
              args = params.merge(referer: "/admin/bm_mw/spielberichtCheck.php?")
              if true
                _res, doc = region_cc.post_cc(
                  "spielberichtSave",
                  args,
                  opts
                )
                doc.text
              else
                RegionCc.logger.info "REPORT [sync_game_details] WOULD ENTER Game Report il League #{league_cc.attributes}  and Part #{party_cc.attributes} with 'spielberichtSave' and payload #{args}"
              end
            end
          end
        end
      end
    end
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end

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

  def sync_branches(opts = {})
    branches = []
    context = shortname.downcase
    opts.delete("armed")
    _, doc = get_cc("showClubList", {}, opts)
    selector = doc.css('select[name="branchId"]')[0]
    option_tags = selector.css("option")
    option_tags.each do |option|
      cc_id = option["value"].to_i
      name_str = option.text.strip
      match = name_str.match(/(.*)(:? \((.*)\))?/)
      branch_name = match[1]
      branch = Branch.find_by_name(branch_name)
      if branch.blank?
        msg = "No Branch with name #{branch_name} in database"
        RegionCc.logger.error "[get_branches_from_cc] #{msg}"
        raise ArgumentError, msg, caller
      else
        args = { cc_id: cc_id, region_cc_id: id, discipline_id: branch.id, context: context, name: branch_name }
        branch_cc = BranchCc.find_by_cc_id(cc_id) || BranchCc.new(args)
        branch_cc.assign_attributes(args)
        branch_cc.save
        branches.push(branch)
      end
    end
    branches
  end

  def fix_tournament_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    tournaments = Tournament
                  .where(season: season, organizer_type: "Region", organizer_id: region.id)
                  .where.not(tournaments: { ba_id: opts[:exclude_tournament_ba_ids] }).to_a
    tournaments.each do |tournament|
      next if tournament.discipline.root.name == "Pool" || tournament.discipline.root.name == "Snooker"

      tournament_cc = TournamentCc.find_by(tournament_id: tournament.id)
      if tournament_cc.present?
        branch_cc = tournament.discipline.root.branch_cc
        registration_list_ccs = RegistrationListCc.where(
          name: tournament.title,
          context: region.shortname.downcase,
          discipline_id: tournament.discipline_id,
          season_id: tournament.season_id
        )
        registration_list_cc = nil
        if registration_list_ccs.count == 1
          registration_list_cc = registration_list_ccs.first
        elsif registration_list_ccs.count > 1
          Rails.logger.info "Error: Ambiguity Problem"
        else
          Rails.logger.info "Error: No RegistrationList for Tournament"
        end
        type_found = nil
        begin
          TournamentCc::TYPE_MAP_REV[branch_cc.cc_id].keys.each do |type_name|
            if /#{type_name}/.match?(tournament.title)
              type_found = TournamentCc::TYPE_MAP_REV[branch_cc.cc_id][type_name]
              break
            end
          end
        rescue Exception => e
          Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
          return
        end
        # args = {
        #   branchId: 6,
        # fedId: 20,
        # disciplinId: "*",
        # catId: "*",
        # meisterTypeId: "*",
        # season: 2014/2015
        # }
        #
        args = {
          fedId: cc_id,
          branchId: branch_cc.cc_id,
          disciplinId: "*",
          season: opts[:season_name],
          catId: "*",
          meisterTypeId: "*",
          meisterschaftsId: tournament_cc.cc_id,
          ebut: ""
        }
        _, doc = post_cc("editMeisterschaftCheck", args, opts)
        args = {
          fedId: cc_id,
          branchId: branch_cc.cc_id,
          disciplinId: tournament.discipline.discipline_cc.cc_id,
          season: opts[:season_name],
          catId: "*",
          meisterschaftsId: tournament_cc.cc_id,
          firstEntry: 1,
          meisterName: tournament.title,
          meisterShortName: tournament.shortname.presence || tournament.title,
          meldeListId: registration_list_cc.cc_id,
          mr: 1,
          meisterTypeId: type_found.to_s,
          groupId: 10, # NBV History is good for all
          playDate: tournament.date.strftime("%Y-%m-%d"),
          playDateTo: tournament.end_date.andand.strftime("%Y-%m-%d"),
          startTime: tournament.date.strftime("%H:%M"),
          quote: "0",
          sg: "0,00",
          maxtn: "0",
          countryId: "free",
          pubName: doc.css('input[name="pubName"]')[0].attributes["value"].to_s,
          pubStreet: doc.css('input[name="pubStreet"]')[0].attributes["value"].to_s,
          pubZipcode: doc.css('input[name="pubZipcode"]')[0].attributes["value"].to_s,
          pubCity: doc.css('input[name="pubCity"]')[0].attributes["value"].to_s,
          pubPhone: doc.css('input[name="pubPhone"]')[0].attributes["value"].to_s,
          besch: "",
          attachment4: "",
          attachment5: "",
          attachment1: "",
          attachment2: "",
          attachment3: "",
          referer: "/admin/einzel/meisterschaft/editMeisterschaftCheck.php?",
          save: ""
        }
        _, doc = post_cc("editMeisterschaftSave", args, opts)
        doc
      else
        Rails.logger.error "Error: Problem in tournament_structure - Tournament[#{tournament.id}]"
      end
    end
  end

  def synchronize_tournament_structure(opts = {})
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

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

  def sync_competitions(opts = {})
    competitions = []
    context = opts[:context]
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      _, doc = post_cc("showLeagueList", { fedId: cc_id, branchId: branch_cc.cc_id }, opts)
      selector = doc.css('select[name="subBranchId"]')[0]
      option_tags = selector.css("option")
      option_tags.each do |option|
        cc_id = option["value"].to_i
        name_str = option.text.strip
        match = name_str.match(/(.*)(:? \((.*)\))?/)
        name = match[1]
        carambus_name = name == "Mannschaft" ? "#{name} #{branch_cc.name}" : "Mannschaft #{name}"
        carambus_name = carambus_name.gsub("Großes Billard", "Karambol großes Billard")
        carambus_name = carambus_name.gsub("Kleines Billard", "Karambol kleines Billard")
        competition = Competition.find_by_name(carambus_name)
        if competition.blank?
          msg = "No Competition with name #{carambus_name} in database"
          RegionCc.logger.error "[sync_competitions] #{msg}"
          raise ArgumentError, msg, caller
        else
          args = { cc_id: cc_id, branch_cc_id: branch_cc.id, discipline_id: competition.id, context: context,
                   name: name }
          competition_cc = CompetitionCc.where(cc_id: cc_id,
                                               branch_cc_id: branch_cc.id).first || CompetitionCc.new(args)
          competition_cc.assign_attributes(args)
          competition_cc.save
          competitions.push(competition)
        end
      end
    end

    competitions
  end

  def sync_seasons_in_competitions(opts)
    context = shortname.downcase
    season = Season.find_by_name(opts[:season_name])
    raise ArgumentError, "unknown season name #{opts[:season_name]}", caller if season.blank?

    competition_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        _, doc = post_cc(
          "showLeagueList",
          { fedId: cc_id,
            branchId: branch_cc.cc_id,
            subBranchId: competition_cc.cc_id },
          opts
        )
        selector = doc.css('select[name="seasonId"]')[0]
        option_tags = selector.css("option")
        option_tags.each do |option|
          cc_id = option["value"].to_i
          name_str = option.text.strip
          match = name_str.match(%r{\s*(.*/.*)\s*})
          s_name = match[1]
          next unless s_name == opts[:season_name]

          args = { cc_id: cc_id, context: context, name: s_name, season_id: season.id,
                   competition_cc_id: competition_cc.id }
          season_cc = SeasonCc.find_by_cc_id_and_competition_cc_id_and_context(cc_id, competition_cc.id,
                                                                               context) || SeasonCc.new(args)
          season_cc.assign_attributes(args)
          season_cc.save
          competition_ccs.push(competition_cc)
          break
        end
      end
    end

    competition_ccs
  end

  def sync_leagues(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    season = Season.find_by_name(season_name)
    region = Region.find_by_shortname(context.upcase)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    dbu_region_id = Region.find_by_shortname("DBU").id

    league_map = [] # league_cc.cc_id => league
    # for all branches
    leagues = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.where.not(name: opts[:exclude_season_names]).each do |season_cc|
          next unless season_cc.name == season_name
          next if branch_cc.name == "Pool" || branch_cc.name == "Snooker"

          # Get List of Leagues in CC
          _res, doc = post_cc(
            "showLeagueList",
            { fedId: cc_id,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              seasonId: season_cc.cc_id },
            opts
          )
          if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
            RegionCc.logger.error msg
            return [[], msg]
          end
          selector = doc.css('select[name="leagueId"]')[0]
          next unless selector.present?

          option_tags = selector.css("option")
          option_tags.each do |option|
            cc_id = option["value"].to_i
            name_str = option.text.strip
            league_cc = nil
            league_ccs = LeagueCc.where(cc_id: cc_id)
            if league_ccs.count == 1
              league_cc = league_ccs.first
            elsif league_ccs.count > 1
              msg = "REPORT! ERROR cc_id #{cc_id} not uniq"
              RegionCc.logger.info msg
              raise ArgumentError, msg
            end
            league = League.find_by_cc_id(cc_id)
            unless league.present?
              name_str_match = name_str.gsub(" - ", " ").gsub(/(\d+). /,
                                                              '\1.').match(%r{(.*)( (?:A|B|Staffel A|Staffel B|Nord|Süd|Nord/Ost))$})
              if name_str_match
                l_name = name_str_match[1].strip
                s_name = name_str_match[2].strip.tr("/", "-")
                s_name = "Staffel #{s_name}" if /A|B/.match?(s_name)
              else
                l_name = name_str
                s_name = nil
              end
              if context == "nbv"
                l_name = l_name == "Regionalliga Pool" ? "Regionalliga" : l_name
              end
              league = nil
              League.where(season: season, name: [l_name, l_name.gsub("2er Teams", "2er-Teams").to_s, l_name.gsub("3er Team", "3'er Team").to_s, l_name.gsub("2er", "2'er").to_s, "#{l_name} #{branch_cc.discipline.name}", "#{l_name} Ligen #{branch_cc.discipline.name}"], staffel_text: s_name, organizer_type: "Region",
                           organizer_id: [region.id, dbu_region_id]).each do |l|
                if l.branch == branch_cc.discipline
                  league = l
                  break
                end
              end
            end
            if league.present?
              next if opts[:exclude_league_ba_ids].include?(league.ba_id)

              if league_cc.blank?
                league_cc = LeagueCc.create(cc_id: cc_id, name: "#{league.name}#{if league.staffel_text.present?
                                                                                   " #{league.staffel_text}"
                                                                                 end}", season_cc_id: season_cc.id, league_id: league.id, context: league.organizer.shortname.downcase, shortname: "#{league.name.gsub("Kreis", "Kreis ").gsub("lig", " lig")}#{" #{league.staffel_text}"}".split(" ").map do |w|
                                                                                                                                                                                                     w[0].upcase
                                                                                                                                                                                                   end.join(""))
              end
              if league_cc.present?
                league_cc.sync_single_league(opts)
                league.reload.assign_attributes(cc_id: cc_id)
                league.save
                league_map[league_cc.cc_id] = league
                leagues.push(league)
              else
                msg = "REPORT! ERROR no LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
                RegionCc.logger.info msg
                Rails.logger.info msg
              end
            else
              msg = "REPORT! ERROR no League for LeagueCc #{name_str} #{season_cc.name} branch: #{branch_cc.name}(#{branch_cc.cc_id}) competition: #{competition_cc.name}(#{competition_cc.cc_id})"
              RegionCc.logger.info msg
              Rails.logger.info msg
            end
          end
        end
      end
    end

    [leagues, nil]
  rescue StandardError => e
    [[], e.to_s]
  end

  def sync_tournaments(opts = {})
    region = Region.find_by_shortname(opts[:context].upcase)
    season_name = opts[:season_name]
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    tournaments = []
    region.region_cc.branch_ccs.each do |branch_cc|
      next if branch_cc.name == "Pool" || branch_cc.name == "Snooker" # TODO: remove restriction on branch

      # Get List of Tournaments in CC
      _, doc = post_cc("showMeisterschaftenList", {
                         fedId: region.cc_id,
                         branchId: branch_cc.cc_id,
                         disciplinId: "*",
                         catId: "*",
                         meisterTypeId: "*",
                         season: season.name,
                         t: 1
                       }, opts)
      if (msg = doc.css('input[name="errMsg"]')[0].andand["value"]).present?
        RegionCc.logger.error msg
        return [[], msg]
      end
      options = doc.css("a.cc_bluelink")
      options.each do |option|
        next unless m = option["href"].match(/.*\?p=([^&]*)&/)

        cc_id = m[1].split("-")[6].to_i
        tournament_cc = TournamentCc.find_by(cc_id: cc_id)
        if tournament_cc.present?
          tournament = tournament_cc.tournament
          unless tournament.present?
            tournaments_tmp = Tournament.where(
              title: tournament_cc.name,
              season_id: season.id,
              discipline_id: tournament_cc.discipline_id
            )
            if tournaments_tmp.count != 1
              RegionCc.logger.error "Error: no unique matching Tournament for TournamentCc(#{cc_id})"
            else
              tournament = tournaments_tmp[0]
              tournament_cc.update(tournament_id: tournament.id)
            end
          end
          tournaments.push(tournament) if tournament.present?
        else
          RegionCc.logger.error "Error: TournamentCc[] not found - run synchronize_tournament_ccs first"
        end
      end
    end

    [tournaments, nil]
  rescue StandardError => e
    [[], e.to_s]
  end

  def sync_league_teams_new(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    Region.find_by_shortname("portal").id

    league_teams = []
    league_team_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      next unless branch_cc.name == "Karambol"

      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next if opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)
            next unless season_cc.name == season_name

            # get club list
            _, doc_club = post_cc(
              "showClubList",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                sportDistrictId: "*",
                statusId: 1 },
              opts
            )
            selector = doc_club.css('select[name="clubId"]')[0]
            options_tags = selector.css("option")
            options_tags.each do |option|
              clubstr = option.text.match(/(.*) \(\d+\)/).andand[1].strip
              club_cc_id = option["value"].to_i
              club = Club.find_by_cc_id(club_cc_id)
              unless club.present?
                club = Club.find_by_shortname(clubstr)
                club.update(cc_id: club_cc_id) if club.present?
              end
              if club.present?

                _, doc_teams = post_cc(
                  "showAnnounceList",
                  {
                    fedId: league_cc.fedId,
                    branchId: league_cc.branchId,
                    subBranchId: league_cc.subBranchId,
                    sportDistrictId: "*",
                    clubId: club_cc_id,
                    originalBranchId: league_cc.branchId,
                    seasonId: season_cc.cc_id
                  },
                  opts
                )
                selector_team = doc_teams.css('select[name="teamId"]')[0]
                if selector_team.present?
                  options_tags_team = selector_team.css("option")
                  options_tags_team.each do |option_team|
                    team_cc_id = option_team["value"].to_i
                    name_str = option_team.text.match(/(\d+) \((.*)\)/)
                    if name_str.present?
                      league_name = name_str[2].strip
                      next unless league_name == league_cc.name

                      team_seqno = name_str[1].to_i
                      name_str = "#{club.shortname} #{team_seqno}"
                      name_str = name_str.split(" ").join(" ")
                      name_str_cc = name_str
                      bgh_map = {
                        "BG Hamburg 2" => "BG Hamburg",
                        "BG Hamburg 3" => "BG Hamburg 2",
                        "BG Hamburg 4" => "BG Hamburg 3"
                      }
                      name_str = bgh_map[name_str] if league_cc.name =~ /2er Team/ && name_str =~ /BG Hamburg [234]/
                      mm3btb_map = {
                        "2014/2015" => {
                          "BV Kiel 1" => "BV Kiel",
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 2" => "BC Wedel",
                          "BC Wedel 3" => "BC Wedel 2"
                        },
                        "2015/2016" => {
                          "BV Kiel 2" => "BV Kiel",
                          "BC Wedel 3" => "BC Wedel"
                        },
                        "2016/2017" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 3" => "BC Wedel",
                          "BC Wedel 4" => "BC Wedel 2"
                        },
                        "2017/2018" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BC Wedel 3" => "BC Wedel"
                        },
                        "2018/2019" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BG Hamburg 3" => "BG Hamburg 2",
                          "BC Wedel 3" => "BC Wedel"
                        }
                      }
                      if league_cc.name =~ /NDMM Dreiband TB/ && mm3btb_map[season_cc.name].andand[name_str].present?
                        name_str = mm3btb_map[season_cc.name][name_str]
                      end
                      mm3bmb_map = {
                        "2015/2016" => {
                          "BG Hamburg 2" => "BG Hamburg",
                          "BG Hamburg 3" => "BG Hamburg 2",
                          "BC Wedel 3" => "BC Wedel",
                          "BC Wedel 4" => "BC Wedel 2"
                        },
                        "2016/2017" => {
                          "BC Bergedorf 1" => "BC Bergedorf",
                          "BC Wedel 3" => "BC Wedel"
                        },

                        "2018/2019" => {
                          "BC Wedel 3" => "BC Wedel",
                          "BG Hamburg 4" => "BG Hamburg"
                        }
                      }
                      if league_cc.name =~ /NDMM Dreiband MB/ && mm3bmb_map[season_cc.name].andand[name_str].present?
                        name_str = mm3bmb_map[season_cc.name][name_str]
                      end
                      if club.present?
                        league_team = LeagueTeam.joins(:league).joins(:league_team_cc).where(league_team_ccs: { cc_id: team_cc_id }).where(leagues: { id: league_cc.league_id }).first
                        league_team ||= LeagueTeam
                                        .joins(:league)
                                        .joins(club: :region)
                                        .where(regions: { id: region.id })
                                        .where(name: name_str, # shortname? TODO
                                               league_id: league_cc.league.id,
                                               club_id: club.id).first
                        league_team ||= LeagueTeam
                                        .joins(:league)
                                        .joins(club: :region)
                                        .where(regions: { id: region.id })
                                        .where(name: club.shortname, # shortname? TODO
                                               league_id: league_cc.league.id,
                                               club_id: club.id).first
                      else
                        RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{
                          name: team_club_str, cc_id: club_cc_id, region: region.shortname
                        }.inspect}"
                      end
                      if league_team.present?
                        args = { cc_id: team_cc_id, name: name_str_cc, league_cc_id: league_cc.id,
                                 league_team_id: league_team.id }
                        league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(team_cc_id,
                                                                                     league_cc.id) || LeagueTeamCc.new(args)
                        league_team_cc.assign_attributes(args)
                        league_team_cc.save!
                        league_teams.push(league_team) unless league_teams.include?(league_team)
                        league_team_ccs.push(league_team_cc) unless league_team_ccs.include?(league_team_cc)
                      else
                        RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft #{club.andand.shortname} in Liga #{league_cc.attributes} entspricht keinem BA LigaTeam: CC: #{{
                          name: name_str, cc_id: team_cc_id, league_id: league_cc.league.id, club_id: club.andand.id
                        }.inspect}"
                      end
                    else
                      RegionCc.logger.info "REPORT CANNOT PARSE TEAM INFO #{name_str} with cc_id: #{team_cc_id}"
                    end
                  end
                end
              else
                RegionCc.logger.info "REPORT UNKNOWN CLUB #{clubstr} with cc_id: #{club_cc_id}"
              end
            end
          end
        end
      end
    end

    [league_teams, league_team_ccs]
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end

  def sync_league_teams(opts = {})
    context = opts[:context]
    season_name = opts[:season_name]
    region = Region.find_by_shortname(context.upcase)
    season = Season.find_by_name(season_name)
    raise ArgumentError, "unknown season name #{season_name}", caller if season.blank?

    Region.find_by_shortname("DBU").id

    league_teams = []
    league_team_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      next unless branch_cc.name == "Karambol"

      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next if opts[:exclude_league_ba_ids].include?(league_cc.league.ba_id)
            next unless season_cc.name == season_name

            _, doc = post_cc(
              "admin_report_showLeague",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              opts
            )
            league_cc.league.league_teams.joins(club: :region).where(regions: { id: region.id })
            league_teams_doc_cc = doc.css('table[name="teams"] tr.odd')
            next unless league_teams_doc_cc.present?

            league_teams_doc_cc.each do |league_team_doc_cc|
              tds = league_team_doc_cc.css("td")
              if tds.count == 2
                cc_id = tds[1].text.to_i
                name_str = tds[0].text.strip
              else
                # TODO: Ansicht mit SpielPlan
                link = tds[1].css("a")[0]["href"]
                cc_id = link.match(/.*p=(\d+)/).andand[1]
                name_str = tds[1].text.strip
              end
              name_str = name_str.split(" ").join(" ")
              name_str_cc = name_str
              bgh_map = {
                "BG Hamburg 2" => "BG Hamburg",
                "BG Hamburg 3" => "BG Hamburg 2",
                "BG Hamburg 4" => "BG Hamburg 3"
              }
              name_str = bgh_map[name_str] if league_cc.name =~ /2er Team/ && name_str =~ /BG Hamburg [234]/
              mm3btb_map = {
                "2014/2015" => {
                  "BV Kiel 1" => "BV Kiel",
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 2" => "BC Wedel",
                  "BC Wedel 3" => "BC Wedel 2"
                },
                "2015/2016" => {
                  "BV Kiel 2" => "BV Kiel",
                  "BC Wedel 3" => "BC Wedel"
                },
                "2016/2017" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 3" => "BC Wedel",
                  "BC Wedel 4" => "BC Wedel 2"
                },
                "2017/2018" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BC Wedel 3" => "BC Wedel"
                },
                "2018/2019" => {
                  "BG Hamburg 2" => "BG Hamburg",
                  "BG Hamburg 3" => "BG Hamburg 2",
                  "BC Wedel 3" => "BC Wedel"
                }
              }
              if league_cc.name =~ /NDMM Dreiband TB/ && mm3btb_map[season_cc.name].andand[name_str].present?
                name_str = mm3btb_map[season_cc.name][name_str]
              end

              team_club_str = name_str

              if /.*[ [[:space:]]]+\d+$/.match?(name_str)
                team_club_str = (m = name_str.match(/(.*[^ [[:space:]]])[ [[:space:]]]*(\d+)$/))[1]
                m[2]
                team_club_str = team_club_str.tr("`", "'")
              end
              club = Club.where(region: region, shortname: team_club_str).first
              if club.present?
                league_team = LeagueTeam.joins(:league).joins(:league_team_cc).where(league_team_ccs: { cc_id: cc_id }).where(leagues: { id: league_cc.league_id }).first
                league_team ||= LeagueTeam
                                .joins(:league)
                                .joins(club: :region)
                                .where(regions: { id: region.id })
                                .where(name: name_str, # shortname? TODO
                                       league_id: league_cc.league.id,
                                       club_id: club.id).first
                league_team ||= LeagueTeam
                                .joins(:league)
                                .joins(club: :region)
                                .where(regions: { id: region.id })
                                .where(name: team_club_str, # shortname? TODO
                                       league_id: league_cc.league.id,
                                       club_id: club.id).first
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name des Clubs entspricht keiner BA Liga: CC: #{{
                  name: team_club_str, cc_id: cc_id, region: region.shortname
                }.inspect}"
              end
              if league_team.present?
                args = { cc_id: cc_id, name: name_str_cc, league_cc_id: league_cc.id, league_team_id: league_team.id }
                league_team_cc = LeagueTeamCc.find_by_cc_id_and_league_cc_id(cc_id,
                                                                             league_cc.id) || LeagueTeamCc.new(args)
                league_team_cc.assign_attributes(args)
                league_team_cc.save!
                league_teams.push(league_team) unless league_teams.include?(league_team)
                league_team_ccs.push(league_team_cc) unless league_team_ccs.include?(league_team_cc)
              else
                RegionCc.logger.warn "REPORT! [sync_league_teams] Name der Liga Mannschaft #{team_club_str} in Liga #{league_cc.attributes} entspricht keinem BA LigaTeam: CC: #{{
                  name: name_str, cc_id: cc_id, league_id: league_cc.league.id, club_id: club.andand.id
                }.inspect}"
              end
            end
          end
        end
      end
    end

    [league_teams, league_team_ccs]
  rescue StandardError => e
    RegionCc.logger.error "ERROR #{e} \n#{e.backtrace.join("\n")}"
  end

  def sync_league_plan(opts = {})
    season = Season.find_by_name(opts[:season_name])
    region = Region.find_by_shortname(opts[:context].upcase)
    leagues = League.joins(league_teams: :club).where(season: season, organizer_type: "Region", organizer_id: region.id).where(
      "clubs.region_id = ?", region.id
    ).where.not(leagues: { ba_id: opts[:exclude_league_ba_ids] }).uniq
    leagues_done = []
    errMsg = nil
    leagues.each do |league|
      next if opts[:exclude_league_ba_ids].include?(league.ba_id)

      league_cc = league.league_cc
      parties = league.parties
      # read spielplan
      #
      if league_cc.present?
        party_ccs = league_cc.party_ccs
        # Abgleich:
        # parties.map{|p| [p.day_seqno, p.league_team_a.name, p.league_team_b.name].join(";")}
        # party_ccs.map{|p| [p.day_seqno, p.league_team_a_cc.andand.name, p.league_team_b_cc.andand.name].join(";")}
        _, doc3 = post_cc(
          "massChangingCheck",
          { fedId: league_cc.fedId,
            leagueId: league_cc.leagueId,
            branchId: league_cc.branchId,
            subBranchId: league_cc.subBranchId,
            seasonId: league_cc.seasonId,
            staffelId: "" },
          opts
        )
        if (msg = doc3.css('input[name="errMsg"]')[0].andand["value"]).present?
          RegionCc.logger.error msg
          return [leagues_done, msg]
        end
        party_match_id = nil
        party_done_ids = []
        tables = doc3.css("form > table > tr > td > table > tr > td > table > tr > td > table") # TODO: why is an Array returned???
        tables.each do |table|
          next unless table.css("> tr > th")[0].andand.text == "Spieltag"

          table.css("> tr").each_with_index do |tr, _ix|
            tds = tr.css("> td")
            next if tds.blank?

            party_match_id = tds[0].css("> input")[0]["name"].match(/spieltagNr(\d+)$/)[1].to_i
            selectors = tds.css("> select")
            party_day_seqno = tds.css("> input")[0]["value"].to_i
            party_group = tds.css("> input")[1]["value"]
            party_cc_id = tds.css("> input")[2]["value"].to_i
            party_round = tds.css("> input")[3]["value"]
            party_team_a_cc_id = selectors[0].css("option[selected=selected]")[0]["value"].to_i
            party_team_b_cc_id = selectors[1].css("option[selected=selected]")[0]["value"].to_i
            # party_date = Date.parse(tds.css("input")[4]["value"])
            party_active_cell = tds.css("> input")[5]
            party_active = nil
            party_active ||= party_active_cell["value"].presence.to_i
            party_res_a = tds.css("> input")[6]["value"]
            party_res_b = tds.css("> input")[7]["value"]
            party_team_host_cc_id = selectors[2].css("option[selected=selected]")[0]["value"].to_i
            party_time = DateTime.parse("#{tds.css("> input")[4]["value"]} #{if /:/.match?(tds.css("> input")[8]["value"])
                                                                               tds.css("> input")[8]["value"]
                                                                             end}")
            party_register = Date.parse(tds.css("> input")[9]["value"])

            party = parties.joins('INNER JOIN "league_teams" as "league_team_a" on "league_team_a"."id" = "parties"."league_team_a_id"')
                           .joins('INNER JOIN "league_teams" as "league_team_b" on "league_team_b"."id" = "parties"."league_team_b_id"')
                           .joins('INNER JOIN "league_team_ccs" as "league_team_cc_a" on "league_team_cc_a"."league_team_id" = "league_team_a"."id"')
                           .joins('INNER JOIN "league_team_ccs" as "league_team_cc_b" on "league_team_cc_b"."league_team_id" = "league_team_b"."id"')
                           .where("league_team_cc_a.cc_id = ?", party_team_a_cc_id)
                           .where("league_team_cc_b.cc_id = ?", party_team_b_cc_id)
                           .where.not(parties: { id: party_done_ids }).first
            # where(day_seqno: party_day_seqno).first
            args = { cc_id: party_cc_id,
                     group: party_group,
                     round: party_round,
                     time: party_time,
                     match_id: party_match_id,
                     register_at: party_register,
                     status: party_active,
                     league_cc_id: league_cc.id,
                     party_id: party.andand.id,
                     league_team_a_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_a_cc_id }).first.andand.id,
                     league_team_b_cc_id: league_cc.league_team_ccs.where(league_team_ccs: { cc_id: party_team_b_cc_id }).first.andand.id,
                     league_team_host_cc_id: league_cc.league_team_ccs.joins(:party_host_ccs).where(league_team_ccs: { cc_id: party_team_host_cc_id }).first.andand.id,
                     day_seqno: party_day_seqno,
                     data: { result: "#{party_res_a}:#{party_res_b}" } }
            if party.present?
              party_cc = party_ccs.where(cc_id: party_cc_id).first || PartyCc.new(args)
              party_cc.assign_attributes(args)
              party_cc.save
              party_done_ids.push(party.id)
              #
              # _, doc = post_cc(
              #   "massChangingCheckAuth",
              #   { teamCounter: 10,
              #   fedId: 20,
              #   leagueId: 36,
              #   branchId: 6,
              #   subBranchId: 1,
              #   seasonId: 8,
              #   editAll: "",
              #   matchId: 759}, opts)
              # doc.text
              # #https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/report/massChangingCheckAuth.php?
              # _, doc = post_cc(
              #   'spielberichtCheck',
              #   {a: 715,
              #   b: 2,
              #   c: 111,
              #   referer: "/admin/report/massChangingCheckAuth.php?"}, opts
              # )
              # doc.text
              #
              # #https://e12112e2454d41f1824088919da39bc0.club-cloud.de/admin/bm_mw/spielberichtCheck.php?a=759&b=2&c=210&
              # _, doc = get_cc(
              #   'spielberichtCheck',
              #  { a: 715,
              #   b: 2,
              #   c: 111 }, opts
              # )
              # doc.text
              leagues_done.push(league) unless leagues_done.include?(league)
            else
              msg = "REPORT ERROR party with cc_id: #{args[:cc_id]}, host: #{LeagueTeamCc[args[:league_team_host_cc_id]].andand.name}, day_seqno: #{args[:day_seqno]} - arguments #{args.inspect} not in database"
              RegionCc.logger.info msg
              Rails.logger.info msg
            end
          end
        end
      else
        RegionCc.logger.info "REPORT [sync_league_plan] Liga nicht in CC: #{league.attributes}"
      end
    end
    [leagues_done, errMsg]
  end

  def sync_clubs(opts = {})
    context ||= "nbv"
    region = Region.find_by_shortname(context.upcase)
    done_clubs = []
    done_club_cc_ids = []
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        %i[active passive].each do |status|
          _, doc = post_cc(
            "showClubList",
            { sortKey: "NAME",
              fedId: branch_cc.fedId,
              branchId: branch_cc.cc_id,
              subBranchId: competition_cc.cc_id,
              sportDistrictId: "*",
              statusId: STATUS_MAP[status] },
            opts
          )
          clubs = doc.css('select[name="clubId"] option')
          clubs.each do |club|
            cc_id = club["value"].to_i
            next if done_club_cc_ids.include?(cc_id)

            name_str = club.text.strip
            shortname = name_str.match(/\s*([^(]*)\s*(?:\(.*)?/).andand[1].strip
            c = Club.find_by_cc_id(cc_id)
            if c.present?
              if c.shortname != shortname
                RegionCc.logger.warn "REPORT! [sync_clubs] name mismatch found - CC: '#{shortname}' BA: #{c.shortname}"
              end
              c.assign_attributes(cc_id: cc_id, status: status)
              c.save!
              done_club_cc_ids.push(cc_id)
              done_clubs.push(c)
            else
              c = Club.where(shortname: shortname, region_id: region.id).first
              unless c.present?
                RegionCc.logger.warn "REPORT! [sync_clubs] no club with name '#{shortname}' found in region #{context}"
              end
            end
          end
        end
      end
    end
    done_clubs
  end

  def sync_parties(opts)
    parties = []
    party_ccs = []
    # for all branches
    BranchCc.where(context: context).each do |branch_cc|
      branch_cc.competition_ccs.each do |competition_cc|
        competition_cc.season_ccs.each do |season_cc|
          season_cc.league_ccs.order(:cc_id).each do |league_cc|
            next unless season_cc.name == opts[:season_name]
            next unless league_cc.id == 177

            _, doc = post_cc(
              "admin_report_showLeague",
              { fedId: league_cc.fedId,
                branchId: league_cc.branchId,
                subBranchId: league_cc.subBranchId,
                seasonId: league_cc.seasonId,
                leagueId: league_cc.cc_id },
              opts
            )
            league = league_cc.league
            doc.css("table > tr > td > table > tr > td > table").each do |table|
              if table.css("> tr > th").andand[1].andand.text == "Spieltag"
                table.css("tr").each do |line|
                  tds = line.css("> td")
                  next if tds.blank?

                  text_arr = tds.map(&:text)
                  day_seqno = text_arr[1].to_i
                  cc_id = text_arr[2].to_i
                  team_a_str = text_arr[3].split(" ").join(" ")
                  team_a_cc = league_cc.league_team_ccs.where(name: team_a_str).first
                  raise RuntimeError, "Team #{team_a_str} not found", caller unless team_a_cc.present?

                  team_b_str = text_arr[4].split(" ").join(" ")
                  team_b_cc = league_cc.league_team_ccs.where(name: team_b_str).first
                  raise RuntimeError, "Team #{team_b_str} not found", caller unless team_b_cc.present?

                  date_str = text_arr[5]
                  text_arr[6]
                  text_arr[7]
                  host_str = text_arr[8]
                  host_cc = league_cc.league_team_ccs.where(name: host_str).first
                  raise RuntimeError, "Team #{host_str} not found", caller unless team_b_cc.present?

                  time_str = text_arr[9]
                  DateTime.parse("#{date_str} #{time_str}")
                  reg_date_str = text_arr[10]
                  Date.parse(reg_date_str)
                  party = league.parties.where(day_seqno: day_seqno, league_team_a: team_a_cc.league_team,
                                               league_team_b: team_b_cc.league_team).first
                  unless team_b_cc.present?
                    raise RuntimeError,
                          "Party #{{ day_seqno: day_seqno, team_a_cc_name: team_a_cc.name, team_b_cc_name: team_b_cc.name }} not found", caller
                  end

                  party.assign_attributes(cc_id: cc_id)
                  party.save!
                  args = { cc_id: cc_id,
                           league_cc_id: league_cc.id,
                           party_id: party.id,
                           league_team_a_cc: team_a_cc,
                           league_team_b_cc: team_b_cc,
                           league_team_host_cc: host_cc }
                  party_cc = PartyCc.find_by_cc_id_and_league_cc_id(cc_id, league_cc.id)
                  party_cc = PartyCc.new(args) if party_cc.blank?
                  party_cc.assign_attributes(args)
                  party_cc.save!
                  party_ccs.push(party_cc)
                  parties.push(party)
                end
              elsif doc.css("table > tr > td > table > tr.tableContent > td > table > tr > td > input").present?
                if league.organizer_id == region.id && league.organizer_type == "Region"
                  RegionCc.logger.info "REPORT! Keine Spieltag gepflegt für Liga #{league.name}"
                end
              end
            end
          end
        end
      end
    end
    [parties, party_ccs]
  end

  def sync_party_games(parties_todo_ids, opts = {})
    parties_todo_ids.each do |id|
      party = Party[id]
      region = party.league.organizer
      region_cc = region.region_cc
      party_cc = party.party_cc
      party_cc.attributes
      _res, doc = region_cc.post_cc(
        "spielberichtCheck",
        { errMsgNew: "",
          fedId: 20,
          branchId: 6,
          subBranchId: 1,
          wettbewerb: 1,
          leagueId: 34,
          seasonId: 8,
          teamId: 185,
          matchId: 571,
          saison: 2010 / 2011,
          partienr: 4003,
          woher: 1,
          woher2: 1,
          editBut: "" },
        opts
        # get Spielbericht
        # _res, doc = region_cc.post_cc(
        #   "spielbericht",
        #   { errMsgNew: "",
        #   matchId: party_cc.party_game_ccs.first.cc_id,
        #   teamId: 189
        #   woher: 1
        #   firstEntry: 1
        #   #
        #   # sortKey: "NAME",
        #   # branchid: party_cc.branchId,
        #   # woher: 1,
        #   # wettbewerb: party_cc.subBranchId,
        #   # sportkreis: "*",
        #   # saison: season_name,
        #   # partienr: party_cc.cc_id,
        #   # seekBut: ""}, opts
      )
      err_msg = doc.present && doc.css('input[name="errMsg"]')[0].andand["value"]
      raise ArgumentError, err_msg if err_msg.present? || doc.blank?
    end
  end

  def sync_team_players(league_team, opts = {})
    league_team_player_done = []
    league_team_cc = league_team.league_team_cc
    if league_team.league_team_cc.present?
      _, doc = get_cc(
        "showLeague_show_teamplayer",
        { p: league_team_cc.p,
          referer: "/admin/report/showLeague_show_teamplayer.php?p=#{league_team_cc.p}&" },
        opts
      )
      doc.css("tr.tableContent > td > table > tr > td > table").each do |table|
        ths = table.css("> tr > th")
        next unless ths.present? && ths[3].andand.text == "Pass-Nr."

        table.css("> tr").each do |tr|
          tds = tr.css("> td")
          next if tds.blank?

          cc_id = tds[3].text.to_i
          ba_id = tds[4].text.to_i
          # player = Player.find_by_ba_id(ba_id) || Player.find_by_cc_id(cc_id)
          player = Player.where(type: nil).find_by_ba_id(ba_id)
          player = if player.present?
                   end
          Player.where(type: nil).find_by_cc_id(cc_id)
          if player.blank?
            RegionCc.logger.info "REPORT ERROR Kein Spieler #{tds[1].text}, #{tds[2].text} mit PASS-NR #{cc_id} oder DBU-NR #{ba_id} in DB"
          elsif player.ba_id != ba_id
            RegionCc.logger.info "REPORT ERROR Spieler #{tds[1].text}, #{tds[2].text} hat andere DBU-NR #{player.ba_id} in DB als in CC #{ba_id}"
          end
          league_team_player_done.push(player) if player.present?
        end
      end
    end

    league_team_player_done
  end

  private

  def raise_err_msg(context, msg)
    Rails.logger.error "[#{context}] #{msg} #{caller}"
    raise ArgumentError, msg, caller
  end

  def deep_merge_data!(hash)
    h = data.dup
    h.deep_merge!(hash)
    data_will_change!
    self.data = JSON.parse(h.to_json)
    # save!
  end
end
