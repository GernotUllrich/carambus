# frozen_string_literal: true

# Syncer fuer Meldelisten-Daten aus dem ClubCloud-System.
# Extrahiert aus RegionCc: sync_registration_list_ccs und sync_registration_list_ccs_detail.
#
# Verwendung:
#   RegionCc::RegistrationSyncer.call(
#     region_cc: region_cc, client: client,
#     operation: :sync_registration_list_ccs_detail,
#     season: season, branch_cc: branch_cc
#   )
class RegionCc::RegistrationSyncer < ApplicationService
  def initialize(options = {})
    @region_cc = options.fetch(:region_cc)
    @client = options.fetch(:client)
    @operation = options.fetch(:operation)
    @season = options[:season]
    @branch_cc = options[:branch_cc]
    @opts = options.except(:region_cc, :client, :operation, :season, :branch_cc)
  end

  def call
    case @operation
    when :sync_registration_list_ccs then sync_registration_list_ccs
    when :sync_registration_list_ccs_detail then sync_registration_list_ccs_detail(@season, @branch_cc)
    else raise ArgumentError, "Unknown operation: #{@operation}"
    end
  end

  private

  def sync_registration_list_ccs
    region = Region.find_by_shortname(@opts[:context].upcase)
    season = Season.find_by_name(@opts[:season_name])
    region_cc = region.region_cc
    if @opts[:branch_cc_cc_id].present?
      branch_cc = BranchCc.find_by_cc_id(@opts[:branch_cc_cc_id].to_i)
      sync_registration_list_ccs_detail(season, branch_cc) if branch_cc.present?
    else
      region_cc.branch_ccs.each do |branch_cc|
        sync_registration_list_ccs_detail(season, branch_cc)
      end
    end
  end

  def sync_registration_list_ccs_detail(season, branch_cc)
    context = @opts[:context]
    _, doc = @client.post("showMeldelistenList",
      {fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", catId: "*", season: season.name}, @opts)

    # Plan 21-13 T3: ClubCloud V2 UI liefert Meldelisten als <table>-Rows
    # statt <select>-Options. Alle benötigten Felder (Name/Disziplin/Datum1/
    # Kategorie/Datum2/Status) sind direkt in der Liste enthalten — separater
    # showMeldeliste-Detail-Call entfällt für basic-sync (deadline/qualifying_date
    # aus den Cells extrahiert, Discipline/Category-Lookup unverändert).
    # Format pro Row (7 cells, Browser-Trace 2026-05-28):
    #   [0] Name | [1] Disziplin | [2] Datum1 (deadline) | [3] Kategorie
    #   [4] Datum2 (qualifying_date) | [5] Status | [6] Anzeigen-Link mit cc_id
    rows = extract_meldeliste_rows(doc)
    rows.each do |row|
      cc_id_ml = row[:cc_id]
      next if cc_id_ml.blank? || cc_id_ml < 1

      registration_list_cc = RegistrationListCc.find_or_initialize_by(cc_id: cc_id_ml)
      next if !registration_list_cc.new_record? && @opts[:update_from_cc].blank?

      name = row[:name]
      # Status: gsub NBSP-prefix entfernen, dann trimmen (D-21-06-C: persistiere
      # den parsedten Wert, nicht hardcoded "Freigegeben")
      status = row[:status].to_s.gsub(/^ /, "").strip
      deadline = parse_german_date(row[:deadline_raw]) || Date.today
      qualifying_date = parse_german_date(row[:qualifying_date_raw]) || Date.today

      # Discipline-Lookup analog Pre-21-13-Code (Disziplin-Name-Normalisierung)
      d_name = row[:discipline_text].to_s
        .gsub("(großes Billard)", "groß")
        .gsub("(kleines Billard)", "klein")
        .gsub("5-Kegel", "5 Kegel")
        .gsub("14/1 endlos", "14.1 endlos")
        .gsub("15-reds", "Snooker")
        .gsub("Billard Kegeln", "Billard-Kegeln")
      discipline_id = Discipline.find_by_name(d_name).andand.id

      # Category-Lookup analog Pre-21-13-Code (`<Name> (range)`-Pattern)
      category_cc_id = nil
      if (m = row[:category_text].to_s.match(/(.*) \(\d+-\d+\)/))
        category_cc_id = CategoryCc.where(context: context, branch_cc_id: branch_cc.id, name: m[1]).first.andand.id
      end

      begin
        if @opts[:release] && status != "Freigegeben"
          @client.post("releaseMeldeliste",
            {branchId: branch_cc.cc_id, fedId: branch_cc.region_cc.cc_id, season: season.name, meldelisteId: cc_id_ml, release: ""}, @opts)
        end

        # Persistierung-Logik UNVERÄNDERT (Plan 21-13 Boundary: KEINE Schema-/Persist-Änderungen)
        registration_list_cc.update(season_id: season.id, discipline_id: discipline_id, category_cc_id: category_cc_id,
          context: context, branch_cc_id: branch_cc.id, name: name, status: status, deadline: deadline, qualifying_date: qualifying_date)

        # Plan 14-G.14 Task 4b: Auto-Wire — finde matching TournamentCc by name+context und triggere API-Push.
        # Idempotent: nur push wenn registration_list_cc_id geändert wurde.
        link_and_push_if_match(registration_list_cc, context)
      rescue => e
        Rails.logger.error "Error: #{e.message}"
      end
    end
  end

  # Plan 21-13 T3 Helper: Extract Meldeliste-Rows aus showMeldelistenList-HTML.
  # ClubCloud V2 UI Heuristik: das Datentabelle ist die letzte <table> mit > 5 Rows
  # (Browser-Trace 2026-05-28 zeigte 6 Tables; table[5] mit 44 rows = Meldelisten).
  # Defensive: gibt [] zurück wenn keine passende Tabelle gefunden.
  def extract_meldeliste_rows(doc)
    candidate_tables = doc.css("table").select { |t| t.css("tr").length > 5 }
    data_table = candidate_tables.last
    return [] unless data_table

    data_table.css("tr").drop(1).filter_map do |tr|
      cells = tr.css("td")
      next nil if cells.length < 6  # Row hat keine Daten-Struktur (Trenner/Footer)

      # cc_id aus dem Anzeigen-Link; toleriert verschiedene Query-Param-Namen.
      anzeigen_link = tr.css('a[href*="showMeldeliste"]').first
      cc_id = nil
      if anzeigen_link
        href = anzeigen_link["href"].to_s
        if (m = href.match(/[?&]meldelisteId=(\d+)/))
          cc_id = m[1].to_i
        elsif (m = href.match(/[?&]id=(\d+)/))
          cc_id = m[1].to_i
        end
      end
      next nil unless cc_id

      {
        cc_id: cc_id,
        name: cells[0].text.strip,
        discipline_text: cells[1].text.strip,
        deadline_raw: cells[2].text.strip,
        category_text: cells[3].text.strip,
        qualifying_date_raw: cells[4].text.strip,
        status: cells[5].text.strip
      }
    end
  end

  # Plan 21-13 T3 Helper: defensive German-Date-Parsing.
  # Akzeptiert "DD.MM.YYYY" überall in einem Text-Snippet; gibt nil bei Parse-Fehler.
  def parse_german_date(raw)
    return nil unless raw.is_a?(String)
    return nil unless (m = raw.match(/(\d\d\.\d\d\.\d\d\d\d)/))
    Date.parse(m[1])
  rescue ArgumentError, Date::Error
    nil
  end

  def link_and_push_if_match(registration_list_cc, context)
    return unless registration_list_cc.persisted? && registration_list_cc.name.present?

    candidates = TournamentCc.where(context: context, name: registration_list_cc.name)
    candidates.each do |tc|
      next if tc.registration_list_cc_id == registration_list_cc.id  # already linked, skip
      next unless tc.tournament&.region  # need region for push payload

      tc.update_columns(registration_list_cc_id: registration_list_cc.id)
      self.class.push_link_to_api(tc, registration_list_cc)
    end
  rescue => e
    Rails.logger.warn "[Syncer] link_and_push_if_match failed: #{e.class}: #{e.message}"
  end

  class << self
    # Plan 14-G.14 Task 4: Regional→API meldeliste_cc_id-Link-Push
    #
    # Triggert PATCH /api/tournament_ccs/:id/registration_list_link auf carambus_master,
    # damit andere Regional-Server die Verknüpfung via PaperTrail-Pull mitbekommen.
    # Direct-Response-Pattern: API-Antwort wird lokal mit unprotected:true persistiert,
    # umgeht LocalProtector für globale Records (id < MIN_ID).
    #
    # Best-effort: bei Netzwerk-/4xx/5xx-Fehlern log + skip (kein Retry-Storm).
    # Bei 401: Token-Cache invalidieren, 1× Retry mit fresh Token.
    def push_link_to_api(tournament_cc, registration_list_cc)
      return unless Carambus.config.carambus_api_url.present?

      token = api_token
      if token.blank?
        Rails.logger.warn "[Syncer] No API token (api_syncer_email/password missing in credentials?), skipping push"
        return
      end

      body = {
        registration_list_link: {
          meldeliste_cc_id: registration_list_cc.cc_id,
          registration_list_name: registration_list_cc.name,
          region_shortname: tournament_cc.tournament&.region&.shortname,
          branch_cc_id: registration_list_cc.branch_cc_id,
          season: registration_list_cc.season&.name,
          discipline_id: registration_list_cc.discipline_id,
          category_cc_id: registration_list_cc.category_cc_id
        }
      }

      response = http_patch(api_url(tournament_cc), body, token)

      # 401-Retry mit fresh Token (Token expired / revoked via JTIMatcher)
      if response.code == "401"
        Rails.logger.warn "[Syncer] API push 401, refreshing token + retry"
        reset_api_token!
        token = api_token
        response = http_patch(api_url(tournament_cc), body, token) if token.present?
      end

      case response.code
      when "200"
        apply_response_unprotected(JSON.parse(response.body))
        Rails.logger.info "[Syncer] API push 200 for tournament_cc_id=#{tournament_cc.id} → registration_list_cc_id=#{registration_list_cc.id}"
      when "401"
        Rails.logger.error "[Syncer] API push 401 (even after retry) — credentials may be invalid"
      when "422"
        Rails.logger.error "[Syncer] API push 422: #{response.body}"
      else
        Rails.logger.error "[Syncer] API push unexpected #{response.code}: #{response.body}"
      end
    rescue => e
      Rails.logger.error "[Syncer] push_link_to_api crashed: #{e.class}: #{e.message}"
    end

    def api_token
      @api_token ||= fetch_api_token
    end

    def reset_api_token!
      @api_token = nil
    end

    private

    def fetch_api_token
      email = Rails.application.credentials.api_syncer_email
      password = Rails.application.credentials.api_syncer_password
      return nil if email.blank? || password.blank?

      uri = URI("#{Carambus.config.carambus_api_url}/login")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      req = Net::HTTP::Post.new(uri.request_uri, {
        "Content-Type" => "application/json",
        "Accept" => "application/json"
      })
      req.body = {user: {email: email, password: password}}.to_json
      res = http.request(req)
      return nil unless res.is_a?(Net::HTTPSuccess)
      res["Authorization"].to_s.sub(/\ABearer\s+/, "").presence
    rescue => e
      Rails.logger.error "[Syncer] fetch_api_token crashed: #{e.class}: #{e.message}"
      nil
    end

    def api_url(tournament_cc)
      "#{Carambus.config.carambus_api_url}/api/tournament_ccs/#{tournament_cc.id}/registration_list_link"
    end

    def http_patch(url, body, token)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      req = Net::HTTP::Patch.new(uri.request_uri, {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{token}"
      })
      req.body = body.to_json
      http.request(req)
    end

    # Direct-Persist-Pattern aus version.rb:344, 396-398 — Response-Records mit
    # unprotected:true persistieren, umgeht ApiProtector für globale Records
    def apply_response_unprotected(response_json)
      tc_json = response_json["tournament_cc"]
      rl_json = response_json["registration_list_cc"]

      ActiveRecord::Base.transaction do
        if rl_json.present?
          rl = RegistrationListCc.find_or_initialize_by(id: rl_json["id"])
          rl.unprotected = true
          rl.assign_attributes(rl_json.except("id", "created_at", "updated_at"))
          rl.save!
        end

        if tc_json.present?
          tc = TournamentCc.find_by(id: tc_json["id"])
          if tc
            tc.unprotected = true
            tc.update!(registration_list_cc_id: tc_json["registration_list_cc_id"])
          end
        end
      end
    end
  end
end
