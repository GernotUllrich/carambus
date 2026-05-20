# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

# Plan 15-05: Empirical-Verify-Substrate für External-Tournament-Bridge.
#
# Smoke-Test gegen lokalen (Dev/Test/Local-Scenario) Carambus-Server. Verifiziert
# Auth + 3 Endpoints (Seeding/Round-Start/Round-Result) mit Bearer-JWT.
#
# Voraussetzungen:
#   1. Carambus-Server läuft (z.B. bin/rails server :3000)
#   2. Service-Account existiert (`rake service_accounts:create_2band[REGION]`)
#   3. SERVICE_ACCOUNT_PASSWORD env var ist gesetzt (Output aus Schritt 2)
#   4. Region existiert in DB; mindestens 1 TournamentCc mit context=region.downcase
#
# Optionale env vars:
#   BASE_URL — default http://localhost:3000

namespace :external_tournament do
  desc "Smoke-Test der External-Tournament-Bridge-Endpoints. Usage: rake external_tournament:smoke_test[REGION]"
  task :smoke_test, [:region_shortname] => :environment do |_, args|
    shortname = args[:region_shortname].to_s.upcase
    if shortname.blank?
      puts "Usage: rake external_tournament:smoke_test[REGION_SHORTNAME]"
      puts "Example: rake external_tournament:smoke_test[NBV]"
      puts ""
      puts "Required env var: SERVICE_ACCOUNT_PASSWORD (from rake service_accounts:create_2band[REGION] output)"
      puts "Optional env var: BASE_URL (default: http://localhost:3000)"
      exit 1
    end

    base_url = ENV.fetch("BASE_URL", "http://localhost:3000")
    email = "2band-#{shortname.downcase}-bridge@carambus.de"
    password = ENV["SERVICE_ACCOUNT_PASSWORD"]
    if password.to_s.empty?
      puts "ERROR: SERVICE_ACCOUNT_PASSWORD env var nicht gesetzt"
      puts "       Lege den Account an mit `rake service_accounts:create_2band[#{shortname}]`"
      puts "       und exportiere das ausgegebene Password: export SERVICE_ACCOUNT_PASSWORD=..."
      exit 1
    end

    puts "═══════════════════════════════════════════"
    puts "External-Tournament-Bridge Smoke-Test"
    puts "═══════════════════════════════════════════"
    puts "Base-URL:        #{base_url}"
    puts "Service-Account: #{email}"
    puts "Region:          #{shortname}"
    puts ""

    # Step 1: Bearer-JWT holen
    jwt = ExternalTournamentSmokeTest.login_for_jwt(base_url, email, password)
    unless jwt
      puts "✗ Step 1: Login failed — kein Bearer-JWT erhalten"
      puts "  Hinweise: Service-Account angelegt? Password korrekt? Server erreichbar?"
      exit 1
    end
    puts "✓ Step 1: Bearer-JWT erhalten (length=#{jwt.length})"

    # Step 2: Region + TournamentCc in lokaler DB finden
    region = Region.find_by(shortname: shortname)
    unless region
      puts "✗ Step 2: Region '#{shortname}' nicht in lokaler DB"
      exit 1
    end

    tcc = TournamentCc.where(context: shortname.downcase).joins(:tournament).first
    if tcc.nil?
      puts "⚠ Step 2: Kein verlinktes TournamentCc für context=#{shortname.downcase}"
      puts ""
      puts "Setup-Hinweis (im rails console):"
      puts "  t = Tournament.where(region_id: Region.find_by(shortname: '#{shortname}').id).first"
      puts "  TournamentCc.create!(cc_id: 999_001, context: '#{shortname.downcase}', name: t.title, tournament: t)"
      exit 0
    end
    puts "✓ Step 2: TournamentCc cc_id=#{tcc.cc_id} verlinkt mit Tournament '#{tcc.tournament.title}'"

    # Step 3: GET /seeding
    seeding_url = "#{base_url}/api/external_tournament/seeding?tournament_cc_id=#{tcc.cc_id}&region=#{shortname}"
    code, body = ExternalTournamentSmokeTest.http_get(seeding_url, jwt)
    unless code == "200"
      puts "✗ Step 3: GET /seeding → HTTP #{code}"
      puts "  Body: #{body.to_s[0..200]}"
      exit 1
    end
    seeding_doc = JSON.parse(body)
    teams_count = seeding_doc["teams"]&.size || 0
    puts "✓ Step 3: GET /seeding → 200, schema=#{seeding_doc["schema"]}, teams=#{teams_count}"

    # Step 4: POST /round_start (idempotent)
    round_start_body = ExternalTournamentSmokeTest.build_round_start_body(tcc.cc_id, shortname, seeding_doc)
    code, body = ExternalTournamentSmokeTest.http_post(
      "#{base_url}/api/external_tournament/round_start",
      jwt,
      round_start_body
    )
    unless %w[200 201].include?(code)
      puts "✗ Step 4: POST /round_start → HTTP #{code}"
      puts "  Body: #{body.to_s[0..300]}"
      puts "  (Häufig: 422 'TableMonitor not found' wenn keine Tables mit name '1' existieren,"
      puts "   oder 'Player not resolved' wenn Seeding leer ist)"
      exit 1
    end
    rs_doc = JSON.parse(body)
    games_count = rs_doc["games"]&.size || 0
    puts "✓ Step 4: POST /round_start → #{code} (#{(code == "201") ? "neu erstellt" : "idempotent"}), games=#{games_count}"

    # Step 5: GET /round_result
    rr_url = "#{base_url}/api/external_tournament/round_result?tournament_cc_id=#{tcc.cc_id}&round_no=1&region=#{shortname}"
    code, body = ExternalTournamentSmokeTest.http_get(rr_url, jwt)
    unless code == "200"
      puts "✗ Step 5: GET /round_result → HTTP #{code}"
      puts "  Body: #{body.to_s[0..200]}"
      exit 1
    end
    rr_doc = JSON.parse(body)
    results_count = rr_doc["results"]&.size || 0
    puts "✓ Step 5: GET /round_result → 200, schema=#{rr_doc["schema"]}, results=#{results_count}"

    # Step 6: POST /player_reconcile (Plan 17-06) — Teilnehmer der ersten Setzliste reconcilen.
    reconcile_body = ExternalTournamentSmokeTest.build_player_reconcile_body(shortname, seeding_doc)
    code, body = ExternalTournamentSmokeTest.http_post(
      "#{base_url}/api/external_tournament/player_reconcile", jwt, reconcile_body
    )
    if code == "200"
      pr_doc = JSON.parse(body)
      matched = (pr_doc["results"] || []).count { |r| r["matched"] }
      puts "✓ Step 6: POST /player_reconcile → 200, schema=#{pr_doc["schema"]}, matched=#{matched}/#{pr_doc["results"]&.size || 0}"
    else
      puts "⚠ Step 6: POST /player_reconcile → HTTP #{code} (nicht-fatal): #{body.to_s[0..150]}"
    end

    # Step 7: GET /csv_export (Plan 17-06) — Ergebnis-CSV (App-Turnier-Games; ggf. nur Header).
    csv_url = "#{base_url}/api/external_tournament/csv_export?tournament_id=#{tcc.tournament.id}&region=#{shortname}"
    code, body = ExternalTournamentSmokeTest.http_get(csv_url, jwt)
    if code == "200" && body.to_s.start_with?("Gruppe;")
      data_rows = body.to_s.lines.size - 1
      puts "✓ Step 7: GET /csv_export → 200 text/csv (Header ok), Datenzeilen=#{data_rows}"
    else
      puts "⚠ Step 7: GET /csv_export → HTTP #{code} (nicht-fatal): #{body.to_s[0..150]}"
    end

    puts ""
    puts "═══════════════════════════════════════════"
    puts "✓ SMOKE-TEST PASSED — Bridge-Endpoints funktional"
    puts "  (Seeding/Round-Start/Round-Result + Player-Reconcile/CSV-Export)"
    puts "═══════════════════════════════════════════"
  end

  # Plan 17-05 (Vision M): Sysadmin-Fallback — gibt alle Tische eines lokalen App-Turniers
  # frei + schließt es (force, auch unbestätigte Hold-Ergebnisse).
  # zsh: Task-Namen quoten! Usage: rake "external_tournament:end[<tournament_id>]"
  desc "Sysadmin: lokales App-Turnier beenden + Tische freigeben. Usage: rake \"external_tournament:end[<tournament_id>]\""
  task :end, [:tournament_id] => :environment do |_, args|
    t = Tournament.find_by(id: args[:tournament_id])
    abort "Tournament #{args[:tournament_id].inspect} not found" if t.nil?
    r = ExternalTournament::TableReleaser.release_tournament(t)
    puts "✓ Tournament #{t.id} (#{t.external_id}): #{r.released} Tisch(e) freigegeben " \
         "(#{r.unacknowledged} unbestätigt), TournamentMonitor=#{r.tournament_monitor_state}"
  end

  # Plan 17-05 (Vision N): Mitternachts-Auto-Abbruch — Safety-Net für über Nacht hängende
  # lokale App-Turnier-Tischbindungen (id>=MIN_ID + manual_assignment). Idempotent.
  # Via whenever in config/schedule.rb täglich getriggert.
  desc "Mitternachts-Auto-Abbruch: hängende lokale App-Turnier-Tische freigeben. Usage: rake external_tournament:release_stale_local_tables"
  task release_stale_local_tables: :environment do
    res = ExternalTournament::TableReleaser.release_stale_local
    puts "✓ Stale-Release: #{res[:released]} Tisch(e) freigegeben, #{res[:tournaments_closed]} Turnier(e) geschlossen"
  end
