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
      #   _, doc_cat = @client.post('deleteMeldeliste', { branchId: 10, fedId: @region_cc.cc_id, season: season.name, meldelisteId: cc_id_ml }, @opts)
      #   next
      # end
      next if !registration_list_cc.new_record? && @opts[:update_from_cc].blank?

      _, doc_cat = @client.post("showMeldeliste",
        {fedId: @region_cc.cc_id, branchId: branch_cc.cc_id, disciplinId: "*", meldelisteId: cc_id_ml, catId: "*", season: season.name}, @opts)
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
            status = tr.css("td")[2].text.strip.gsub(/^\u00A0/, "").strip
          end
        end
        if @opts[:release] && status != "Freigegeben"
          _, doc = @client.post("releaseMeldeliste",
            {branchId: branch_cc.cc_id, fedId: branch_cc.region_cc.cc_id, season: season.name, meldelisteId: registration_list_cc.cc_id, release: ""}, @opts)
        end
        registration_list_cc.update(season_id: season.id, discipline_id: discipline_id, category_cc_id: category_cc_id,
          context: context, branch_cc_id: branch_cc.id, name: name, status: "Freigegeben", deadline: deadline, qualifying_date: qualifying_date)

        # Plan 14-G.14 Task 4b: Auto-Wire — finde matching TournamentCc by name+context und triggere API-Push.
        # Idempotent: nur push wenn registration_list_cc_id geändert wurde (Avoidet Push-Storm bei Re-Scraping).
        link_and_push_if_match(registration_list_cc, context)
      rescue => e
        Rails.logger.error "Error: #{e.message}"
      end
    end
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
