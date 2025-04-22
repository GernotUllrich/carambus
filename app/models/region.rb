# frozen_string_literal: true

require "open-uri"

# == Schema Information
#
# Table name: regions
#
#  id                 :bigint           not null, primary key
#  address            :text
#  dbu_name           :string
#  email              :string
#  fax                :string
#  logo               :string
#  name               :string
#  opening            :string
#  public_cc_url_base :string
#  shortname          :string
#  source_url         :string
#  sync_date          :datetime
#  telefon            :string
#  website            :string
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  cc_id              :integer
#  country_id         :integer
#
# Indexes
#
#  index_regions_on_country_id  (country_id)
#  index_regions_on_shortname   (shortname) UNIQUE
#
# noinspection SpellCheckingInspection
class Region < ApplicationRecord
  include LocalProtector
  include SourceHandler
  include RegionTaggable
  # TODO: check country association, because RuboCop complains
  # Unable to find an associated Rails Model for the ':country' association field
  belongs_to :country
  has_many :clubs
  has_many :tournaments
  has_many :player_rankings
  has_many :locations, as: :organizer
  has_many :organized_tournaments, as: :organizer, class_name: "Tournament"
  has_many :organized_leagues, as: :organizer, class_name: "League"
  has_one :setting
  has_many :leagues, as: :organizer, class_name: "League"
  has_one :region_cc

  serialize :scrape_data, coder: YAML, type: Hash

  self.ignored_columns = ["location_url"]

  NON_CC = {
    "BBV" => "https://billardbayern.de/"
  }

  NON_CC_ADMIN = {
    "BBV" => "https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/home"
  }

  SHORTNAMES_CC = {
    "DBU" => "https://billard-union.net/",
    # was 'BBBV' => 'https://bbbv.club-cloud.de/',
    "BBBV" => "https://billard-brandenburg.net/",
    # "BBV",##
    "BLMR" => "https://blmr.club-cloud.de/",
    "BLVN" => "https://billard-niedersachsen.de/",
    "BLVSA" => "https://www.blv-sa.de/",
    "BVB" => "https://billard.club-cloud.de/berlin/",
    "BVBW" => "https://billard-bvbw.de/",
    "BVNR" => "https://billard-niederrhein.de/",
    "BVNRW" => "https://bvnrw.net/",
    "BVRP" => "https://billardverband-rlp.de/",
    "BVS" => "https://billard-ergebnisse.de/",
    "BVW" => "https://westfalenbillard.net/",
    # "HBU",
    "NBV" => "https://ndbv.de/",
    "SBV" => "https://billard-sachsen.de/",
    "TBV" => "https://billard-thueringen.de/"
  }.freeze

  #  BVB
  SHORTNAMES_ROOF_ORGANIZATION = %w[DBU].freeze
  SHORTNAMES_CARAMBUS_USERS = %w[BVBW NBV].freeze
  SHORTNAMES_OTHERS = %w[BLMR BLVN BVNR BVRP BVS BVW SBV TBV].freeze
  SHORTNAMES_FEDERATIONS = %w[BVNRW].freeze
  SHORTNAMES_NO_CC = %w[BBBV BBV HBU].freeze
  SHORTNAMES = SHORTNAMES_ROOF_ORGANIZATION +
    SHORTNAMES_FEDERATIONS +
    SHORTNAMES_CARAMBUS_USERS +
    SHORTNAMES_OTHERS + SHORTNAMES_NO_CC

  COLUMN_NAMES = {
    "Logo" => "",
    "id" => "regions.id",
    "Shortname" => "regions.shortname",
    "Name" => "regions.name",
    "Email" => "regions.email",
    "Address" => "regions.address",
    "Country" => ""
  }.freeze

  def self.region_map
    map = all.pluck(:shortname, :id).to_h
    map.select { |k, _v| k.present? }
    return {
      "Norddeutscher Billard-Verband" => map["NBV"],
      "Norddeutscher Billard-Verband e.V." => map["NBV"],
      "Brandenburgischer Billard-Verband" => map["BBBV"],
      "Brandenburgischer Billard-Verband e.V." => map["BBBV"],
      "Bayerischer Billardverband" => map["BBV"],
      "Bayerischer Billardverband e.V." => map["BBV"],
      "BL Mittleres Rheinland" => map["BLMR"],
      "Billard Landesverband Mittleres Rheinland" => map["BLMR"],
      "Billard Landesverband Mittleres Rheinland e.V." => map["BLMR"],
      "BLMR" => map["BLMR"],
      "Billard-Landesverband Sachsen-Anhalt e.V." => map["BLVSA"],
      "Billard Landesverband Sachsen-Anhalt" => map["BLVSA"],
      "Billard Landesverband Sachsen-Anhalt e.V." => map["BLVSA"],
      "Billard-Verband Niedersachsen e.V." => map["BLVN"],
      "Billard Landesverband Niedersachsen" => map["BLVN"],
      "Billard Landesverband Niedersachsen e.V." => map["BLVN"],
      "Billard-Verband Berlin 49/76 e.V." => map["BVB"],
      "Billard-Verband Berlin" => map["BVB"],
      "Billard-Verband Berlin e.V." => map["BVB"],
      "Billard-Verband Baden-Württemberg" => map["BVBW"],
      "Billard-Verband Baden-Württemberg e.V." => map["BVBW"],
      "BV Niederrhein" => map["BVNR"],
      "Billard-Verband Niederrhein" => map["BVNR"],
      "Billard-Verband Niederrhein e.V." => map["BVNR"],
      "Billard-Verband Rheinland-Pfalz 1989 e.V." => map["BVRP"],
      "Billard-Verband Rheinland-Pfalz" => map["BVRP"],
      "Billard-Verband Rheinland-Pfalz e.V." => map["BVRP"],
      "Billard-Verband Nordrhein-Westfalen" => map["BVNRW"],
      "Billard-Verband Nordrhein-Westfalen e.V." => map["BVNRW"],
      "BV Westfalen" => map["BVW"],
      "Billard-Verband Westfalen" => map["BVW"],
      "Billard-Verband Westfalen e.V." => map["BVW"],
      "Hessische Billard-Union" => map["HBU"],
      "Hessische Billard-Union e.V." => map["HBU"],
      "Billard-Verband Saar" => map["BVS"],
      "Billard-Verband Saar e.V." => map["BVS"],
      "Sächsischer Billard Verband" => map["SBV"],
      "Sächsischer Billard-Verband" => map["SBV"],
      "Sächsischer Billard-Verband e.V." => map["SBV"],
      "Sächsischer Billard Verband e.V." => map["SBV"],
      "Thüringer Billard-Verband" => map["TBV"],
      "Thüringer Billard-Verband e.V." => map["TBV"],
      "Deutsche Billard-Union" => map["DBU"],
      "Deutsche Billard-Union e.V." => map["DBU"]
    }
  end
  def self.search_hash(params)
    {
      model: Region,
      sort: params[:sort],
      direction: sort_direction(params[:direction]),
      search: [params[:sSearch], params[:search]].compact.join("&").to_s,
      column_names: Region::COLUMN_NAMES,
      raw_sql: "(regions.name ilike :search)
or (regions.shortname ilike :search)
or (regions.email ilike :search)
or (regions.address ilike :search)",
      joins: :country
    }
  end

  URL_MAP = {
    "nbv" => "https://e12112e2454d41f1824088919da39bc0.club-cloud.de"
  }.freeze

  # scrape_locations
  def scrape_locations
    base_url = public_cc_url_base
    url = "location.php?p=#{region_cc.cc_id}|||||||1"
    location_url = base_url + url
    uri = URI(location_url)
    location_html = Net::HTTP.get(uri)
    location_doc = Nokogiri::HTML(location_html)
    location_table = location_doc.css("article > section > table")[1]
    # no_locs = location_table.css("th")[0].text.match(/(\d+) Locations gefunden/)[1].to_i
    no_pages = location_table.css("tr table tr td")[1].text.gsub(/[  ]*/, "").match(/Seite(\d+)von(\d+)/)[2].to_i
    (1..no_pages).each do |p_no|
      range = (((p_no - 1) * 10 + 1)..((p_no - 1) * 10 + 10))
      page_url = base_url + "location.php?p=#{region_cc.cc_id}|||||||#{p_no}"
      uri = URI(page_url)
      location_html = Net::HTTP.get(uri)
      location_doc = Nokogiri::HTML(location_html)
      location_table = location_doc.css("article > section > table")[1]
      location_table.css("tr").each do |tr|
        next if tr.css("th").count.positive?
        break if tr.css("td > table").count.positive?

        # seqno = tr.css("td")[0].text.strip.to_i
        # logo = tr.css("td")[1].text.strip
        raise StandardError, "NO Link ?" unless tr.css("td a")[0].present?
        lnr = tr.css("td")[0].text.to_i
        next unless range.include?(lnr)
        name = tr.css("td a").text.strip
        link = tr.css("td a")[0]["href"]

        cc_id = link.split("p=")[1].split("|")[1].to_i

        addr = tr.css("td")[2].inner_html.split("<br>")[1..2]
        location = if shortname == "DBU"
                     Location.where(organizer: self).where(dbu_nr: cc_id).first
                   else
                     loc = Location.where(organizer: self).where(cc_id: cc_id).first
                     if loc.present?
                       loc
                     else
                       given_region = self
                       clubs_in_region = Club.where(region: given_region)
                       Location.where(organizer: clubs_in_region, cc_id: cc_id).first
                     end
                   end
        if location.present?
          Location.where.not(id: location.id).where("address ilike '#{addr[0]}%'")
                  .where(name: location.name).all.each do |club_location|
            location.merge_locations(club_location)
          end
        end
        location = find_or_create_location(addr, name, cc_id, location, location_url)

        location_detail_url = base_url + link
        Rails.logger.info "reading #{location_detail_url}"
        uri = URI(location_detail_url)
        location_detail_html = Net::HTTP.get(uri)
        location_detail_doc = Nokogiri::HTML(location_detail_html)
        location_detail_table = location_detail_doc.css("aside > section > table")
        location_detail_table.css("tr").each do |tr_dl|
          next unless tr_dl.css("td")[0].text.strip == "Vereine"

          vereine = tr_dl.css("td")[1].css("a").to_a
          vereine.each do |v|
            vereinslink = v["href"]
            # vereins_name = v.text.strip
            club_dbu_nr = vereinslink.split("p=")[1].split("-")[3].to_i
            club = Club.find_by_dbu_nr(club_dbu_nr) if shortname == "DBU"
            club = Club.find_by_cc_id(club_dbu_nr) if shortname != "DBU"
            next unless club.present?

            club_location = ClubLocation.find_by_location_id_and_club_id(location&.id, club.id)
            next if club_location.present?

            ClubLocation.create(
              location_id: location.id,
              club_id: club.id
            ) if location.present?
          end
        end
      end
    end
  rescue StandardError => e
    Rails.logger.info "===== scrape ===== FATAL Error  #{e}, #{e.backtrace&.join("\n")}"
    raise StandardError, "FATAL Error  #{e}, #{e.backtrace&.join("\n")}" unless Rails.env == "production"
  end

  # scrape regions from Club Cloud Instances
  def self.scrape_regions
    Region.all.each do |region|
      region.assign_attributes(public_cc_url_base: SHORTNAMES_CC[region.shortname])
      region.save if region.changed?
    end
    Region.where.not(public_cc_url_base: nil).all.each do |region|
      region.scrape_region_public
    rescue StandardError => e
      Rails.logger.info "!!!!!!!!! Error: Problem #{e} #{e.backtrace&.join("\n")}"
    end
    Region.find_by_shortname("BBV")&.scrape_region_public
  end

  def post_cc_public(action, post_options = {}, _opts = {})
    referer = post_options.delete(:referer)
    referer = referer.present? ? base_url + referer : nil
    if RegionCc::PATH_MAP[action].present?
      url = public_cc_url_base + RegionCc::PATH_MAP[action][0]
      read_only_action = RegionCc::PATH_MAP[action][1]
      if read_only_action
        Rails.logger.debug "[#{action}] POST #{RegionCc::PATH_MAP[action][0]} with payload #{post_options}"
      else
        # read_only
        Region.logger.debug "[#{action}] #{
          if Rails.env != "procduction"
            "WILL"
          end} POST #{action} #{RegionCc::PATH_MAP[action][0]} with payload #{post_options}"
      end
      uri = URI(url)
      http = Net::HTTP.new(uri.host.to_s, uri.port.to_i)
      http.use_ssl = true
      req = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"] = "application/x-www-form-urlencoded"
      req["referer"] = referer if referer.present?
      req["cache-control"] = "max-age=0"
      req["upgrade-insecure-requests"] = "1"
      req["accept-language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7,fr;q=0.6"
      req["accept"] =
        "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,\
image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
      req.set_form_data(post_options.reject { |_k, v| v.blank? })
      # sleep(0.5)
      res = http.request(req)
      doc = if res.message == "OK"
              Nokogiri::HTML(res.body)
            else
              Nokogiri::HTML(res.message)
            end
    end
    [res&.message, doc]
  rescue e < EOFError
    ["EOFError", nil]
  end

  # scrape_single_league_public
  def scrape_single_league_public(season, opts = {})
    league_details = opts[:league_details]
    League.scrape_leagues_from_cc(self, season, league_details:)
  end

  # These are URLs which are Errors in ClubCloud and must be ignored
  VOID_URLS = [
    "https://ndbv.de/sb_einzelergebnisse.php?p=20--2022/2023-570------100000-"
  ]
  # crape_single_tournament_public
  def scrape_tournaments_check(season_from, opts = {})
    Tournament.joins(:tournament_cc).where(organizer_id: id, organizer_type: "Region").where("season_id >= ?", season_from.id).where(source_url: nil).each do |tournament|
      Rails.logger.error "TournamentCheck ERROR: no source_url on Tournament[#{tournament.id}]}"
    end
    source_urls_todo = {}
    Tournament.joins(:tournament_cc).where(organizer_id: id, organizer_type: "Region").where("season_id >= ?", season_from.id).each do |t|
      source_urls_todo[t.id] = normalize_tournament_url(t.source_url)
    end
    source_urls_done = []
    problem_source_urls = []
    url = public_cc_url_base
    Rails.logger.info "TournamentCheck ===== scrape ===== SCRAPING TOURNAMENTS '#{url}'"
    Season.where("id >= #{season_from.id}").each do |season|
      einzel_url = url + "sb_einzelergebnisse.php?p=#{cc_id}--#{season.name}-#{opts[:tournament_cc_id]}----1-1-100000-"
      Rails.logger.info "TournamentCheck reading #{einzel_url}"
      uri = URI(einzel_url)
      einzel_html = Net::HTTP.get(uri)
      einzel_doc = Nokogiri::HTML(einzel_html)
      einzel_doc.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
        tournament_link = tr.css("a")[0].attributes["href"].value
        tournament_url = normalize_tournament_url(url + tournament_link)
        if VOID_URLS.include?(tournament_url)
          Rails.logger.error "TournamentCheck ERROR: skip erroneous URL from CC: - #{tournament_url}"
          next
        end
        tournament_cc_id_from_link = tournament_link.split("p=")[1].split("-")[3].to_i
        next if opts[:tournament_cc_id].present? && opts[:tournament_cc_id].to_i != tournament_cc_id_from_link

        region_cc_id_from_link = tournament_link.split("p=")[1].split("-")[0].to_i
        if cc_id != region_cc_id_from_link
          Rails.logger.error "TournamentCheck ERROR: mismatch region_cc_id_from_link:#{region_cc_id_from_link} and region.cc_id:#{cc_id} - #{tournament_url}"
          next
        end

        tournament_ccs = TournamentCc.where(cc_id: tournament_cc_id_from_link, context: region_cc.context).to_a
        if tournament_ccs.count > 1
          Rails.logger.error "TournamentCheck ERROR: multiple tournament_cc with cc_id:#{tournament_cc_id_from_link} - #{tournament_url}"
          next
        elsif tournament_ccs.count == 0
          Rails.logger.info "TournamentCheck TODO: tournament_cc with cc_id:#{tournament_cc_id_from_link} not yet present!! - #{tournament_url}"
          next
        end
        tournament_cc = tournament_ccs[0]

        tournament = tournament_cc.tournament
        if tournament.blank?
          Rails.logger.error "TournamentCheck ERROR: tournament_cc with cc_id:#{tournament_cc_id_from_link} without tournament - #{tournament_url}"
          next
        end
        source_url = normalize_tournament_url(tournament_url.gsub("sb_einzelergebnisse.php", "sb_meisterschaft.php"))
        tournament_source_url = normalize_tournament_url(tournament.source_url)
        if source_url != tournament_source_url
          Rails.logger.error "TournamentCheck ERROR: mismatch tournament.source_url:#{tournament.source_url} in Tournament[#{tournament.id}] without source_url from link - #{source_url}"
          problem_source_urls << [tournament.id, tournament.source_url]
          next
        end
        unless source_urls_todo.values.include?(source_url)
          Rails.logger.error "TournamentCheck TODO: source_url not in any Tournament - #{source_url}"
        end
        source_urls_done << source_url
      end
    end
    source_urls_not_done = source_urls_todo.values - source_urls_done
    t_ids_todo = source_urls_todo.to_a.select{|k,v| source_urls_not_done.include?(v)}
    Rails.logger.info "TournamentCheck source_urls not done: Tournament[#{t_ids_todo}]"
    source_urls_new = source_urls_done - source_urls_todo.values
    Rails.logger.info "TournamentCheck source_urls new or error: #{source_urls_new.inspect}"
    Rails.logger.info "TournamentCheck problem_source_urls: #{problem_source_urls.inspect}"
  end

  # crape_single_tournament_public
  def scrape_single_tournament_public(season, opts = {})
    tournament = nil
    url = public_cc_url_base
    Rails.logger.info "===== scrape ===== SCRAPING REGION '#{url}'"
    einzel_url = url + "sb_meisterschaft.php?eps=100000&s=#{season.name}"
    Rails.logger.info "reading #{einzel_url}"
    uri = URI(einzel_url)
    einzel_html = Net::HTTP.get(uri)
    einzel_doc = Nokogiri::HTML(einzel_html)
    # scrape branches
    einzel_doc.css("article ul.tabstrip li a").each do |a|
      branch_cc_id = a.attributes["href"].value.split("p=")[1].split("-")[1].to_i
      next if branch_cc_id.zero?

      branch_cc_name = a.text.strip
      branch_cc = BranchCc.where(context: region_cc.context, cc_id: branch_cc_id).first
      if branch_cc.present?
        if branch_cc.name != branch_cc_name
          Rails.logger.info "===== scrape ===== Error: Problem with BranchCc #{{ "branch_cc_name" => branch_cc_name,
                                                                                 "branch:cc" => branch_cc.attributes }
                                                                                 .inspect}"
        end
      else
        branch_cc = BranchCc.where(context: region_cc.context, name: branch_cc_name).first
        branch_cc ||= BranchCc.new(context: region_cc.context, name: branch_cc_name, region_cc:,
                                   discipline: Discipline.find_by_name(branch_cc_name))
        branch_cc.update!(cc_id: branch_cc_id)
      end
    end
    # maximum_cc_id so far
    # TODO: test the .maximimum(:cc_id), because RuboCop complains:
    # <html>One of the following expectations should be satisfied:<br/>Expected DB field name of
    # table 'tournament_cc', but found ':cc_id'<br/>Hash expected
    cc_id_max = TournamentCc.joins(tournament: :season)
                            .where(seasons: { id: season.id })
                            .where(tournaments: { organizer_id: 1, organizer_type: "Region" })
                            .maximum(:cc_id)
    open_tournaments_cc_ids = TournamentCc.joins(tournament: :season)
                                          .where(seasons: { id: season.id })
                                          .joins("left outer join games on games.tournament_id = tournaments.id")
                                          .where(tournaments: { organizer_id: 1, organizer_type: "Region" })
                                          .where(games: { id: nil }).uniq.map(&:cc_id)
    einzel_doc.css("article table.silver").andand[1].andand.css("tr").to_a[2..].to_a.each do |tr|
      tournament_link = tr.css("a")[0].attributes["href"].value
      params = tournament_link.split("p=")[1].split("-")
      cc_id = params[3].to_i
      if opts[:optimize_api_access] && (cc_id <= cc_id_max)
        date = DateTime.parse(tr.css("td")[1])
        next if date > Time.now
        next unless open_tournaments_cc_ids.include?(cc_id)
      end
      Rails.logger.info "reading #{url + tournament_link}"
      uri = URI(url + tournament_link)
      tournament_html = Net::HTTP.get(uri)
      Rails.logger.info "===== scrape =========================== SCRAPING TOURNAMENT '#{url + tournament_link}'"
      tournament_doc = Nokogiri::HTML(tournament_html)
      region_cc_id = params[0].to_i
      region_cc.assign_attributes(cc_id: region_cc_id) if region_cc.cc_id.zero? || region_cc.cc_id.blank?
      region_cc.save
      name = tr.css("a")[0].text.strip
      tc = TournamentCc.where(cc_id:, context: region_cc.context).first
      tc ||= TournamentCc.new(cc_id:, name:, context: region_cc.context)

      if tc.present?
        # some checks
        if name != tc.name
          Rails.logger.info "===== scrape ===== Error: Problem with tournament_cc in
 #{tournament_link}: '#{name}' != '#{tc.name}' - fixed"
          tc.assign_attributes(name:)
        end
      else
        tc = TournamentCc.new(cc_id: cc_id, context: region_cc.context)
      end
      tc.assign_attributes(name:)
      tc.save
      # tournament known but no cc entry yet?
      tournament = Tournament.where(season:, organizer: self, title: name).first
      tournament ||= Tournament.create(season:, organizer: self, title: name)
      TournamentCc.where(tournament_id: tournament.id).where.not(id: tc.id).destroy_all
      tc.update(tournament:)
      tournament.reload.scrape_single_tournament_public(opts.merge(tournament_doc:))
    rescue StandardError => e
      Rails.logger.info "!!!!!!!!! Error #{e} tournament[#{tournament.andand.id}]#{e.backtrace&.join("\n")}"
    end
  rescue StandardError => e
    Rails.logger.info "!!!!!!!!! Error #{e} tournament[#{tournament.andand.id}]#{e.backtrace&.join("\n")}"
  end

  def self.scrape_regions_cc(season)
    Region.find_by_shortname("DBU")&.scrape_clubs(season)
  end

  # scrape_clubs
  def scrape_clubs(season, opts = {})
    region_map_ = Region.region_map
    clubs_url = nil
    if Rails.env != "production" || opts[:from_background]
      if shortname == "BBV"
        url = "https://bbv-billard.liga.nu"
        clubs_url = "https://bbv-billard.liga.nu/cgi-bin/WebObjects/nuLigaBILLARDDE.woa/wa/clubSearch?searchFor=e.V.&federation=BBV&federations=BBV"
        uri = URI(clubs_url)
        html_clubs = Net::HTTP.get(uri).gsub("//--", "--").
          gsub('id="banner-groupPage-content"', "").
          gsub(/<meta name="uLigaStatsRefUrl"\s*\/>/, "").
          gsub('</meta>', '')
        doc_clubs = Nokogiri::HTML.fragment(html_clubs)
        clubs_table = doc_clubs.css("table")[0]
        clubs_table.css("tr").each do |tr|
          if tr.css("td").present?
            club_url = url + tr.css("a")[0].attributes["href"]
            club_cc_id = club_url.match(/club=(\d+)/).andand[1].to_i
            club_match = tr.css("td")[0].text.match(/\n\s*(.*)\n\s*\((\d+)\)/)
            club_name = club_match.andand[1]
            club_dbu_nr = club_match.andand[2].to_i
            location = nil
            tr.css("td li").each do |ls|
              location_params = ls.text.split("\n").map(&:strip)
              location_name = location_params[1]
              location_street = location_params[2].split(", ")[0]
              location_city = location_params[2].split(", ")[1]
              location = find_or_create_location([location_street, location_city], location_name, nil, location, clubs_url)
            end
            club = Club.find_by_dbu_nr(club_dbu_nr)
            if club&.name != club_name
              Rails.logger.info "===== scrape ===== scrape clubs - mismatch in names: id: #{club&.id}, club_name: #{club&.name}, new_name: #{club_name}"
            end
            unless club.present?
              club = Club.new(name: club_name, dbu_nr: club_dbu_nr)
            end
            club.cc_id = club_cc_id
            club.name = club_name
            club.region = self
            club.source_url = club_url
            club.save!
            if club.present? && location.present?
              club_location = ClubLocation.find_or_create_by({ club: club, location: location })
              club_location
            end
          end
        end
      else
        url = public_cc_url_base
        if url.present?
          clubs_url = "#{url}verein-details.php?eps=100000"
          Rails.logger.info "reading #{clubs_url}"
          uri = URI(clubs_url)
          html_clubs = Net::HTTP.get(uri)
          doc_clubs = Nokogiri::HTML(html_clubs)
          clubs_table = doc_clubs.css("article table.silver")[1]
          clubs = clubs_table.css("a")
          clubs.each do |club_a|
            # if shortname == "DBU"
            ref = club_a.attributes["href"].value
            next if opts[:start_with_club_shortname].present? && (club_a.text.strip < opts[:start_with_club_shortname])
            next if opts[:restrict_to_club_shortname].present? && club_a.text.strip != opts[:restrict_to_club_shortname]

            club_shortname = club_a.text.strip
            params = ref.split("p=")[1].split("|")
            cc_id = params[3]
            club_url = url + ref
            Rails.logger.info "reading #{club_url}"
            uri = URI(club_url)
            html_club = Net::HTTP.get(uri)
            doc_club = Nokogiri::HTML(html_club)
            club_table = doc_club.css("aside table.silver")[0]
            region = dbu_nr = club_name = nil
            club_table.css("tr").each do |tr|
              if %w[Mitgliedsverband Verband Landesverband].include? tr.css("td")[0].text.strip
                region_name = tr.css("td")[1].text.strip
                region_name = "BLMR" if %w[PBVRW KBVM PBVM].include?(region_name)
                region = region_map_[region_name]
                unless region.present?
                  region = region_map_[region_name] =
                    Region.find_by_name(region_name) || Region.create(name: region_name, country: Country.first)
                end
                Rails.logger.info "===== scrape ===== Error - Name Problem with Region '#{region_name}'" if region.blank?
              elsif tr.css("td")[0].text.strip == "Verein"
                club_name = tr.css("td")[1].text.strip.gsub("1.", "1. ").gsub("1.  ", "1. ")
              elsif tr.css("td")[0].text.strip == "DBU-Nr."
                dbu_nr = tr.css("td")[1].text.strip.to_i
              end
            end
            next unless club_name.present?

            club_matches = Club.where("synonyms ilike ?", "%#{club_name.strip}%").to_a.select do |c|
              c.synonyms.split("\n").include?(club_name.strip)
            end
            if club_matches.count > 1
              club = club_matches.find { |c| c.region_id == region&.id }
              club = club_matches.first if club.blank?
            else
              club = club_matches.first
              club = Club.new(name: club_name, region:) if club.blank?
            end
            next unless club.present?

            club.assign_attributes(name: club_name, shortname: club_shortname, region:, cc_id:)
            club.source_url = club_url
            club.save!
            club_matches.reject { |c| c.id == club.id }.each do |c|
              Rails.logger.info "===== scrape ===== MERGE Clubs #{club.name} [#{club.id}] with #{c.name} [#{c.id}]"
              club.merge_clubs(c.id)
            end
            if club_matches.count { |c| c.id != club.id }.zero?
              club.assign_attributes(dbu_nr:)
            else
              Rails.logger.info "===== scrape ===== Error ba_id problem cannot merge #{club_matches.map(&:id)} to #{id}"
            end
            club.source_url = club_url
            club.save!
            # end

            club.scrape_club(season, ref, url, opts.merge(called_from_portal: shortname == "DBU"))
          end
        else
          Rails.logger.info "===== scrape ===== clubs_url: #{clubs_url} No ClubCloud Url for Region #{name}(#{shortname})"
        end
      end
    else
      RegionScrapeClubsJob.perform_later(self, opts)
    end
  rescue StandardError => e
    Rails.logger.info "===== scrape ===== FATAL Error clubs_url: #{clubs_url}  #{e}, #{e.backtrace&.join("\n")}"
  end

  def source
    "ClubCloud"
  end

  def scrape_region_public

    key_to_db_name = {
      "Adresse" => "address",
      "E-Mail" => "email",
      "Telefon" => "telefon",
      "Telefax" => "fax",
      "Website" => "website",
      "Öffnungszeiten" => "opening"
    }
    if public_cc_url_base.present?
      url = public_cc_url_base
      Rails.logger.info "===== scrape ===== reading #{url} -\
 Region #{shortname} ClubCloud index page - to scrape clubs"
      verband_url = url + "verband.php"
      Rails.logger.info "reading #{verband_url}"
      uri = URI(verband_url)
      html_verband = Net::HTTP.get(uri)
      doc_verband = Nokogiri::HTML(html_verband)
      table = doc_verband.css("article table.silver")
      rows = table.css("tr")
      rows.each do |tr|
        key_val = tr.css("td:nth-child(1)").text.split(":").compact
        if key_val.count == 2
          key = key_val[0].strip
          val = tr.css("td:nth-child(1)").inner_html.split(":")[1].gsub(/^<br>/, "")
        else
          key = tr.css("td:nth-child(1)").text
          val = tr.css("td:nth-child(2)").inner_html
        end
        assign_attributes("#{key_to_db_name[key]}": val) if key_to_db_name[key].present?
      end
      save!
      self.source_url = verband_url
      save! if changed?
      region_cc = RegionCc.find_by_shortname(shortname) || RegionCc.new(shortname:)
      region_cc.assign_attributes(name:, cc_id:, region_id: id, context: shortname.downcase, public_url: url,
                                  base_url:)
      region_cc.save!
    else
      if shortname == "BBV" && false # TODO debug this, before releasing
        url = Region::NON_CC["BBV"]
        Rails.logger.info "reading #{url}"
        Rails.logger.info "===== scrape ===== SCRAPING REGION '#{url}'"
        # TODO continue coding here
        self.logo = "https://api.carambus.de/club-logos/BBV_Transparent-2webp.webp"
        self.address = "Postfach 1104<br>84048 Mainburg"
        self.email = "gs@billard.bayern"
        self.telefon = "+49 89 1570 2242"
        self.website = "https://billardbayern.de/"
        self.source_url = "https://billardbayern.de/geschaeftsstelle/"
      end
    end
  end

  require "net/http"

  def fetch_uri(uri, limit = 10)
    raise ArgumentError, "too many HTTP redirects" if limit.zero?

    response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == "https") do |http|
      request = Net::HTTP::Get.new uri
      http.request request
    end

    case response
    when Net::HTTPSuccess
      response.body
    when Net::HTTPRedirection
      location = response["location"].to_s
      warn "redirected to #{location}"
      fetch_uri(URI(location), limit - 1)
    else
      response&.value
    end
  end

  def fix_player_without_ba_id(firstname, lastname, should_be_ba_id = nil, should_be_club_id = nil)
    ret = nil
    args = { firstname:, lastname:, ba_id: should_be_ba_id, club_id: should_be_club_id }
    args.reject { |_k, v| v.nil? }
    players = Player.where(type: nil).where(args)
    return players[0] if players.count == 1

    players = Player.where(type: nil).where(firstname:, lastname:)
    if players.present?
      players.each do |player|
        players_same_name_arr = Player.where(type: nil).where(firstname: player.firstname,
                                                              lastname: player.lastname).to_a
        if players_same_name_arr.count == 1
          begin
            # try to update ba_id
            ret = players_same_name_arr[0]
            players_same_name_arr[0].update(ba_id: should_be_ba_id)
          rescue ActiveRecord::RecordNotUnique
            Rails.logger.info "REPORT! [fix_players_without_ba_id] Spieler mit
