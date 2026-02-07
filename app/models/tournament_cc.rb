# frozen_string_literal: true

# == Schema Information
#
# Table name: tournament_ccs
#
#  id                        :bigint           not null, primary key
#  branch_cc_name            :string
#  category_cc_name          :string
#  championship_type_cc_name :string
#  context                   :string
#  description               :text
#  entry_fee                 :decimal(6, 2)
#  flowchart                 :string
#  league_climber_quote      :integer
#  location_text             :string
#  max_players               :integer
#  name                      :string
#  poster                    :string
#  ranking_list              :string
#  registration_rule         :integer
#  season                    :string
#  shortname                 :string
#  starting_at               :time
#  status                    :string
#  successor_list            :string
#  tender                    :string
#  tournament_end            :datetime
#  tournament_start          :datetime
#  created_at                :datetime         not null
#  updated_at                :datetime         not null
#  branch_cc_id              :integer
#  category_cc_id            :integer
#  cc_id                     :integer
#  championship_type_cc_id   :integer
#  discipline_id             :integer
#  group_cc_id               :integer
#  location_id               :integer
#  registration_list_cc_id   :integer
#  tournament_id             :integer
#  tournament_series_cc_id   :integer
#
# Indexes
#
#  index_tournament_ccs_on_cc_id_and_context  (cc_id,context) UNIQUE
#  index_tournament_ccs_on_tournament_id      (tournament_id) UNIQUE
#
class TournamentCc < ApplicationRecord
  include LocalProtector
  belongs_to :branch_cc, optional: true
  belongs_to :location, optional: true
  belongs_to :registration_list_cc, optional: true
  belongs_to :discipline, optional: true
  belongs_to :group_cc, optional: true
  belongs_to :championship_type_cc, optional: true
  belongs_to :category_cc, optional: true
  belongs_to :tournament_series_cc, optional: true
  belongs_to :tournament, optional: true

  COLUMN_NAMES = { # TODO: FILTERS
    "CC_ID" => "tournament_ccs.cc_id",
    "Name" => "tournament_ccs.name",
    "Shortname" => "tournament_ccs.shortname",
    "Discipline" => "disciplines.name",
    "Context" => "tournament_ccs.context",
    "SingleOrLeague" => "tournament_ccs.single_or_league",
    "Season" => "tournament_ccs.season",
    "BranchCc" => "branch_ccs.name",
    "Type" => "championship_type_ccs.name",
    "CategoryCc" => "category_ccs.name",
    "GroupCc" => "group_ccs.name"
  }

  REGISTRATION_RULES = {
    1 => "Standard (nur Aktive dürfen gemeldet werden)",
    2 => "Flexibel (Aktive und Passive dürfen gemeldet werden (Teilnehmer-Liste))",
    3 => "Meine Club Cloud (Meldung durch Spieler möglich / Extra-Meldeliste)"
  }.freeze
  REGISTRATION_RULES_INV = REGISTRATION_RULES.invert.merge({ "Jackpot ist auf Startseite ausgeblendet" => 1,
                                                             "Jackpot wird auf Startseite angezeigt" => 2 })

  JACKPOT_DISPLAY = {
    1 => "Nein, Jackpot auf Startseite AUSBLENDEN",
    2 => "Ja, Jackpot auf Startseite DARSTELLEN"
  }.freeze
  JACKPOT_DISPLAY_INV = JACKPOT_DISPLAY.invert

  TYPE_MAP = {
    6 => { # Pool
      1 => ["Norddeutsche Meisterschaft", "NDM"],
      2 => %w[Bezirksmeisterschaft BM]
    },
    7 => { # Snooker
      6 => ["Norddeutsche Meisterschaft", "NDM"]
    },
    8 => { # Kegel
      7 => ["Norddeutsche Meisterschaft", "NDM"]
    },
    10 => { # Karambol
      5 => ["Norddeutsche Meisterschaft", "NDM"],
      8 => %w[Vorgabepokal VP],
      9 => ["Petit Prix", "PP"],
      10 => ["Grand Prix", "GP"],
      11 => %w[NordCup NC],
      12 => %w[Bezirksmeisterschaft BM]
    }
  }.freeze

  TYPE_MAP_REV = {
    6 => { # Pool
      "Norddeutsche Meisterschaft" => 1,
      "NDM" => 1,
      "Bezirksmeisterschaft" => 2,
      "BM" => 2,
      "BKMR" => 2
    },
    7 => { # Snooker
      "Norddeutsche Meisterschaft" => 6,
      "NDM" => 6
    },
    8 => { # Kegel
      "Norddeutsche Meisterschaft" => 7,
      "NDM" => 7
    },
    10 => { # Karambol
      "Norddeutsche Meisterschaft" => 5,
      "NDM" => 5,
      "Vorgabepokal" => 8,
      "VP" => 8,
      "Petit Prix" => 9,
      "PP" => 9,
      "Grand Prix" => 10,
      "Grand-Prix" => 10,
      "GP" => 10,
      "NordCup" => 11,
      "NC" => 11,
      "Bezirksmeisterschaft" => 12,
      "BM" => 12,
      "BKMR" => 12
    }
  }.freeze

  def self.create_from_ba(tournament, opts)
    region = tournament.organizer
    region_cc = region.region_cc
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
    branch_cc = tournament.discipline.root.branch_cc
    begin
      TYPE_MAP_REV[branch_cc.cc_id].keys.each do |type_name|
        if /#{type_name}/.match?(tournament.title)
          type_found = TYPE_MAP_REV[branch_cc.cc_id][type_name]
          break
        end
      end
    rescue Exception => e
      Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
      return
    end
    tournament_cc = TournamentCc.where(name: tournament.title, discipline_id: tournament.discipline_id,
                                       branch_cc_id: branch_cc.id, season: opts[:season_name]).first
    begin
      args = {
        fedId: region.cc_id,
        branchId: branch_cc.cc_id,
        season: opts[:season_name],
        meisterName: tournament.title,
        meisterShortName: tournament.shortname.presence || "NDM",
        meldeListId: registration_list_cc&.cc_id,
        mr: 1,
        meisterTypeId: type_found.to_s,
        groupId: 10,
        playDate: tournament.date.strftime("%Y-%m-%d"),
        playDateTo: tournament.end_date.andand.strftime("%Y-%m-%d"),
        startTime: tournament.date.strftime("%H:%M"),
        quote: "",
        sg: "",
        maxtn: "",
        countryId: "free",
        pubName: "",
        save: ""
      }
    rescue Exception => e
      Rails.logger.error "Error: #{e} Tournament[#{tournament.id}]"
      return
    end
    region_cc.post_cc("createMeisterschaftSave", args, opts)
    tournament_cc.update(tournament_id: tournament.id) if tournament_cc.present?
  end

  #noinspection RubyLocalVariableNamingConvention
  def delete_tournament_results(opts)
    region = tournament.organizer
    tournament_cc = TournamentCc.find_by_tournament_id(tournament.id)
    branch_cc = tournament_cc.branch_cc
    args = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      season: tournament.season.name,
      disciplinId: tournament.discipline.discipline_cc.cc_id,
      catId: "*",
      meisterTypeId: "*",
      meisterschaftsId: tournament_cc.cc_id,
      teilnehmerId: "*"
    }
    _, doc = region.region_cc.post_cc_with_formdata("showErgebnisliste", args, opts)

    doc.css(".cc_bluelink").each do |line|
      partieId = line["href"].match(/.*partieId=(\d+).*/).andand[1].to_i
      region.region_cc.post_cc_with_formdata("deleteErgebnis", args.merge(partieId: partieId), opts)
    end
  end

  def upload_csv(opts)
    # GRUPPE/RUNDE;PARTIE;SATZ-NR.;PASS-NR. SPIELER 1;PASS-NR. SPIELER 2;PUNKTE SPIELER 1;PUNKTE SPIELER 2;AUFNAHMEN SPIELER 1;AUFNAHMEN SPIELER 2;HÖCHSTSERIE SPIELER 1;HÖCHSTSERIE SPIELER 2
    game_data = []
    game_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? "games.id >= #{Game::MIN_ID}" : "games.id < #{Game::MIN_ID}"
    tournament.games.where(game_scope).each do |game|
      game.gname = game.gname.presence || "Gruppe 1"
      if (m = game.gname.match(/^G(\d)-/))
        game.gname = "Gruppe #{m[1]}"
      end
      game.gname = "Gruppe 1" if /.*Runde/.match?(game.gname)
      gruppe = GroupCc::NAME_MAPPING[:groups]["#{/^group/.match?(game.gname) ? "Gruppe" : game.gname}#{if game.group_no.present?
                                                                                                         " #{game.group_no}"
                                                                                                       end}"] ||
               GroupCc::NAME_MAPPING[:round]["#{/^group/.match?(game.gname) ? "Gruppe" : game.gname}#{if game.group_no.present?
                                                                                                        " #{game.group_no}"
                                                                                                      end}"]
      begin
        gruppe = gruppe.gsub("Runde", "Gruppe").gsub("Hauptrunde", "Gruppe 1")
      rescue Exception
        Rails.logger.error "Error: Unknown group name Tournament[#{tournament.id}]"
        return
      end
      partie = game.seqno
      gp1 = game.game_participations.where(role: %w[playera Heim]).first
      gp2 = game.game_participations.where(role: %w[playerb Gast]).first

      line = begin
        "#{gruppe};#{partie};;#{gp1&.player&.cc_id};#{gp2&.player&.cc_id};#{gp1&.result};#{gp2&.result};#{gp1&.innings};#{gp2&.innings};#{gp1&.hs};#{gp2&.hs}"
      rescue StandardError
        nil
      end
      game_data << line if line.present?
    end

    region = tournament.organizer
    tournament_cc = TournamentCc.find_by_tournament_id(tournament.id)
    branch_cc = tournament_cc.branch_cc
    args = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      season: tournament.season.name,
      disciplinId: "*",
      catId: "*",
      meisterTypeId: "*",
      meisterschaftsId: tournament_cc.cc_id
    }
    seeding_scope = tournament.seedings.where("seedings.id >= #{Seeding::MIN_ID}").count > 0 ? "seedings.id >= #{Seeding::MIN_ID}" : "seedings.id < #{Seeding::MIN_ID}"
    begin
      ranking_data = tournament.seedings.where(seeding_scope).select do |seeding|
                       seeding.data["result"].andand["Gesamtrangliste"].present?
                     end.sort_by { |seeding| seeding.data["result"]["Gesamtrangliste"]["Rank"].to_i }.map do |s|
        [
          s.data["result"]["Gesamtrangliste"]["#"].to_i, s.data["result"]["Gesamtrangliste"]["Punkte"].to_i, "", s.player.cc_id, "", ""
        ].join(";")
      end
    rescue Exception
      Rails.logger.error "Error: One ore more Players not assignable Tournament[#{tournament.id}]"
      return
    end

    f = File.new("#{Rails.root}/tmp/ranking#{tournament_cc.cc_id}.csv", "w")
    f.write(ranking_data.join("\n"))
    f.close
    _, doc0a = region.region_cc.post_cc_with_formdata("importRangliste2",
                                                      args.merge(importBut: "", ranglistenimport: UploadIO.new("#{Rails.root}/tmp/ranking#{tournament_cc.cc_id}.csv", "text/csv", "ranking#{tournament_cc.cc_id}.csv")), opts)
    _, doc0b = region.region_cc.post_cc_with_formdata("showRangliste", args, opts)

    f = File.new("#{Rails.root}/tmp/result#{tournament_cc.cc_id}.csv", "w")
    f.write(game_data.join("\n"))
    f.close
    _, doc2 = region.region_cc.post_cc_with_formdata("importErgebnisseStep2",
                                                     args.merge(disciplinId: tournament.discipline.discipline_cc.cc_id, saveBut: "", importFile: UploadIO.new("#{Rails.root}/tmp/result#{tournament_cc.cc_id}.csv", "text/csv", "result#{tournament_cc.cc_id}.csv")), opts)
    _, doc3 = region.region_cc.post_cc("importErgebnisseStep3", args.merge(saveBut: ""), opts)

    [doc0a, doc0b, doc2, doc3]
  end

  # Scrapt die groupItemId-Optionen aus createErgebnisCheck.php für dieses Turnier
  # Gibt ein Hash zurück: {groupItemId => "Gruppe A", ...}
  # 
  # WICHTIG: Wenn opts[:session_id] übergeben wird, wird diese Session verwendet!
  # Sonst wird ensure_logged_in aufgerufen, was ein neues Login macht.
  def scrape_tournament_group_options(opts = {})
    return {} unless tournament.present?

    region = tournament.organizer
    raise "Tournament organizer not found" unless region.present?

    region_cc = region.region_cc
    raise "RegionCc not found for region: #{region.shortname}" unless region_cc.present?

    branch_cc = self.branch_cc
    raise "BranchCc not found for tournament_cc[#{id}]" unless branch_cc.present?

    # WICHTIG: Verwende die übergebene session_id, falls vorhanden!
    # Sonst stelle sicher, dass wir eingeloggt sind (mit Session-Validierung)
    session_id = opts[:session_id]
    unless session_id.present?
      Rails.logger.info "[scrape_tournament_group_options] No session_id in opts, calling ensure_logged_in..."
      session_id = Setting.ensure_logged_in
    else
      Rails.logger.info "[scrape_tournament_group_options] Using session_id from opts: #{session_id}"
    end

    base = region_cc.base_url.sub(/\/+$/, '') # Entferne trailing slashes

    # WICHTIG: Besuche erst die Ergebnisliste (showErgebnisliste.php)
    # um den "Kontext" in der Session zu setzen - das ist der Browser-Flow!
    show_url = base + "/admin/einzel/meisterschaft/showErgebnisliste.php?"
    show_uri = URI(show_url)
    show_http = Net::HTTP.new(show_uri.host, show_uri.port)
    show_http.use_ssl = true
    show_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    show_http.read_timeout = 30
    show_http.open_timeout = 10
    
    show_req = Net::HTTP::Get.new(show_uri.request_uri)
    show_req["cookie"] = "PHPSESSID=#{session_id}"
    show_req["referer"] = base + "/index.php"  # Wichtig: Referer vom Login
    show_req["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    show_req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    show_req["Accept-Language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7"
    show_req["Connection"] = "keep-alive"
    
    Rails.logger.warn "[scrape_tournament_group_options] Visiting showErgebnisliste.php to set session context..."
    show_res = show_http.request(show_req)
    Rails.logger.warn "[scrape_tournament_group_options] showErgebnisliste response: #{show_res.code}"
    
    # WICHTIG: Prüfe ob eine neue Session-ID gesetzt wurde und verwende diese!
    show_cookies = show_res.get_fields("set-cookie")
    if show_cookies
      show_cookies.each do |cookie|
        cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
        if cookie_match
          new_session_id = cookie_match[1]
          if new_session_id != session_id
            Rails.logger.info "[scrape_tournament_group_options] Got NEW session ID from showErgebnisliste: #{new_session_id} (old: #{session_id})"
            session_id = new_session_id
            # Update auch in Settings, damit andere Requests die neue Session verwenden
            Setting.key_set_value("session_id", session_id)
          end
          break
        end
      end
    end
    
    # KEINE Wartezeit mehr - ClubCloud erwartet schnelle Requests!
    # sleep(0.3)  # ENTFERNT

    # Erstelle Payload für createErgebnisCheck.php
    args = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      disciplinId: "*",
      season: tournament.season.name,
      catId: "*",
      meisterTypeId: championship_type_cc&.cc_id || "",
      meisterschaftsId: cc_id,
      teilnehmerId: "*",
      nbut: ""
    }

    # Rufe createErgebnisCheck.php mit GET auf (nicht POST!)
    # ClubCloud erwartet GET um das Formular zu laden, POST geht an createErgebnisSave.php
    url_with_params = base + "/admin/einzel/meisterschaft/createErgebnisCheck.php?" + URI.encode_www_form(args)
    uri = URI(url_with_params)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30
    http.open_timeout = 10

    req = Net::HTTP::Get.new(uri.request_uri)
    req["cookie"] = "PHPSESSID=#{session_id}"
    req["referer"] = show_url  # Verwende die showMeisterschaft-URL mit meisterschaftsId als Referer
    req["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    req["Accept-Language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7"
    req["Accept-Encoding"] = "gzip, deflate, br"
    req["Connection"] = "keep-alive"
    req["Upgrade-Insecure-Requests"] = "1"
    req["Sec-Fetch-Dest"] = "document"
    req["Sec-Fetch-Mode"] = "navigate"
    req["Sec-Fetch-Site"] = "same-origin"

    # Debug: Log request details
    login_time_str = Setting.key_get_value("session_login_time")
    time_since_login = login_time_str ? (Time.now.to_f - login_time_str.to_f) : nil
    Rails.logger.warn "[scrape_tournament_group_options] REQUEST DEBUG:"
    Rails.logger.warn "[scrape_tournament_group_options]   URL: #{url_with_params}"
    Rails.logger.warn "[scrape_tournament_group_options]   Cookie: PHPSESSID=#{session_id}"
    Rails.logger.warn "[scrape_tournament_group_options]   Referer: #{req['referer']}"
    Rails.logger.warn "[scrape_tournament_group_options]   User-Agent: #{req['User-Agent']}"
    Rails.logger.warn "[scrape_tournament_group_options]   Time since login: #{time_since_login ? '%.2f' % time_since_login : 'unknown'} seconds"

    res = http.request(req)
    
    # WICHTIG: Prüfe ob eine neue Session-ID gesetzt wurde
    res_cookies = res.get_fields("set-cookie")
    if res_cookies
      res_cookies.each do |cookie|
        cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
        if cookie_match
          new_session_id = cookie_match[1]
          if new_session_id != session_id
            Rails.logger.info "[scrape_tournament_group_options] Got NEW session ID from createErgebnisCheck: #{new_session_id} (old: #{session_id})"
            session_id = new_session_id
            # Update auch in Settings
            Setting.key_set_value("session_id", session_id)
          end
          break
        end
      end
    end
    
    # Debug: Log response details
    Rails.logger.warn "[scrape_tournament_group_options] RESPONSE DEBUG:"
    Rails.logger.warn "[scrape_tournament_group_options]   Status: #{res.code}"
    Rails.logger.warn "[scrape_tournament_group_options]   Content-Encoding: #{res['content-encoding'] || 'none'}"
    Rails.logger.warn "[scrape_tournament_group_options]   Set-Cookie headers: #{res.get_fields('set-cookie')&.join('; ') || 'none'}"

    unless res.is_a?(Net::HTTPSuccess)
      raise "Failed to fetch createErgebnisCheck: #{res.code} - #{res.message}"
    end

    # Decompress response body if needed
    body = res.body
    if res['content-encoding'] == 'gzip'
      Rails.logger.warn "[scrape_tournament_group_options] Decompressing gzip response..."
      body = Zlib::GzipReader.new(StringIO.new(body)).read
    elsif res['content-encoding'] == 'deflate'
      Rails.logger.warn "[scrape_tournament_group_options] Decompressing deflate response..."
      body = Zlib::Inflate.inflate(body)
    end

    # Parse HTML und extrahiere groupItemId-Optionen
    doc = Nokogiri::HTML(body)
    
    # Debug: Prüfe ob Select vorhanden ist
    select_element = doc.css('select[name="groupItemId"]')
    if select_element.empty?
      Rails.logger.warn "[scrape_tournament_group_options] WARNING: select[name='groupItemId'] not found in HTML response"
      Rails.logger.warn "[scrape_tournament_group_options] Response URL: #{url_with_params}"
      Rails.logger.warn "[scrape_tournament_group_options] Response status: #{res.code}"
      Rails.logger.warn "[scrape_tournament_group_options] Response body preview (first 1500 chars): #{body[0..1500]}"
      Rails.logger.warn "[scrape_tournament_group_options] All select elements: #{doc.css('select').map { |s| "#{s['name']}(#{s['id']})" }.join(', ')}"
      Rails.logger.warn "[scrape_tournament_group_options] Request args: #{args.inspect}"
      
      # Prüfe ob Login-Seite angezeigt wird
      if body.include?("call_police") || body.include?("loginUser")
        Rails.logger.error "[scrape_tournament_group_options] ERROR: Got login page instead of createErgebnisCheck page - session may be invalid"
        raise "Session invalid: Got login page instead of createErgebnisCheck"
      end
    end
    
    group_options = doc.css('select[name="groupItemId"] > option').each_with_object({}) do |o, memo|
      memo[o["value"].to_i] = o.text.strip unless o["value"] == "*"
    end

    if group_options.empty?
      Rails.logger.warn "[scrape_tournament_group_options] WARNING: No groupItemId options found for tournament_cc[#{id}]"
      Rails.logger.warn "[scrape_tournament_group_options] All select elements in response: #{doc.css('select').map { |s| s['name'] }.join(', ')}"
    else
      Rails.logger.info "[scrape_tournament_group_options] Scraped #{group_options.count} groupItemId options: #{group_options.inspect}"
    end
    
    group_options
  rescue StandardError => e
    Rails.logger.error "[scrape_tournament_group_options] Error scraping tournament group options: #{e.message}"
    Rails.logger.error "[scrape_tournament_group_options] Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise
  end

  # Erstellt oder updated den GroupCc Record mit den groupItemId-Mappings
  # Wird bei der Turniervorbereitung aufgerufen
  # 
  # WICHTIG: Auf lokalen Servern sind ClubCloud-Records geschützt (LocalProtector).
  # Daher speichern wir die Mappings direkt in tournament_monitor.data statt in GroupCc.
  # 
  # opts[:session_id] - Wenn übergeben, wird diese Session für das Scraping verwendet
  def prepare_group_mapping(opts = {})
    return nil unless tournament.present?

    # Scrape die groupItemId-Optionen (verwende session_id aus opts, falls vorhanden)
    group_options = scrape_tournament_group_options(opts)

    return nil if group_options.empty?

    tournament_monitor = tournament.tournament_monitor
    unless tournament_monitor.present?
      Rails.logger.warn "[prepare_group_mapping] No tournament_monitor found for tournament[#{tournament.id}]"
      return nil
    end

    # Speichere Mappings in tournament_monitor.data (nicht geschützt durch LocalProtector)
    tournament_monitor.deep_merge_data!(
      "cc_group_mapping" => {
        "positions" => group_options,
        "scraped_at" => Time.current.iso8601
      }
    )
    tournament_monitor.save!
    
    Rails.logger.info "[prepare_group_mapping] Saved #{group_options.count} groupItemId mappings to tournament_monitor[#{tournament_monitor.id}].data"
    Rails.logger.info "[prepare_group_mapping] Mappings: #{group_options.inspect}"

    # Für Rückwärtskompatibilität: Versuche auch GroupCc zu erstellen (nur auf API-Server)
    # Auf lokalen Servern wird das fehlschlagen, aber das ist OK
    begin
      branch_cc = self.branch_cc
      if branch_cc.present?
        found_group_cc = self.group_cc || GroupCc.where(branch_cc: branch_cc).find do |gcc|
          positions = gcc.data.is_a?(String) ? JSON.parse(gcc.data) : gcc.data
          positions = positions["positions"] if positions.is_a?(Hash)
          positions.is_a?(Hash) && positions.values.sort == group_options.values.sort
        end

        unless found_group_cc
          plan_name = name || "Unknown Plan"
          region = tournament.organizer
          region_cc = region.region_cc if region.present?
          context = region_cc&.context || branch_cc.region_cc&.context || "nbv"
          
          found_group_cc = GroupCc.create!(
            context: context,
            name: plan_name,
            display: "Gruppen",
            status: "Freigegeben",
            branch_cc_id: branch_cc.id,
            data: { "positions" => group_options }.to_json
          )
          Rails.logger.info "[prepare_group_mapping] Created GroupCc[#{found_group_cc.id}] for tournament_cc[#{id}]"
        end

        update(group_cc: found_group_cc) unless group_cc_id == found_group_cc.id
      end
    rescue StandardError => e
      # Auf lokalen Servern wird das fehlschlagen (LocalProtector), das ist OK
      Rails.logger.debug "[prepare_group_mapping] Could not create/update GroupCc (expected on local servers): #{e.message}"
    end

    true
  end

  # Validiert, ob alle game.gname aus executor_params ein Mapping in GroupCc haben
  # Gibt Hash zurück: {missing: [...], mapped: [...]}
  def validate_game_gname_mapping
    return { missing: [], mapped: [] } unless tournament.present? && tournament.tournament_plan.present?

    group_cc = self.group_cc
    return { missing: [], mapped: [], error: "GroupCc not found" } unless group_cc.present?

    # Extrahiere positions aus GroupCc
    positions_data = group_cc.data.is_a?(String) ? JSON.parse(group_cc.data) : group_cc.data
    positions = positions_data["positions"] || {}
    cc_names = positions.values

    # Extrahiere game.gname aus executor_params
    executor_params = JSON.parse(tournament.tournament_plan.executor_params)
    game_gnames = []

    executor_params.each_key do |k|
      next unless (m = k.match(/g(\d+)/))

      group_no = m[1].to_i
      # Erstelle gname-Patterns wie "group1:1-2", "group2:1-3", etc.
      # (basierend auf der Struktur in tournament_monitor_state.rb)
      sequence = executor_params[k]["sq"]
      if sequence.is_a?(Hash)
        sequence.each do |_round_key, round_data|
          next unless round_data.is_a?(Hash)

          round_data.each do |_tno_str, game_pair|
            if game_pair.is_a?(String) && /(\d+)-(\d+)/.match?(game_pair)
              game_gnames << "group#{group_no}:#{game_pair}"
            end
          end
        end
      end
    end

    # Prüfe Mapping für jeden gname
    missing = []
    mapped = []

    game_gnames.each do |gname|
      # Mappe gname zu CC-Name
      cc_name = Setting.map_game_gname_to_cc_group_name(gname)
      
      if cc_name.present? && cc_names.include?(cc_name)
        mapped << { gname: gname, cc_name: cc_name }
      else
        missing << { gname: gname, cc_name: cc_name }
      end
    end

    { missing: missing, mapped: mapped, total: game_gnames.count }
  end
end