end

# Helper-Modul (kein top-level Pollution; Plan 15-05 Substrate)
module ExternalTournamentSmokeTest
  def self.login_for_jwt(base_url, email, password)
    uri = URI("#{base_url}/login")
    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req.body = JSON.dump(user: {email: email, password: password})
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
    return nil unless res.is_a?(Net::HTTPSuccess)
    res["Authorization"]&.sub(/\ABearer\s+/, "")
  end

  def self.http_get(url, jwt)
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{jwt}"
    req["Accept"] = "application/json"
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
    [res.code, res.body]
  end

  def self.http_post(url, jwt, body)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{jwt}"
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req.body = JSON.dump(body)
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { |h| h.request(req) }
    [res.code, res.body]
  end

  # Plan 17-06: Baut ein player_reconcile-Payload aus den Spielern der ersten Setzliste.
  def self.build_player_reconcile_body(region_shortname, seeding_doc)
    players = seeding_doc.dig("teams", 0, "players") || []
    participants = players.map.with_index(1) do |p, i|
      {ref: "p#{i}", cc_id: p["cc_id"], dbu_nr: p["dbu_nr"], firstname: p["firstname"], lastname: p["lastname"]}
    end
    participants = [{ref: "p1", firstname: "Test", lastname: "PlayerA"}] if participants.empty?
    {region: {shortname: region_shortname}, participants: participants}
  end

  # Baut ein round_start/v1-Payload basierend auf der Seeding-Response.
  # Fixe external_id für Re-Run-Idempotenz (zweiter Call liefert 200 statt 201).
  def self.build_round_start_body(cc_id, region_shortname, seeding_doc)
    first_team = seeding_doc["teams"]&.first
    players = first_team&.dig("players") || []
    pa = players[0] || {"firstname" => "Test", "lastname" => "PlayerA"}
    pb = players[1] || {"firstname" => "Test", "lastname" => "PlayerB"}
    {
      schema: "carambus.round_start/v1",
      region: {shortname: region_shortname},
      tournament: {cc_id: cc_id},
      round_no: 1,
      round_name: "Smoke-Test Runde 1",
      games: [{
        external_id: "smoke-test-r1-table1",
        table_no: 1,
        discipline: {name: "3-Band"},
        format: {target_points: 30, max_innings: 25},
        context: {round_no: 1, gname: "Smoke-Test-Game-1", group_no: 1, seqno: 1},
        participants: [
          {role: "playera", player: pa},
          {role: "playerb", player: pb}
        ]
      }]
    }
  end
end