anderem Namen und gleicher ba_id (#{should_be_ba_id}) gefunden:
#{Player.find_by_ba_id(should_be_ba_id).andand.fullname}
hier: #{lastname}, #{firstname}"
          end
        else
          begin
            player_ok_arr = Player.where(type: nil).where(firstname:, lastname:,
                                                          ba_id: should_be_ba_id).to_a
            player_tmp_arr = Player.where(type: nil).where(firstname:,
                                                           lastname:).where("ba_id > 999000000").to_a
            if player_ok_arr.count == 1 && player_tmp_arr.count >= 1
              ret = Player.merge_players(player_ok_arr.first, player_tmp_arr.first)
            else
              Rails.logger.info "REPORT! [fix_players_without_ba_id] Kein Ersatz Record für Spieler gefunden:
should_be_ba_id: #{should_be_ba_id} hier: #{lastname}, #{firstname}"
              if should_be_ba_id.present?
                begin
                  ret = Player.create!(firstname:, lastname:, ba_id: should_be_ba_id,
                                       club_id: should_be_club_id)
                rescue StandardError
                  Rails.logger.info "REPORT! [fix_player_without_ba_id] (1) kann Spieler Record nicht anlegen:
firstname: #{firstname}, lastname: #{lastname}, ba_id: #{should_be_ba_id},
club_id: #{should_be_club_id}"
                end
              end
            end
          rescue ActiveRecord::RecordNotUnique
            Rails.logger.info "REPORT! [fix_players_without_ba_id] Spieler mit anderem Namen
 und gleicher ba_id (#{should_be_ba_id}) gefunden:
#{Player.find_by_ba_id(should_be_ba_id).andand.fullname}
hier: #{lastname}, #{firstname}"
          end
        end
      end
    else
      begin
        ret = Player.create(firstname:, lastname:, ba_id: should_be_ba_id,
                            club_id: should_be_club_id)
      rescue StandardError
        Rails.logger.info "REPORT! [fix_player_without_ba_id] (2) kann Spieler Record nicht anlegen:
firstname: #{firstname}, lastname: #{lastname}, ba_id: #{should_be_ba_id}, club_id: #{should_be_club_id}"
      end
    end
    ret
  end

  def display_shortname
    shortname
  end

  scope :having_rankings, -> {
    joins(:player_rankings)
      .joins('INNER JOIN disciplines ON disciplines.id = player_rankings.discipline_id')
      .distinct
  }

  def has_rankings?
    player_rankings.joins(:discipline).exists?
  end

  private

  def normalize_tournament_url(url)
    url_str = url.to_s.gsub(public_cc_url_base, "")
    params = url_str.split("p=")[1]&.split("-").to_a
    "#{public_cc_url_base}sb_einzelergebnisse.php?p=#{params[0]}--#{params[2]}-#{params[3]}------100000-"
  end

  def find_or_create_location(addr, name, cc_id, location, location_url)
    unless location.present?
      query = Location.where(organizer_type: "Region", organizer_id: self.id)
      query = query.where(cc_id: cc_id) if cc_id.present?
      locations = (query.where("address ilike '%#{addr[0]}%'") if addr[0].present?)
      Array(locations).each do |l|
        addr_loc = if l.address =~ /,/
                     l.address.split(", ")
                   else
                     l.address.split("\n")
                   end
        # && addr_loc[1] == addr[1] && l.source_url !~ /billard-union.net/
        location = l if addr_loc[0] == addr[0]
      end
    end
    attr = {
      name: name,
      address: addr.join("\n"),
      organizer: self,
      dbu_nr: (cc_id if shortname == "DBU"),
      cc_id: (cc_id if shortname != "DBU")
    }.compact
    location = Location.new(attr) unless location.present?
    location.assign_attributes(attr)
    location.synonyms = nil
    if location.changes.present?
      location.source_url = location_url
      location.add_md5
      if location.new_record?
        md5 = Digest::MD5.hexdigest(location.attributes.except("synonyms", "sync_date", "updated_at", "created_at").inspect)
        location = Location.find_by_md5(md5) || location
      end
      begin
        location.save!
      rescue Exception => e
        e
      end
    end
    location
  end

end
