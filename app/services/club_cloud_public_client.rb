# frozen_string_literal: true

# Öffentliche Vereins- und Mitgliederseiten der ClubCloud.
#
# Die alten GET-Seiten `verein-details.php?p=…` und `verein-mitglieder…` liefern seit spätestens 2026-11-10
# HTTP 410 (Vereinsliste, Details, Mitglieder — auch im Browser). Ersatz ist die Seitenfamilie `cb*.php`,
# bedient per POST-Formular „cc“ (siehe `clubNavigate`/`cp` im Seiten-JS):
#   cbdet.php    f=<Verband> eps=100000          → Vereinsliste  (Links `cp(0,<Verein>)`, title = Kurzname)
#   cbdet.php    f=<Verband> a=<Verein>          → Vereinsdetails (aside table.silver: Verein, DBU-Nr., …)
#   cbmemdet.php f=<Verband> a=<Verein> eps=…    → Mitgliederliste (article table.silver: `memberPage(<Pass-Nr.>)`)
#   cbmemdet.php f=<Verband> a=<Verein> m=<Pass> → Spielerdetails (aside table.silver[1]: Name, Pass-Nr., DBU-Nr.)
# Pass-Nr. = Spieler-cc_id (früher Parameter 5 der Spieler-URL).
#
# Die CC drosselt zweifach (2026-11-24 gemessen): bei ~0,17 s Abstand HTTP 429, und nach einigen hundert
# Anfragen sperrt sie die IP länger (schon die erste Anfrage 429, auch nach 90 s Pause).
# `X-WS-RateLimit-Remaining` taugt nicht als Zähler (stand nach dem Lauf auf 999). Darum MIN_INTERVAL
# zwischen zwei Anfragen, bei 429 Pause und bis zu RETRIES Wiederholungen, danach Error statt leerer Seite
# (eine leere Seite würde als „keine Mitglieder/keine Details“ ausgewertet).
# Menge: Das Kontingent (~400 POSTs je IP, gemessen 2026-11-25/26, Fenster > 25 min) zählt jede Anfrage —
# darum zieht `budget` (geteilt mit Region#scrape_clubs/Club#scrape_club, die vorab prüfen) jeden POST ab,
# auch Wiederholungen. Das Budget gilt je Lauf; zwei Läufe im selben Fenster teilen sich das Kontingent trotzdem.
class ClubCloudPublicClient
  class Error < StandardError; end

  MIN_INTERVAL = 2.0
  PAUSE_SECONDS = 30
  RETRIES = 3
  ALL = 100_000

  Member = Struct.new(:pass_nr, :name, keyword_init: true) # name: "Nachname, Vorname"

  attr_accessor :budget # {left:, deferred:} oder nil (unbegrenzt)

  def initialize(base_url:, fed_id:, http: nil, sleeper: ->(s) { sleep(s) }, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
    @base_url = base_url.to_s.end_with?("/") ? base_url.to_s : "#{base_url}/"
    @fed_id = fed_id
    @http = http || method(:post_form)
    @sleeper = sleeper
    @clock = clock
    @last_at = nil
  end

  # [[cc_id, Kurzname], …] aller Vereine des Verbands. Nur Vereinslinks (`a.cc_bluelink`, ID > 0): Die
  # Sparten-Filter nutzen dieselbe Funktion (`cp(0,0)` = „Alle Sparten“, class cc_white).
  def clubs
    doc = post("cbdet.php", eps: ALL)
    doc.css("a.cc_bluelink[onclick]").filter_map do |a|
      id = a["onclick"][/\bcp\(\s*\d+\s*,\s*(\d+)\s*\)/, 1].to_i
      [id, (a["title"].presence || a.text).strip] if id.positive?
    end.uniq(&:first)
  end

  def club_doc(cc_id) = post("cbdet.php", a: cc_id)

  def members_doc(cc_id) = post("cbmemdet.php", a: cc_id, eps: ALL, m: 0)

  def self.members(doc)
    return [] if doc.nil?

    doc.css("article table.silver a[onclick]").filter_map do |a|
      pass = a["onclick"][/memberPage\(\s*(\d+)\s*\)/, 1]
      Member.new(pass_nr: pass.to_i, name: (a["title"].presence || a.text).strip) if pass
    end.uniq(&:pass_nr)
  end

  def member_doc(cc_id, pass_nr) = post("cbmemdet.php", a: cc_id, m: pass_nr)

  # Nur zur Herkunftsangabe (source_url); die Seiten sind per GET nicht abrufbar.
  def url_for(page, **params) = "#{@base_url}#{page}?#{{f: @fed_id}.merge(params).to_query}"

  # Schlüssel/Wert-Zeilen einer Detailtabelle („DBU-Nr.“ => "2191").
  def self.details(table)
    return {} if table.nil?

    table.css("tr").each_with_object({}) do |tr, h|
      tds = tr.css("td")
      h[tds[0].text.strip] = tds[1] if tds.size >= 2 && tds[0].text.strip.present?
    end
  end

  private

  FORM_DEFAULTS = {b: 0, pno: 1, team: 0, player: 0, loc: 0, pic: 0, article: 0}.freeze

  def post(page, params)
    uri = URI("#{@base_url}#{page}")
    form = FORM_DEFAULTS.merge(f: @fed_id).merge(params)
    (RETRIES + 1).times do |attempt|
      throttle
      @budget[:left] -= 1 if @budget
      code, body = @http.call(uri, form)
      return Nokogiri::HTML(body.to_s) if code.to_i == 200
      raise Error, "HTTP #{code} für POST #{uri} #{params.inspect}" unless code.to_i == 429 && attempt < RETRIES

      Rails.logger.info "===== scrape ===== HTTP 429 für POST #{uri} — Pause #{PAUSE_SECONDS}s (Versuch #{attempt + 1})"
      @sleeper.call(PAUSE_SECONDS)
    end
  end

  def throttle
    wait = @last_at && (MIN_INTERVAL - (@clock.call - @last_at))
    @sleeper.call(wait) if wait&.positive?
    @last_at = @clock.call
  end

  def post_form(uri, params)
    response = Net::HTTP.post_form(uri, params.transform_keys(&:to_s).transform_values(&:to_s))
    [response.code, response.body.to_s.force_encoding("UTF-8")]
  end
end
