require "open-uri"
require "uri"
require "net/http"

# == Schema Information
#
# Table name: settings
#
#  id            :bigint           not null, primary key
#  data          :text
#  state         :string
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  club_id       :integer
#  region_id     :integer
#  tournament_id :integer
#
# Foreign Keys
#
#  fk_rails_...  (club_id => clubs.id)
#  fk_rails_...  (region_id => regions.id)
#  fk_rails_...  (tournament_id => tournaments.id)
#
class Setting < ApplicationRecord
  # acts_as_singleton
  serialize :data, coder: JSON, type: Hash
  attr_reader :key
  attr_reader :value

  belongs_to :region, optional: true
  belongs_to :club, optional: true
  belongs_to :tournament, optional: true

  before_save do
    # Rails.logger.info "!!!!!!!" + JSON.pretty_generate(self.attributes)
  end

  SETTING = Setting.first || Setting.create!
  MIN_ID = 50_000_000

  include AASM
  include ActiveModel::Model
  include ActiveModel::Attributes

  aasm column: "state" do
    state :startup, initial: true
    state :ready
    state :maintenance
  end

  def self.instance
    SETTING
  end

  # Holt ClubCloud Credentials aus Rails Credentials (lokal, verschlüsselt)
  # Fallback auf RegionCc für Rückwärtskompatibilität
  #
  # Rails Credentials Format (config/credentials/development.yml.enc oder production.yml.enc):
  #   clubcloud:
  #     nbv:
  #       username: "your-email@example.com"
  #       password: "your-password"
  #     dbu:
  #       username: "..."
  #       password: "..."
  #
  # Verwendung:
  #   credentials = Setting.get_cc_credentials("nbv")
  #   # => { username: "...", password: "..." }
  def self.get_cc_credentials(context)
    context_key = context.to_s.downcase.to_sym
    
    # Primär: Aus Rails Credentials (lokal, verschlüsselt, nicht synchronisiert)
    if Rails.application.credentials.clubcloud.present?
      cc_config = Rails.application.credentials.clubcloud[context_key]
      if cc_config.present?
        Rails.logger.debug "[get_cc_credentials] Using credentials from Rails Credentials for context: #{context}"
        return {
          username: cc_config[:username],
          password: cc_config[:password]
        }
      end
    end
    
    # Fallback: Aus RegionCc (für Rückwärtskompatibilität, aber nicht empfohlen)
    region = Region.find_by(shortname: context.upcase)
    if region&.region_cc.present?
      region_cc = region.region_cc
      if region_cc.username.present? && region_cc.userpw.present?
        Rails.logger.warn "[get_cc_credentials] WARNING: Using credentials from RegionCc (deprecated). Please move to Rails Credentials for security."
        return {
          username: region_cc.username,
          password: region_cc.userpw
        }
      end
    end
    
    # Keine Credentials gefunden
    Rails.logger.error "[get_cc_credentials] No ClubCloud credentials found for context: #{context}"
    Rails.logger.error "[get_cc_credentials] Please configure in Rails Credentials: rails credentials:edit --environment #{Rails.env}"
    { username: nil, password: nil }
  end

  def self.login_to_cc
    opts = RegionCcAction.get_base_opts_from_environment
    region = Region.find_by(shortname: opts[:context].upcase)
    raise "Region not found for context: #{opts[:context]}" unless region

    region_cc = region.region_cc
    raise "RegionCc not found for region: #{region.shortname}" unless region_cc
    raise "RegionCc base_url not set for region: #{region.shortname}" unless region_cc.base_url.present?
    
    # Hole Credentials aus Rails Credentials (lokal, verschlüsselt) oder als Fallback aus RegionCc
    cc_credentials = get_cc_credentials(opts[:context])
    username = cc_credentials[:username]
    password = cc_credentials[:password]
    
    raise "ClubCloud username not configured for region: #{region.shortname}" unless username.present?
    raise "ClubCloud password not configured for region: #{region.shortname}" unless password.present?

    # Schritt 1: Login-Seite abrufen, um call_police zu bekommen und Session-Cookie zu erhalten
    url = region_cc.base_url + "/index.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30
    http.open_timeout = 10
    req = Net::HTTP::Get.new(uri.request_uri)
    res = http.request(req)
    
    # Extrahiere Session-ID vom ersten Request (wird oft beim ersten Seitenaufruf gesetzt)
    initial_session_id = nil
    initial_cookies = res.get_fields("set-cookie")
    if initial_cookies
      initial_cookies.each do |cookie|
        cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
        if cookie_match
          initial_session_id = cookie_match[1]
          Rails.logger.debug "Found initial session ID: #{initial_session_id}"
          break
        end
      end
    end
    
    # Prüfe auf Redirects
    if res.is_a?(Net::HTTPRedirection)
      redirect_url = res['location']
      Rails.logger.warn "Login page redirected to: #{redirect_url}"
      # Versuche die Redirect-URL
      redirect_uri = URI(redirect_url)
      if redirect_uri.relative?
        redirect_uri = URI.join(url, redirect_url)
      end
      http = Net::HTTP.new(redirect_uri.host, redirect_uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.read_timeout = 30
      http.open_timeout = 10
      req = Net::HTTP::Get.new(redirect_uri.request_uri)
      # Setze Cookie vom ersten Request
      req["cookie"] = "PHPSESSID=#{initial_session_id}" if initial_session_id
      res = http.request(req)
      
      # Prüfe auf neue Session-ID nach Redirect
      redirect_cookies = res.get_fields("set-cookie")
      if redirect_cookies
        redirect_cookies.each do |cookie|
          cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
          if cookie_match
            initial_session_id = cookie_match[1]
            break
          end
        end
      end
    end
    
    unless res.is_a?(Net::HTTPSuccess)
      raise "Failed to fetch login page: #{res.class} - #{res.message} (Status: #{res.code})"
    end

    unless res.body.present?
      raise "Login page response is empty (Status: #{res.code})"
    end

    doc = Nokogiri::HTML(res.body)
    unless doc
      raise "Failed to parse login page HTML"
    end

    call_police_input = doc.css("input[name=\"call_police\"]")[0]
    unless call_police_input
      Rails.logger.warn "call_police input not found in login page, using 0"
    end
    call_police = call_police_input&.[]("value")&.to_i || 0

    # Schritt 2: Login-Daten direkt senden an /login/checkUser.php (nicht /index.php!)
    userpw = password
    
    # Prüfe ob Passwort bereits URL-decoded ist (falls es in DB encoded gespeichert ist)
    # Versuche zu decodieren, falls es encoded ist
    begin
      decoded_pw = URI.decode_www_form_component(userpw)
      if decoded_pw != userpw
        Rails.logger.debug "Password was URL-encoded, decoded it"
        userpw = decoded_pw
      end
    rescue
      # Falls Decoding fehlschlägt, verwende Original
    end
    
    md5pw = Digest::MD5.hexdigest(userpw)
    
    # WICHTIG: Login-URL ist /login/checkUser.php, nicht /index.php!
    login_url = region_cc.base_url + "/login/checkUser.php"
    login_uri = URI(login_url)
    
    # Debug: Zeige Login-Parameter (ohne Passwort)
    Rails.logger.debug "Login attempt - URL: #{login_url}, username: #{username}, call_police: #{call_police}, has_session: #{initial_session_id.present?}, pw_length: #{userpw.length}"
    
    login_http = Net::HTTP.new(login_uri.host, login_uri.port)
    login_http.use_ssl = true
    login_http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    login_http.read_timeout = 30
    login_http.open_timeout = 10
    
    login_req = Net::HTTP::Post.new(login_uri.request_uri)
    login_req["Content-Type"] = "application/x-www-form-urlencoded"
    login_req["referer"] = login_url  # Referer sollte auf checkUser.php zeigen
    login_req["User-Agent"] = "Mozilla/5.0 (compatible; Carambus/1.0)"
    login_req["Origin"] = region_cc.base_url.chomp("/")
    login_req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
    login_req["Accept-Language"] = "de-DE,de;q=0.9,en-US;q=0.8,en;q=0.7"
    
    # WICHTIG: Setze Cookie vom ersten Request, damit Session beibehalten wird
    # Falls keine Session-ID gefunden wurde, versuchen wir trotzdem den Login
    # (die Session-ID wird möglicherweise erst beim Login gesetzt)
    if initial_session_id
      login_req["cookie"] = "PHPSESSID=#{initial_session_id}"
      Rails.logger.debug "Using session ID from initial request: #{initial_session_id}"
    else
      Rails.logger.warn "No session ID found from initial request - proceeding without cookie (session may be set during login)"
    end
    
    # Erstelle Form-Daten - set_form_data kodiert automatisch
    form_data = {
      username: username,
      userpassword: md5pw,
      call_police: call_police.to_s,
      loginUser: username,
      userpw: userpw,  # Klartext-Passwort (wird von set_form_data kodiert)
      loginButton: "ANMELDEN"
    }
    
    # Manuell Form-Daten erstellen, um mehr Kontrolle zu haben
    form_string = form_data.map { |k, v| "#{URI.encode_www_form_component(k.to_s)}=#{URI.encode_www_form_component(v.to_s)}" }.join("&")
    login_req.body = form_string
    
    Rails.logger.debug "Login form data (without password): #{form_data.except(:userpw, :userpassword).inspect}"
    
    login_res = login_http.request(login_req)
    
    # Prüfe auf Redirects nach Login (Redirect ist oft ein Zeichen für erfolgreichen Login)
    if login_res.is_a?(Net::HTTPRedirection)
      redirect_url = login_res['location']
      Rails.logger.info "Login response is redirect to: #{redirect_url}"
      
      # Extrahiere Session-ID aus dem Redirect-Response
      redirect_cookies = login_res.get_fields("set-cookie")
      if redirect_cookies
        redirect_cookies.each do |cookie|
          cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
          if cookie_match
            session_id = cookie_match[1]
            Setting.key_set_value("session_id", session_id)
            Rails.logger.info "Successfully logged in to ClubCloud (via redirect), session_id: #{session_id}"
            return session_id
          end
        end
      end
      
      # Falls keine Session-ID im Redirect, verwende die initiale (falls vorhanden)
      if initial_session_id
        Setting.key_set_value("session_id", initial_session_id)
        Rails.logger.info "Successfully logged in to ClubCloud (via redirect, using initial session), session_id: #{initial_session_id}"
        return initial_session_id
      else
        # Keine Session-ID gefunden - das ist problematisch, aber versuchen wir trotzdem
        Rails.logger.warn "Login redirect but no session ID found - login may have failed"
      end
    end

    unless login_res.is_a?(Net::HTTPSuccess)
      raise "Login failed: #{login_res.class} - #{login_res.message} (Status: #{login_res.code})"
    end

    # Schritt 3: Session-ID aus Set-Cookie Header extrahieren
    session_id = nil
    
    # Debug: Zeige alle Set-Cookie Header
    all_cookies = login_res.get_fields("set-cookie")
    Rails.logger.debug "Set-Cookie headers: #{all_cookies.inspect}" if all_cookies
    
    # Prüfe ob Login erfolgreich war (wenn Response noch Login-Seite ist, war Login fehlgeschlagen)
    login_doc = Nokogiri::HTML(login_res.body)
    still_login_page = login_doc.css("input[name=\"call_police\"]").present? || 
                       login_doc.css("input[name=\"loginButton\"]").present? ||
                       login_doc.css("form").any? { |f| f["action"]&.include?("index.php") }
    
    if still_login_page
      # Login-Seite wird noch angezeigt - Login war nicht erfolgreich
      # Suche nach Fehlermeldungen im HTML
      error_messages = []
      
      # Verschiedene Selektoren für Fehlermeldungen
      error_selectors = [
        ".error", ".alert", ".warning", ".danger",
        "[class*='error']", "[class*='alert']", "[class*='warning']",
        "div[style*='color: red']", "div[style*='color:red']",
        "font[color='red']", "span[style*='color: red']",
        "td[style*='color: red']", "td[style*='color:red']"
      ]
      
      error_selectors.each do |selector|
        login_doc.css(selector).each do |elem|
          text = elem.text.strip
          error_messages << text if text.present? && text.length < 200
        end
      end
      
      # Suche auch nach Text-Inhalten, die auf Fehler hindeuten
      body_text = login_doc.text
      if body_text.match(/falsch|ungültig|fehler|error|invalid|wrong/i)
        error_messages << "Page contains error-related text"
      end
      
      # Prüfe auch den Titel der Seite
      page_title = login_doc.css("title").text
      if page_title.include?("Anmeldung") || page_title.include?("Login")
        error_messages << "Page title still shows login page: #{page_title}"
      end
      
      # Extrahiere alle Text-Inhalte aus dem Body für bessere Analyse
      all_text = login_doc.css("body").text.gsub(/\s+/, " ").strip[0..500]
      
      # Debug: Zeige einen Teil des HTML-Body und Formular-Felder
      Rails.logger.error "Login failed - Response analysis:"
      Rails.logger.error "  Status: #{login_res.code}"
      Rails.logger.error "  Title: #{page_title}"
      Rails.logger.error "  Form fields found: #{login_doc.css('form input').map { |i| i['name'] }.compact.join(', ')}"
      Rails.logger.error "  Body text preview: #{all_text}"
      
      # Prüfe ob das Formular noch vorhanden ist und welche Felder es hat
      forms = login_doc.css("form")
      if forms.any?
        forms.each do |form|
          Rails.logger.error "  Form action: #{form['action']}, method: #{form['method']}"
          form.css("input").each do |input|
            Rails.logger.error "    Input: name=#{input['name']}, type=#{input['type']}, value=#{input['value']&.[](0..20)}"
          end
        end
      end
      
      if error_messages.any?
        raise "Login failed: #{error_messages.uniq.join('; ')}"
      else
        # Prüfe ob es vielleicht ein Redirect gibt, den wir verpasst haben
        if login_res.is_a?(Net::HTTPRedirection)
          raise "Login failed: Got redirect to #{login_res['location']} - might need to follow redirect"
        else
          raise "Login failed: Still showing login page. Check username/password. Response status: #{login_res.code}, Body length: #{login_res.body.length}. Form fields: #{login_doc.css('form input').map { |i| i['name'] }.compact.join(', ')}"
        end
      end
    end
    
    # Versuche Session-ID aus dem Set-Cookie Header zu extrahieren (beste Methode)
    if login_res["set-cookie"]
      cookie_match = login_res["set-cookie"].match(/PHPSESSID=([a-f0-9]+)/i)
      session_id = cookie_match[1] if cookie_match
    end

    # Fallback: Versuche Session-ID aus allen Cookies im Set-Cookie Header
    unless session_id
      cookies = login_res.get_fields("set-cookie")
      if cookies
        cookies.each do |cookie|
          # Prüfe verschiedene Cookie-Formate
          cookie_match = cookie.match(/PHPSESSID=([a-f0-9]+)/i)
          if cookie_match
            session_id = cookie_match[1]
            Rails.logger.debug "Found session ID in cookie: #{session_id}"
            break
          end
          # Auch nach PHPSESSID ohne Wert suchen (falls anders formatiert)
          if cookie.include?("PHPSESSID")
            Rails.logger.debug "Cookie contains PHPSESSID but format unclear: #{cookie}"
          end
        end
      end
    end
    
    # Fallback: Verwende Session-ID vom ersten Request (wenn keine neue gesetzt wurde)
    unless session_id
      if initial_session_id
        session_id = initial_session_id
        Rails.logger.debug "Using initial session ID: #{session_id}"
      end
    end

    # Fallback: Versuche Session-ID aus JavaScript im HTML zu extrahieren
    unless session_id
      login_doc = Nokogiri::HTML(login_res.body)
      # Verschiedene Patterns für Session-ID im JavaScript
      patterns = [
        /PHPSESSID['"]?\s*[:=]\s*['"]([a-f0-9]+)['"]/i,
        /PHPSESSID=([a-f0-9]+)/i,
        /session[_-]?id['"]?\s*[:=]\s*['"]([a-f0-9]+)['"]/i
      ]
      
      patterns.each do |pattern|
        session_match = login_doc.css("script").text.match(pattern)
        if session_match
          session_id = session_match[1]
          Rails.logger.debug "Found session ID in JavaScript: #{session_id}"
          break
        end
      end
    end

    # Fallback: Suche im gesamten HTML-Body
    unless session_id
      login_doc = Nokogiri::HTML(login_res.body)
      body_text = login_doc.text
      session_match = body_text.match(/PHPSESSID[=:]\s*([a-f0-9]{32,})/i)
      if session_match
        session_id = session_match[1]
        Rails.logger.debug "Found session ID in body text: #{session_id}"
      end
    end

    # Fallback: Prüfe ob Login erfolgreich war (vielleicht ist Session in URL oder Form)
    unless session_id
      login_doc = Nokogiri::HTML(login_res.body)
      # Prüfe ob es ein Formular mit verstecktem Session-Feld gibt
      session_input = login_doc.css("input[name*='session'], input[name*='PHPSESSID'], input[value*='PHPSESSID']").first
      if session_input
        session_id = session_input["value"]&.match(/([a-f0-9]{32,})/i)&.[](1)
        Rails.logger.debug "Found session ID in form input: #{session_id}" if session_id
      end
    end

    unless session_id
      # Debug-Informationen für Fehleranalyse
      debug_info = {
        status: login_res.code,
        message: login_res.message,
        set_cookie: login_res["set-cookie"],
        all_cookies: all_cookies,
        body_length: login_res.body.length,
        body_preview: login_res.body[0..500]
      }
      Rails.logger.error "Login response debug info: #{debug_info.inspect}"
      raise "Could not extract session ID from login response. Status: #{login_res.code}, Set-Cookie: #{login_res['set-cookie'] || '(none)'}, All cookies: #{all_cookies.inspect}, Response body length: #{login_res.body.length}"
    end
    Setting.key_set_value("session_id", session_id)
    Rails.logger.info "Successfully logged in to ClubCloud, session_id: #{session_id}"
    session_id
  end

  def self.logoff_from_cc
    opts = RegionCcAction.get_base_opts_from_environment
    region = Region.find_by(shortname: opts[:context].upcase)
    raise "Region not found for context: #{opts[:context]}" unless region

    region_cc = region.region_cc
    raise "RegionCc not found for region: #{region.shortname}" unless region_cc

    session_id = opts[:session_id] || Setting.key_get_value("session_id")
    unless session_id
      Rails.logger.warn "No session ID found, already logged off?"
      return true
    end

    # Logoff direkt senden (ohne post_cc, da logoff nicht in PATH_MAP ist)
    url = region_cc.base_url + "/index.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Post.new(uri.request_uri)
    req["cookie"] = "PHPSESSID=#{session_id}"
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req["referer"] = url
    req.set_form_data(logoff: "ABMELDEN")
    res = http.request(req)

    Setting.key_delete("session_id")
    if res&.message == "OK"
      Rails.logger.info "Successfully logged off from ClubCloud"
      true
    else
      Rails.logger.warn "Logoff response: #{res&.message}"
      true # Auch bei Fehler als erfolgreich betrachten (Session wird gelöscht)
    end
  end

  # Prüft, ob die aktuelle Session noch gültig ist
  # Ruft eine geschützte Seite auf und prüft, ob wir noch eingeloggt sind
  def self.validate_session(session_id = nil)
    return false unless session_id.present? || Setting.key_get_value("session_id").present?
    
    session_id ||= Setting.key_get_value("session_id")
    opts = RegionCcAction.get_base_opts_from_environment
    region = Region.find_by(shortname: opts[:context].upcase)
    return false unless region&.region_cc&.base_url.present?

    region_cc = region.region_cc
    
    # Versuche eine Admin-Seite aufzurufen (z.B. die Hauptseite nach Login)
    url = region_cc.base_url + "/admin/index.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 10
    http.open_timeout = 5
    
    req = Net::HTTP::Get.new(uri.request_uri)
    req["cookie"] = "PHPSESSID=#{session_id}"
    res = http.request(req)
    
    # Wenn wir zur Login-Seite redirected werden oder die Login-Seite sehen, ist Session ungültig
    if res.is_a?(Net::HTTPRedirection)
      redirect_url = res['location']
      if redirect_url&.include?("index.php") && !redirect_url&.include?("admin")
        Rails.logger.debug "Session invalid: Redirected to login page"
        return false
      end
    end
    
    if res.is_a?(Net::HTTPSuccess)
      doc = Nokogiri::HTML(res.body)
      # Prüfe ob Login-Formular vorhanden (= nicht eingeloggt)
      has_login_form = doc.css("input[name='call_police']").any? || 
                       doc.css("input[name='loginUser']").any? ||
                       doc.css("title").text.include?("Anmeldung")
      
      if has_login_form
        Rails.logger.debug "Session invalid: Login form detected"
        return false
      end
      
      Rails.logger.debug "Session valid: Admin page accessible"
      return true
    end
    
    Rails.logger.warn "Session validation inconclusive: #{res.class} #{res.code}"
    false
  rescue StandardError => e
    Rails.logger.error "Error validating session: #{e.message}"
    false
  end

  # Login mit automatischem Logout-Retry bei Fehler
  # Wenn Login fehlschlägt, wird erst ein Logout versucht, dann erneut Login
  def self.login_with_retry(max_retries: 1)
    attempt = 0
    last_error = nil
    
    loop do
      attempt += 1
      
      begin
        Rails.logger.info "[login_with_retry] Attempt #{attempt}/#{max_retries + 1}"
        session_id = login_to_cc
        
        # Validiere Session nach Login
        if validate_session(session_id)
          Rails.logger.info "[login_with_retry] Login successful and validated"
          return session_id
        else
          raise "Session validation failed after login"
        end
        
      rescue StandardError => e
        last_error = e
        Rails.logger.error "[login_with_retry] Login attempt #{attempt} failed: #{e.message}"
        
        if attempt <= max_retries
          Rails.logger.info "[login_with_retry] Attempting logout before retry..."
          begin
            logoff_from_cc
            sleep 1 # Kurze Pause nach Logout
          rescue StandardError => logout_error
            Rails.logger.warn "[login_with_retry] Logout failed (continuing anyway): #{logout_error.message}"
          end
        else
          Rails.logger.error "[login_with_retry] Max retries (#{max_retries}) reached, giving up"
          raise last_error
        end
      end
    end
  end

  # Stellt sicher, dass wir eingeloggt sind (mit Session-Validierung)
  # Ruft login_with_retry auf wenn nötig
  def self.ensure_logged_in
    session_id = Setting.key_get_value("session_id")
    
    # Wenn keine Session vorhanden: Login
    unless session_id.present?
      Rails.logger.info "[ensure_logged_in] No session found, logging in..."
      return login_with_retry
    end
    
    # Session vorhanden: Validiere sie
    if validate_session(session_id)
      Rails.logger.debug "[ensure_logged_in] Existing session is valid"
      return session_id
    end
    
    # Session ungültig: Logout + Login
    Rails.logger.info "[ensure_logged_in] Session invalid, re-logging in..."
    begin
      logoff_from_cc
    rescue StandardError => e
      Rails.logger.warn "[ensure_logged_in] Logout failed (continuing): #{e.message}"
    end
    
    login_with_retry
  end

  # Mappt game.gname (z.B. "group1:1-2", "Runde 1", "Finale") zu einem ClubCloud-Gruppennamen
  def self.map_game_gname_to_cc_group_name(gname)
    return nil unless gname.present?

    # Normalisiere gname
    normalized = gname.strip

    # Prüfe zuerst groups-Mapping
    GroupCc::NAME_MAPPING[:groups].each do |pattern, mapped_name|
      if pattern.start_with?("/") && pattern.end_with?("/")
        # Regex-Pattern
        regex = Regexp.new(pattern[1..-2])
        return mapped_name if regex.match?(normalized)
      elsif normalized == pattern || normalized.include?(pattern)
        return mapped_name
      end
    end

    # Prüfe round-Mapping
    GroupCc::NAME_MAPPING[:round].each do |pattern, mapped_name|
      if normalized == pattern || normalized.include?(pattern)
        return mapped_name
      end
    end

    # Fallback: Versuche aus gname zu extrahieren
    if (m = normalized.match(/group(\d+)/i))
      group_no = m[1].to_i
      return "Gruppe #{group_no}"
    end

    # Wenn nichts gefunden, gib nil zurück
    Rails.logger.warn "Could not map game.gname '#{gname}' to ClubCloud group name"
    nil
  end

  # Findet die groupItemId direkt aus game.gname
  # Verwendet tournament.group_cc.data["positions"]
  def self.find_group_item_id_from_gname(game_gname, tournament = nil)
    return nil unless game_gname.present? && tournament.present?

    tournament_cc = tournament.tournament_cc
    return nil unless tournament_cc.present?

    group_cc = tournament_cc.group_cc
    return nil unless group_cc.present?

    # Prüfe ob group_cc.data["positions"] existiert
    positions_data = group_cc.data
    positions = positions_data.is_a?(String) ? JSON.parse(positions_data) : positions_data
    positions = positions["positions"] if positions.is_a?(Hash) && positions["positions"].present?

    return nil unless positions.is_a?(Hash)

    # Mappe game.gname zu CC-Gruppennamen
    cc_group_name = map_game_gname_to_cc_group_name(game_gname)
    return nil unless cc_group_name.present?

    # Suche nach dem Gruppennamen in positions
    positions.each do |group_item_id, name|
      return group_item_id.to_i if name == cc_group_name || name.include?(cc_group_name) || cc_group_name.include?(name)
    end

    Rails.logger.warn "Could not find groupItemId for game.gname '#{game_gname}' (mapped to '#{cc_group_name}') in tournament_cc[#{tournament_cc.id}]"
    nil
  end

  # Findet die groupItemId für einen ClubCloud-Gruppennamen
  # Verwendet tournament.group_cc.data["positions"]
  def self.find_group_item_id(tournament, cc_group_name)
    return nil unless cc_group_name.present? && tournament.present?

    tournament_cc = tournament.tournament_cc
    return nil unless tournament_cc.present?

    group_cc = tournament_cc.group_cc
    return nil unless group_cc.present?

    # Prüfe ob group_cc.data["positions"] existiert
    positions_data = group_cc.data
    positions = positions_data.is_a?(String) ? JSON.parse(positions_data) : positions_data
    positions = positions["positions"] if positions.is_a?(Hash) && positions["positions"].present?

    return nil unless positions.is_a?(Hash)

    # Suche nach dem Gruppennamen in positions
    positions.each do |group_item_id, name|
      return group_item_id.to_i if name == cc_group_name || name.include?(cc_group_name) || cc_group_name.include?(name)
    end

    Rails.logger.warn "Could not find groupItemId for group name '#{cc_group_name}' in tournament_cc[#{tournament_cc.id}]"
    nil
  end

  # Trägt ein Spiel automatisch in die ClubCloud ein
  def self.upload_game_to_cc(table_monitor)
    return false unless table_monitor.present?

    game = table_monitor.game
    return false unless game.present?

    tournament = game.tournament
    return false unless tournament.present?

    tournament_cc = tournament.tournament_cc
    return false unless tournament_cc.present?

    # Prüfe ob TournamentCc konfiguriert ist
    region = tournament.organizer
    return false unless region.present?

    region_cc = region.region_cc
    return false unless region_cc.present? && region_cc.base_url.present?

    # Stelle sicher, dass wir eingeloggt sind (mit Session-Validierung)
    begin
      session_id = Setting.ensure_logged_in
    rescue StandardError => e
      Rails.logger.error "Failed to ensure ClubCloud login: #{e.message}"
      return false
    end

    # Extrahiere Spieldaten
    ba_results = table_monitor.data["ba_results"] || game.data["ba_results"]
    return false unless ba_results.present?

    # Finde groupItemId direkt aus game.gname (verwendet CC: UNIVERSAL Mapping wenn verfügbar)
    group_item_id = find_group_item_id_from_gname(game.gname, tournament)
    unless group_item_id
      Rails.logger.warn "Could not find groupItemId for game[#{game.id}], gname: #{game.gname}"
      return false
    end

    # Hole Spieler
    gp1 = game.game_participations.where(role: %w[playera Heim]).first
    gp2 = game.game_participations.where(role: %w[playerb Gast]).first
    return false unless gp1.present? && gp2.present?

    player1 = gp1.player
    player2 = gp2.player
    return false unless player1.present? && player2.present?

    # Hole ClubCloud-IDs (cc_id oder ba_id als Fallback)
    sportler_one_id = player1.cc_id || player1.ba_id
    sportler_two_id = player2.cc_id || player2.ba_id
    return false unless sportler_one_id.present? && sportler_two_id.present?

    # Extrahiere Spieldaten
    partie_number = ba_results["Partie"] || game.seqno || 1
    set_number = ba_results["SetNo"] || 1
    homescore = ba_results["Ergebnis1"] || gp1.result || 0
    visitorscore = ba_results["Ergebnis2"] || gp2.result || 0
    homeinning = ba_results["Aufnahmen1"] || gp1.innings || 0
    visitorinning = ba_results["Aufnahmen2"] || gp2.innings || 0
    homebreak = ba_results["Höchstserie1"] || gp1.hs || 0
    visitorbreak = ba_results["Höchstserie2"] || gp2.hs || 0

    # Hole Tournament-Parameter
    branch_cc = tournament_cc.branch_cc
    return false unless branch_cc.present?

    # Erstelle Formular-Daten
    form_data = {
      fedId: region.cc_id,
      branchId: branch_cc.cc_id,
      disciplinId: "*",
      season: tournament.season.name,
      catId: "*",
      meisterTypeId: tournament_cc.championship_type_cc&.cc_id || "",
      meisterschaftsId: tournament_cc.cc_id,
      teilnehmerId: "*",
      groupItemId: group_item_id,
      partieNumber: partie_number.to_s,
      setNumber: set_number.to_s,
      sportlerOne: sportler_one_id.to_s,
      sportlerTwo: sportler_two_id.to_s,
      homescore: homescore.to_s,
      visitorscore: visitorscore.to_s,
      homeinning: homeinning.to_s,
      visitorinning: visitorinning.to_s,
      homebreak: homebreak.to_s,
      visitorbreak: visitorbreak.to_s
    }

    # Sende POST-Request an createErgebnisSave.php
    url = region_cc.base_url + "/admin/einzel/meisterschaft/createErgebnisSave.php"
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30
    http.open_timeout = 10

    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/x-www-form-urlencoded"
    req["cookie"] = "PHPSESSID=#{session_id}"
    req["referer"] = region_cc.base_url + "/admin/einzel/meisterschaft/showErgebnisliste.php"
    req["User-Agent"] = "Mozilla/5.0 (compatible; Carambus/1.0)"
    req["Origin"] = region_cc.base_url
    req["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"

    req.set_form_data(form_data)
    res = http.request(req)

    if res.is_a?(Net::HTTPSuccess) || res.is_a?(Net::HTTPRedirection)
      Rails.logger.info "Successfully uploaded game[#{game.id}] to ClubCloud (Status: #{res.code})"
      return true
    else
      Rails.logger.error "Failed to upload game[#{game.id}] to ClubCloud (Status: #{res.code}, Message: #{res.message})"
      Rails.logger.error "Response body preview: #{res.body[0..500]}" if res.body.present?
      return false
    end
  rescue StandardError => e
    Rails.logger.error "Error uploading game[#{game&.id}] to ClubCloud: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    false
  end

  def self.key_set_value(k, v)
    return nil unless %w[session_id last_version_id scenario_name].include?(k.to_s)
    Setting.transaction do
      inst = instance.reload
      hash = inst.data
      hash[k.to_s] = { v.class.name => v.to_s }
      inst.data_will_change!
      inst.update(data: hash)
    end
  end

  def self.get_keys
    Setting.instance.data.keys
  end

  def self.key_delete(k)
    Setting.transaction do
      inst = Setting.instance
      hash = inst.data
      hash.delete(k.to_s)
      inst.data_will_change!
      inst.update(data: hash)
    rescue StandardError
      return nil
    end
  end

  def self.key_get_value(k)
    return nil unless %w[session_id last_version_id scenario_name].include?(k.to_s)
    inst = instance.reload
    hash = inst.data
    return nil unless hash[k.to_s].present?
    _type, val = inst.data[k.to_s].to_a.flatten
    val
  end

  def self.get_carambus_api_token
    expire_str = Setting.key_get_value("carambus_api_token_expire_at")
    if expire_str.blank? || Time.parse(expire_str) < Time.now
      url = URI("https://dev-r4djmvaa.eu.auth0.com/oauth/token")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      request = Net::HTTP::Post.new(url)
      request["content-type"] = "application/json"
      request.body = "{\"client_id\":\"aqAJY7zNMsw0jiThccQyKOO1WyjKP0AC\",\"client_secret\":\"7PN4bsl0tikD8fylkoOY_j2RudtlayXVCI0SlPzG2Tfr7ewLUETiEYHFwVL9Rk1Q\",\"audience\":\"https://api.carambus.de\",\"grant_type\":\"client_credentials\"}"
      response = http.request(request)
      return [] unless response.message == "OK"

      resp = JSON.parse(response.read_body)
      access_token = resp["access_token"]
      token_type = resp["token_type"]
      Rails.logger.info "access_token: #{access_token} token_type: #{token_type}"

      Setting.key_set_value("carambus_api_access_token", access_token)
      Setting.key_set_value("carambus_api_token_type", token_type)
      Setting.key_set_value("carambus_api_token_expire_at", Time.now + 36_000.seconds)

    else
      access_token = Setting.key_get_value("carambus_api_access_token")
      token_type = Setting.key_get_value("carambus_api_token_type")
    end
    [access_token, token_type]
  end
end
