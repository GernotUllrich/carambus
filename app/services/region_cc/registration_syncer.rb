# frozen_string_literal: true

# Syncer fuer Meldelisten-Daten aus dem ClubCloud-System.
#
# Plan 23-01 T2 (Seeding-Unification): Schrieb bis 23-01 RegistrationListCc-
# Header-Records (mit name/status/deadline/qualifying_date/branch/discipline/
# category). Diese Tabelle wird in T1b gedroppt; die CC-System-IDs leben jetzt
# direkt auf TournamentCc (meldeliste_cc_id, meldeliste_deadline,
# meldeliste_qualifying_date — Migration T1a).
#
# Verbleibende Aufgabe: Pro CC-Meldeliste das matching TournamentCc finden
# und seine meldeliste_*-Felder setzen. Match-Strategie: (context, name)
# wie bisher in link_and_push_if_match. Wenn kein TCc gefunden → skip + log
# (Meldeliste ohne Carambus-Tournament hat keinen DB-Anker).
#
# Status wird zum Release-Trigger evaluiert, aber nicht mehr persistiert.
# (Bestand: kein MCP-Tool und kein Workflow-Code liest RL.status.)
#
# Plan 14-G.14 Push (Local→Authority) ist entfallen: API-Endpoint wird in
# T3c gelöscht; Meldungen leben Authority-zentral.
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

    rows = extract_meldeliste_rows(doc)
    rows.each do |row|
      cc_id_ml = row[:cc_id]
      next if cc_id_ml.blank? || cc_id_ml < 1

      name = row[:name]
      status = row[:status].to_s.gsub(/^ /, "").strip
      deadline = parse_german_date(row[:deadline_raw]) || Date.today
      qualifying_date = parse_german_date(row[:qualifying_date_raw]) || Date.today

      begin
        if @opts[:release] && status != "Freigegeben"
          @client.post("releaseMeldeliste",
            {branchId: branch_cc.cc_id, fedId: branch_cc.region_cc.cc_id, season: season.name, meldelisteId: cc_id_ml, release: ""}, @opts)
        end

        update_tournament_cc_meldeliste_fields(cc_id_ml, name, context, season, deadline, qualifying_date)
      rescue => e
        Rails.logger.error "[RegistrationSyncer] cc_id=#{cc_id_ml} name=#{name.inspect}: #{e.class}: #{e.message}"
      end
    end
  end

  # Plan 23-01 T2: matching TournamentCc finden und meldeliste_*-Felder direkt
  # setzen. Idempotent (update_columns ist write-all-or-nothing, kein Trigger
  # auf gleiche Werte). Match-Strategie: (context, name) — wie bisher in
  # link_and_push_if_match. Bei Ambiguität (2+ TCcs): alle updaten (theoretisch
  # selten; Tournament-Name + Context sollten in der Praxis eindeutig sein).
  # Bei 0 Treffern: skip + log (kein Carambus-Tournament für diese Meldeliste).
  def update_tournament_cc_meldeliste_fields(cc_id_ml, name, context, season, deadline, qualifying_date)
    return if name.blank?

    candidates = TournamentCc.where(context: context, name: name)
    candidates = candidates.where(season: season.name) if season&.name.present?

    if candidates.none?
      Rails.logger.info "[RegistrationSyncer] No matching TournamentCc for cc_id=#{cc_id_ml} name=#{name.inspect} context=#{context}"
      return
    end

    candidates.find_each do |tcc|
      tcc.update_columns(
        meldeliste_cc_id: cc_id_ml,
        meldeliste_deadline: deadline,
        meldeliste_qualifying_date: qualifying_date
      )
    end
  end

  # Plan 21-13 T3 Helper: Extract Meldeliste-Rows aus showMeldelistenList-HTML.
  # ClubCloud V2 UI Heuristik: das Datentabelle ist die letzte <table> mit > 5 Rows.
  # Defensive: gibt [] zurück wenn keine passende Tabelle gefunden.
  #
  # Plan 21-13 D-EXEC-A Deviation (2026-05-29 checkpoint:human-verify):
  # Live-Body-Inspect via /tmp/probe_meldelisten.rb gegen production zeigte zwei
  # Diskrepanzen zum Browser-Trace 2026-05-28, der dem Plan-CONTEXT D-K zugrunde lag:
  #   1. Daten-Rows haben 8 Cells, nicht 7. Cell[0] ist Laufnummer (im Trace übersehen).
  #      Alle Cell-Indizes für Name/Disz/Datum/Kat/Datum/Status verschieben sich um +1.
  #   2. cc_id-Link sitzt in Cell[1] (Name-Cell) als <a class="cc_bluelink"> und nutzt
  #      Param `?p=<fed>|<branch>|<disz>|<kat>|<season>|<cc_id>&` (Pipe-separated, letztes
  #      Segment = cc_id) statt der angenommenen Patterns `meldelisteId=N` / `id=N`.
  # Defensive Fallback-Patterns (meldelisteId=, id=) bleiben für Mixed-State-Tolerance.
  def extract_meldeliste_rows(doc)
    candidate_tables = doc.css("table").select { |t| t.css("tr").length > 5 }
    data_table = candidate_tables.last
    return [] unless data_table

    data_table.css("tr").drop(1).filter_map do |tr|
      cells = tr.css("td")
      next nil if cells.length < 8  # Daten-Row hat 8 Cells (Laufnr/Name/Disz/Dl/Kat/Qd/Status/Dashboard)

      # cc_id aus dem Name-Link in Cell[1]; primär Pipe-Pattern (V2 UI 2026-05-29),
      # Fallbacks für ältere Patterns.
      name_link = cells[1].css('a[href*="showMeldeliste.php"]').first
      cc_id = nil
      if name_link
        href = name_link["href"].to_s
        if (m = href.match(/\|(\d+)(?:&|$)/))
          cc_id = m[1].to_i
        elsif (m = href.match(/[?&]meldelisteId=(\d+)/))
          cc_id = m[1].to_i
        elsif (m = href.match(/[?&]id=(\d+)/))
          cc_id = m[1].to_i
        end
      end
      next nil unless cc_id

      # Cell-Mapping (Live-Body 2026-05-29 verifiziert):
      # [0] Laufnummer | [1] Name+Link | [2] Disziplin | [3] Deadline
      # [4] Kategorie  | [5] Qualifying-Date | [6] Status | [7] Dashboard-Icon
      {
        cc_id: cc_id,
        name: cells[1].text.strip,
        discipline_text: cells[2].text.strip,
        deadline_raw: cells[3].text.strip,
        category_text: cells[4].text.strip,
        qualifying_date_raw: cells[5].text.strip,
        status: cells[6].text.strip
      }
    end
  end

  # Plan 21-13 T3 Helper: defensive German-Date-Parsing.
  # Akzeptiert "DD.MM.YYYY" überall in einem Text-Snippet; gibt nil bei Parse-Fehler.
  def parse_german_date(raw)
    return nil unless raw.is_a?(String)
    return nil unless (m = raw.match(/(\d\d\.\d\d\.\d\d\d\d)/))
    Date.parse(m[1])
  rescue Date::Error
    nil
  end
end
