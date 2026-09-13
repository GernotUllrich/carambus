// ============================================================================
// shared/carambus-core.js — gemeinsamer Carambus-Kern (KANONISCHE QUELLE)
// ----------------------------------------------------------------------------
// Klassisches Script (KEIN ES-Modul), definiert das globale Objekt
// `window.Carambus`. Wird per tools/sync-core.mjs zwischen den CARAMBUS-SYNC-
// Markern (Region core-js) in jede self-contained Schema-/Launcher-HTML INLINE
// kopiert (damit jede Datei per Doppelklick aus dem Dateisystem läuft — ES-Module
// gehen über file:// nicht). HINWEIS: in dieser Datei dürfen die literalen
// Marker-Tokens NICHT vorkommen (sonst bricht der Extraktor zu früh ab).
//
// → Diese Datei ist die EINZIGE Bearbeitungsstelle des Kerns. Nach Änderungen:
//      node tools/sync-core.mjs    (inlinen)
//      node tools/check-core-sync.mjs   (verifizieren)
// Diese Datei wird zur LAUFZEIT NICHT geladen — die Deliverables sind die
// self-contained HTML-Dateien.
// ============================================================================
window.Carambus = (function () {
  "use strict";

  // ========================= Verbindung / Auth =============================
  const CONN_KEY = "carambus.connection";
  const CONN_DEFAULTS = {
    base_url: "http://192.168.178.84:3131",
    email: "carambus-app-gu-bridge@carambus.de",
    region: "NBV",
    tournament_cc_id: "",
    tournament_id: "",     // Carambus-DB-PK (global eindeutig, robust gegen region-scoped cc_id-Ambiguität)
    party_cc_id: "",       // Liga-Spieltag (Party) — vom Chat-Deeplink cc_open_party_in_app (§6 spieltag-Handoff)
    bearer: null,
    bearer_expires_at: null
  };

  function getConnection() {
    try {
      const raw = localStorage.getItem(CONN_KEY);
      if (!raw) return { ...CONN_DEFAULTS };
      return { ...CONN_DEFAULTS, ...JSON.parse(raw) };
    } catch (e) {
      return { ...CONN_DEFAULTS };
    }
  }
  function saveConnection(conn) { localStorage.setItem(CONN_KEY, JSON.stringify(conn)); }
  function isBearerValid(conn) {
    return !!(conn.bearer && conn.bearer_expires_at && Date.now() < conn.bearer_expires_at);
  }
  function regionShortname() { return (getConnection().region || "NBV").toUpperCase(); }

  // Deep-Link-Vorausfüllung (Carambus-Chat-Brücke, Handoffs cc_open_in_tournament_app +
  // cc_open_party_in_app):
  // Liest cb_base_url/cb_region/cb_tournament_cc_id/cb_tournament_id/cb_party_cc_id aus der URL
  // und schreibt sie in die gespeicherte Verbindung. base_url: explizit aus cb_base_url, sonst
  // Same-Origin = window.location.origin (App wird unter /app/ vom selben Local-Server
  // ausgeliefert). cb_tournament_id (= Carambus-DB-Tournament#id, global eindeutig) wird
  // zusätzlich zu cb_tournament_cc_id (region-scoped, deshalb mehrdeutig) gelesen; der
  // seeding-Endpoint bevorzugt tournament_id wenn beide vorhanden — siehe HANDOFF Paul/
  // v52337e16. cb_party_cc_id (Liga-Spieltag) wird parallel dazu geführt — der Launcher zeigt
  // dann eine Party-Variante des Deep-Link-Banners.
  // Das Passwort wird NIE über den Link übertragen — nach dem Vorausfüllen loggt sich
  // der TL wie gewohnt ein. Räumt die cb_*-Parameter danach aus der URL (replaceState).
  // Gibt true zurück, wenn etwas vorausgefüllt wurde.
  function applyDeepLinkConnection() {
    try {
      if (typeof window === "undefined" || !window.location) return false;
      const q = new URLSearchParams(window.location.search || "");
      const region = q.get("cb_region");
      const ccId = q.get("cb_tournament_cc_id");
      const tId = q.get("cb_tournament_id");
      const partyCcId = q.get("cb_party_cc_id");
      const baseUrl = q.get("cb_base_url");
      // cb_email: Service-Account des Ziel-Servers. Ohne diesen Parameter steht in einem
      // frischen Browser der CONN_DEFAULTS-Wert im Login-Feld (z. B. …-gu-bridge@…), und
      // der Login gegen einen anderen Local-Server scheitert mit 401 „E-Mail oder Passwort
      // ungültig" — ohne dass der Grund im Feld sichtbar auffällt. Das Passwort wird
      // weiterhin NIE über den Link übertragen.
      const email = q.get("cb_email");
      if (!region && !ccId && !tId && !partyCcId && !baseUrl && !email) return false;

      const conn = getConnection();
      if (region) conn.region = String(region).toUpperCase();
      if (ccId) conn.tournament_cc_id = String(ccId);
      if (tId) conn.tournament_id = String(tId);
      if (partyCcId) conn.party_cc_id = String(partyCcId);
      if (email && email.trim()) conn.email = email.trim();
      const origin = (window.location.origin && window.location.origin !== "null") ? window.location.origin : null;
      const resolvedBase = (baseUrl && baseUrl.trim()) || origin;
      if (resolvedBase) conn.base_url = resolvedBase;
      saveConnection(conn);

      ["cb_region", "cb_tournament_cc_id", "cb_tournament_id", "cb_party_cc_id", "cb_base_url", "cb_email"].forEach((k) => q.delete(k));
      const rest = q.toString();
      const clean = window.location.pathname + (rest ? "?" + rest : "") + (window.location.hash || "");
      if (window.history && window.history.replaceState) window.history.replaceState(null, "", clean);
      return true;
    } catch (e) {
      return false;
    }
  }

  function parseTournamentCcIdInput(input) {
    if (input == null) return null;
    const s = String(input).trim();
    if (!s) return null;
    if (/^\d+$/.test(s)) return s;
    try {
      const u = new URL(s);
      const p = u.searchParams.get("p");
      if (p) { const m = p.match(/\d{4}\/\d{4}-(\d+)/); if (m) return m[1]; }
    } catch (_) {}
    const m2 = s.match(/[-/](\d{3,})[-/]/);
    if (m2) return m2[1];
    return null;
  }

  class CarambusError extends Error {
    constructor(status, body, message) {
      super(message || `HTTP ${status}`);
      this.name = "CarambusError";
      this.status = status;
      this.body = body;
    }
  }

  async function fetchWithTimeout(url, opts, timeoutMs) {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), timeoutMs);
    try { return await fetch(url, { ...opts, signal: ctrl.signal }); }
    finally { clearTimeout(timer); }
  }

  async function carambusLogin(baseUrl, email, password) {
    const url = baseUrl.replace(/\/+$/, "") + "/login";
    const resp = await fetchWithTimeout(url, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Accept": "application/json" },
      body: JSON.stringify({ user: { email, password } })
    }, 10000);
    if (!resp.ok) {
      let body = null; try { body = await resp.json(); } catch (_) {}
      throw new CarambusError(resp.status, body, `Login fehlgeschlagen (HTTP ${resp.status})`);
    }
    const auth = resp.headers.get("Authorization") || resp.headers.get("authorization");
    if (!auth || !auth.startsWith("Bearer ")) {
      throw new CarambusError(resp.status, null, "Login OK, aber kein Bearer-Token in der Antwort gefunden");
    }
    const bearer = auth.substring("Bearer ".length).trim();
    const expiresAt = Date.now() + 90 * 24 * 60 * 60 * 1000;
    return { bearer, expires_at: expiresAt };
  }

  // ========================= REST-Client ===================================
  async function carambusFetch(path, opts = {}) {
    const conn = getConnection();
    if (!conn.base_url) throw new CarambusError(0, null, "Keine Carambus-Verbindung konfiguriert (im Header auf das Statusfeld klicken)");
    if (!isBearerValid(conn)) throw new CarambusError(401, null, "Kein gültiger Bearer-Token (bitte Login in den Verbindungseinstellungen)");
    const url = conn.base_url.replace(/\/+$/, "") + path;
    const headers = { "Authorization": `Bearer ${conn.bearer}`, "Accept": "application/json", ...(opts.headers || {}) };
    const fetchOpts = { method: opts.method || "GET", headers };
    if (opts.body != null) {
      headers["Content-Type"] = "application/json";
      fetchOpts.body = typeof opts.body === "string" ? opts.body : JSON.stringify(opts.body);
    }
    const cbEntry = { ts: new Date().toISOString(), method: fetchOpts.method, path, request: opts.body ?? null, status: null, response: null, error: null };
    (window.__cbLog = window.__cbLog || []).push(cbEntry);
    let resp;
    try {
      resp = await fetchWithTimeout(url, fetchOpts, 10000);
    } catch (e) {
      cbEntry.error = e.name === "AbortError" ? "Timeout" : ("Netzwerk: " + e.message);
      if (e.name === "AbortError") throw new CarambusError(0, null, "Timeout — Carambus antwortet nicht (LAN-Verbindung prüfen)");
      throw new CarambusError(0, null, "Netzwerkfehler — Carambus nicht erreichbar (LAN-Verbindung prüfen): " + e.message);
    }
    let body = null;
    const ct = resp.headers.get("Content-Type") || "";
    if (ct.includes("application/json")) { try { body = await resp.json(); } catch (_) {} }
    else { try { body = await resp.text(); } catch (_) {} }
    cbEntry.status = resp.status; cbEntry.response = body;
    if (!resp.ok) throw new CarambusError(resp.status, body, `HTTP ${resp.status}`);
    return { status: resp.status, body };
  }

  async function ping() {
    try {
      await carambusFetch(`/api/external_tournament/clubs?region=${encodeURIComponent(regionShortname())}`);
      return { ok: true };
    } catch (err) {
      if (err instanceof CarambusError && err.status === 404) return { ok: true, note: "404 (API erreichbar, Auth OK)" };
      throw err;
    }
  }

  async function fetchClubs(region = regionShortname()) {
    const { body } = await carambusFetch(`/api/external_tournament/clubs?region=${encodeURIComponent(region)}`);
    return body.clubs || [];
  }
  // Phase 21-07: optional ageClass/gender (Server-Filter). Spieler-Payload enthält jetzt
  // age_class (String) + gender ("M"/"F"/"U"). 2. Arg darf weiter ein region-String sein
  // (Legacy-Kompatibilität) — bevorzugt aber das Optionen-Objekt.
  async function fetchClubPlayers(clubCcId, opts = {}) {
    if (typeof opts === "string") opts = { region: opts };
    const region = opts.region || regionShortname();
    const params = new URLSearchParams();
    params.set("region", region);
    params.set("club_cc_id", clubCcId);
    if (opts.ageClass) params.set("age_class", opts.ageClass);
    if (opts.gender) params.set("gender", opts.gender);
    const { body } = await carambusFetch(`/api/external_tournament/club_players?${params.toString()}`);
    return body.players || [];
  }
  // Phase 15 + Paul-Patch v52337e16: Seedings + Turnier-Metadaten eines TournamentCc
  // (Single + Mannschaft). Quelle für die "Aus Meldeliste vorbefüllen"-UX: liefert
  // tournament.{name,discipline,format,location} + teams[].players[] in Setzlisten-
  // Reihenfolge. tournament_id (Carambus-DB-PK, global eindeutig) wird bevorzugt; Fallback
  // tournament_cc_id (region-scoped via context). Mindestens eines muss gesetzt sein.
  async function fetchSeeding({ region = regionShortname(), tournamentCcId, tournamentId } = {}) {
    const hasTId = tournamentId != null && String(tournamentId).trim() !== "";
    const hasCc = tournamentCcId != null && String(tournamentCcId).trim() !== "";
    if (!hasTId && !hasCc) {
      throw new CarambusError(0, null, "tournamentId oder tournamentCcId erforderlich für fetchSeeding");
    }
    const params = new URLSearchParams();
    params.set("region", region);
    if (hasTId) params.set("tournament_id", tournamentId);
    if (hasCc) params.set("tournament_cc_id", tournamentCcId);
    const { body } = await carambusFetch(`/api/external_tournament/seeding?${params.toString()}`);
    return body;
  }
  // Phase 21-05: ClubCloud-Meldelisten einer Region+Saison (Deadline/Status/Disziplin/Kategorie
  // + ggf. verknüpftes tournament_cc). Default-Saison = Carambus current_season.
  async function fetchRegistrationLists({ region = regionShortname(), season, discipline, category, status } = {}) {
    const params = new URLSearchParams();
    params.set("region", region);
    if (season) params.set("season", season);
    if (discipline) params.set("discipline", discipline);
    if (category) params.set("category", category);
    if (status) params.set("status", status);
    const { body } = await carambusFetch(`/api/external_tournament/registration_lists?${params.toString()}`);
    return body;
  }
  // Phase 19 (Handoff an Paul): Sortierung nach Disziplin-Ranking.
  async function fetchPlayerRankings({ discipline, playerCcIds = [], region = regionShortname() }) {
    const params = new URLSearchParams();
    params.set("region", region);
    params.set("discipline", discipline);
    if (playerCcIds.length) params.set("player_cc_ids", playerCcIds.join(","));
    const { body } = await carambusFetch(`/api/external_tournament/player_rankings?${params.toString()}`);
    return body;
  }
  async function fetchTables(locationRef, region = regionShortname()) {
    const params = new URLSearchParams();
    params.set("region", region);
    if (locationRef.id != null) params.set("location_id", locationRef.id);
    else if (locationRef.cc_id != null) params.set("location_cc_id", locationRef.cc_id);
    const { body } = await carambusFetch("/api/external_tournament/tables?" + params.toString());
    return body;
  }

  // Phase 20: GET disciplines — offizielle Disziplinen + TournamentPlans (executor_params)
  // + DisciplineTournamentPlan-Matrix (points/innings je Plan×Klasse×Spielerzahl).
  // Liefert { schema, region, tournament_plans:{name→{…,executor_params}}, disciplines:[…] }.
  async function fetchDisciplines(region = regionShortname()) {
    const { body } = await carambusFetch(`/api/external_tournament/disciplines?region=${encodeURIComponent(region)}`);
    return body;
  }

  async function createTournament({ externalId, title, location, discipline, region = regionShortname() }) {
    const body = {
      region: { shortname: region }, external_id: externalId, title,
      location: location.id != null ? { id: location.id } : { cc_id: location.cc_id }
    };
    if (discipline) body.discipline = { name: discipline };
    const { body: resp } = await carambusFetch("/api/external_tournament/tournament", { method: "POST", body });
    return resp.tournament || {};
  }
  // Tisch-Referenz für die API: bevorzugt die Carambus-Table-id (eindeutig, robust gegen
  // doppelte Tischnamen einer Location), sonst Fallback auf den Namen (location-scoped).
  function tableRef(tableId, tableName) { return tableId != null ? { id: tableId } : { name: tableName }; }
  // Turnier-Referenz: bevorzugt tournamentId (globaler DB-PK, unabhängig von external_id).
  // Für Attach-Modus (Web-erzeugtes Turnier ohne external_id) unverzichtbar. Fallback auf
  // {external_id:…} für app-erzeugte Turniere. Alle POST-Endpoints akzeptieren beide Formen
  // (external_tournaments_controller#lock_table/start_game/acknowledge_result/end_tournament).
  function tournamentRef({ tournamentId, externalId }) {
    if (tournamentId != null && String(tournamentId).trim() !== "") return { tournament_id: tournamentId };
    return { tournament: { external_id: externalId } };
  }
  async function lockTable({ externalId, tournamentId = null, tableName, tableId = null, lock = true, region = regionShortname() }) {
    const { body } = await carambusFetch("/api/external_tournament/lock_table", {
      method: "POST",
      body: { region: { shortname: region }, ...tournamentRef({ tournamentId, externalId }), table: tableRef(tableId, tableName), lock }
    });
    return body;
  }
  async function startGame({ externalId, tournamentId = null, gameExternalId, tableName, tableId = null, participants, format = {}, region = regionShortname() }) {
    const payload = {
      region: { shortname: region }, ...tournamentRef({ tournamentId, externalId }), table: tableRef(tableId, tableName),
      external_id: gameExternalId,
      free_game_form: format.free_game_form || "karambol",
      innings_goal: format.innings_goal ?? 25,
      sets_to_play: format.sets_to_play ?? 1,
      sets_to_win: format.sets_to_win ?? 1,
      allow_follow_up: format.allow_follow_up ?? false,
      participants
    };
    if (format.initial_red_balls != null) payload.initial_red_balls = format.initial_red_balls; // Snooker
    const { body } = await carambusFetch("/api/external_tournament/start_game", { method: "POST", body: payload });
    return body;
  }
  async function acknowledgeResult({ externalId, tournamentId = null, gameExternalId, region = regionShortname() }) {
    const { status, body } = await carambusFetch("/api/external_tournament/acknowledge_result", {
      method: "POST",
      body: { region: { shortname: region }, ...tournamentRef({ tournamentId, externalId }), game: { external_id: gameExternalId } }
    });
    return { status, body };
  }
  async function endTournament({ externalId, tournamentId = null, cleanup = false, region = regionShortname() }) {
    const { body } = await carambusFetch("/api/external_tournament/end_tournament", {
      method: "POST",
      body: { region: { shortname: region }, ...tournamentRef({ tournamentId, externalId }), cleanup }
    });
    return body;
  }
  // ===== Ergebnisarchiv (Vertrag carambus.tournament_result/v1) ===========
  // Die App bleibt System of Record; der lokale Server bekommt zusaetzlich eine lesbare
  // Kopie des Endstands — dieselbe Form, in der Carambus gescrapte CC-Ergebnisse haelt.
  // Vertrag + Klaerungen: HANDOFF-to-/from-carambus-tournament-result-archive.md.
  //
  // Idempotent: mehrfacher Aufruf mit demselben Payload schreibt dieselben Zeilen
  // (Upsert ueber den Unique-Index tournament_id/gname/seqno). Bewusst nach JEDER Runde
  // aufrufen, nicht erst am Schluss — ein Geraeteverlust mittendrin kostet dann nichts.
  //
  // Response: { archived, durable, seedings_written, games_written, players_unmatched[] }
  //   archived = geschrieben, durable = ueberlebt den naechtlichen GC (erst ab Plan 41-02).
  async function pushTournamentResult({ externalId, tournamentId = null, scheme, title = "Endstand",
                                        standings = [], games = [], region = regionShortname() }) {
    const { body } = await carambusFetch("/api/external_tournament/tournament_result", {
      method: "POST",
      body: {
        // ACHTUNG, weicht von allen anderen Endpoints ab: tournament_result liest die
        // Region als STRING (`params[:region].to_s.upcase`, permit als Skalar), nicht als
        // {shortname:…}. Mit der Hausform quittiert der Server 404 "Couldn't find Region".
        // Gemeldet — solange die Server-Seite so ist, senden wir hier den String.
        region,
        ...tournamentRef({ tournamentId, externalId }),
        scheme, title, standings, games
      }
    });
    return body;
  }

  // Round-Result Aggregator (Plan 15-04): liest alle Ergebnisse einer Runde eines
  // Turniers. Erforderlich für Attach-Modus (State-Restore auf Zweit-Laptop / Tag N).
  // Achtung: Endpoint arbeitet mit tournament_cc_id (region-scoped), NICHT mit tournament_id
  // — kommt aus seeding.tournament.cc_id. Read-only.
  async function fetchRoundResult({ region = regionShortname(), tournamentCcId, roundNo } = {}) {
    if (tournamentCcId == null) throw new CarambusError(0, null, "tournamentCcId erforderlich für fetchRoundResult");
    if (roundNo == null) throw new CarambusError(0, null, "roundNo erforderlich für fetchRoundResult");
    const params = new URLSearchParams();
    params.set("region", region);
    params.set("tournament_cc_id", tournamentCcId);
    params.set("round_no", String(roundNo));
    const { body } = await carambusFetch(`/api/external_tournament/round_result?${params.toString()}`);
    return body;
  }
  // Convenience: iteriert round_result für Runden 1..maxRounds und aggregiert alle
  // Ergebnisse (leere Runden = einfach übersprungen). Für Attach-Modus im plan-Schema:
  // ein Aufruf → alle bereits gespielten Games mit external_id/table_name/participants.
  async function fetchAllRoundResults({ region = regionShortname(), tournamentCcId, maxRounds } = {}) {
    if (tournamentCcId == null) throw new CarambusError(0, null, "tournamentCcId erforderlich für fetchAllRoundResults");
    if (!maxRounds || maxRounds < 1) throw new CarambusError(0, null, "maxRounds erforderlich (>=1) für fetchAllRoundResults");
    const results = [];
    for (let r = 1; r <= maxRounds; r++) {
      try {
        const body = await fetchRoundResult({ region, tournamentCcId, roundNo: r });
        for (const res of (body.results || [])) results.push({ ...res, round_no: r });
      } catch (e) {
        if (e instanceof CarambusError && e.status === 404) continue; // Runde nicht gefunden = leer
        throw e;
      }
    }
    return results;
  }

  // Phase 48-§7 / HANDOFF-to-carambus-party-api §1: GET party — Liga-Spieltag laden.
  // Vorrang partyId (Carambus-DB-PK, global eindeutig); Fallback partyCcId (region-scoped).
  // Antwort: {schema:"carambus.party/v1", party:{id,cc_id,external_id,name,…,location?},
  // team_a/team_b:{id,cc_id,name,club_*,roster:[{dbu_nr,firstname,lastname,…}]},
  // party_monitor: identisch Pauls party_monitor.data (§4.1)}. Endpoint noch ausstehend.
  async function fetchParty({ region = regionShortname(), partyId, partyCcId } = {}) {
    const hasId = partyId != null && String(partyId).trim() !== "";
    const hasCc = partyCcId != null && String(partyCcId).trim() !== "";
    if (!hasId && !hasCc) throw new CarambusError(0, null, "partyId oder partyCcId erforderlich für fetchParty");
    const params = new URLSearchParams();
    params.set("region", region);
    if (hasId) params.set("party_id", partyId);
    if (hasCc) params.set("party_cc_id", partyCcId);
    const { body } = await carambusFetch(`/api/external_tournament/party?${params.toString()}`);
    return body;
  }
  // §2: POST party_game_result — Direkteingabe-Push pro Spielzeile (Modus ii).
  // baResults entspricht §4.3-Container (Spieler1/2 = dbu_nr team_a/b, Sets1/2 oder
  // Ergebnis1/2 je sets-Disziplin, Aufnahmen1/2 + Höchstserie1/2 optional).
  // gname = "<seqno>-<type>" — Schlüssel ins party_monitor.rows. Idempotent: Mehrfach-Push
  // überschreibt (TL-Korrektur). Antwort enthält intermediate_result für Drift-Vergleich.
  async function partyGameResult({ region = regionShortname(), partyExternalId, gname, baResults } = {}) {
    const { body } = await carambusFetch("/api/external_tournament/party_game_result", {
      method: "POST",
      body: {
        schema: "carambus.party_game_result/v1",
        region: { shortname: region },
        party: { external_id: partyExternalId },
        gname, ba_results: baResults
      }
    });
    return body;
  }
  // §3: POST party_close — Spielbericht abschließen (AASM close_party).
  // 409 + {missing_gnames:[...]} bei verletztem Guard (App soll fehlende Spiele anzeigen).
  async function partyClose({ region = regionShortname(), partyExternalId } = {}) {
    const { body } = await carambusFetch("/api/external_tournament/party_close", {
      method: "POST",
      body: {
        schema: "carambus.party_close/v1",
        region: { shortname: region },
        party: { external_id: partyExternalId }
      }
    });
    return body;
  }

  function cleanPlayerRef(p) {
    const ref = { firstname: (p.firstname ?? p.f ?? "").trim(), lastname: (p.lastname ?? p.l ?? "").trim() };
    if (p.cc_id != null) ref.cc_id = p.cc_id;
    if (p.dbu_nr != null) ref.dbu_nr = p.dbu_nr;
    if (p.club_cc_id != null) ref.club_cc_id = p.club_cc_id;
    return ref;
  }

  // ========================= Util ==========================================
  function calcAvg(balls, innings) { return (!innings || innings <= 0) ? 0 : balls / innings; }
  function fmtAvg(x) { return (!isFinite(x) || x === 0) ? "-" : x.toFixed(3); }
  function escapeHtml(s) {
    return String(s == null ? "" : s)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }
  function shuffle(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
    return a;
  }
  function tableNo(t) { const m = String(t == null ? "" : t).match(/\d+/); return m ? parseInt(m[0], 10) : null; }
  function csvCell(v) { const s = (v == null ? "" : String(v)); return /[";\n]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; }
  function buildCsv(rows) { return rows.map(r => r.map(csvCell).join(";")).join("\n"); }
  function downloadText(filename, text, mime = "text/csv") {
    const blob = new Blob([text], { type: mime });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob); a.download = filename; a.click();
    URL.revokeObjectURL(a.href);
  }
  function downloadJson(filename, obj) { downloadText(filename, JSON.stringify(obj, null, 2), "application/json"); }
  // Gemeinsame Export-Formate (schemaübergreifend identisch). Jedes Schema baut nur die
  // normalisierten Zeilen aus seinen eigenen Daten und ruft diese Builder auf.
  // ClubCloud-Rangliste (kein Header): RANG;PUNKTE;GRUPPENRANG;PASS-NR;PGA;VEREINSNR;TEILNEHMER
  function buildRankingCsv(entries) {
    return buildCsv((entries || []).map(e => [
      e.rang ?? "", e.punkte ?? "", e.gruppenrang ?? "", e.passNr ?? "", e.pga ?? "", e.vereinsNr ?? "", e.teilnehmer ?? ""
    ]));
  }
  // Spiele-CSV im Carambus-Import-Format (kein Header), in Reihenfolge nummeriert (lfd.nr):
  // Spielname;lfd.nr;;dbu_nr a;dbu_nr b;Bälle a;Bälle b;Aufn. a;Aufn. b;HS a;HS b;dd.mm.yyyy;hh:mm
  // games: [{ name, dbuA, dbuB, ballsA, ballsB, inningsA, inningsB, hsA, hsB, at(ms) }] (bereits sortiert)
  function buildGamesCsv(games) {
    const pad = n => String(n).padStart(2, "0");
    const dt = ms => { if (!ms) return ["", ""]; const d = new Date(ms); return [`${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()}`, `${pad(d.getHours())}:${pad(d.getMinutes())}`]; };
    return buildCsv((games || []).map((g, i) => {
      const [d, t] = dt(g.at);
      return [g.name ?? "", i + 1, "", g.dbuA ?? "", g.dbuB ?? "", g.ballsA ?? "", g.ballsB ?? "", g.inningsA ?? "", g.inningsB ?? "", g.hsA ?? "", g.hsB ?? "", d, t];
    }));
  }

  // Scoreboard-/Spielform-Typ aus der Disziplin ableiten. Carambus waehlt das Scoreboard
  // AUSSCHLIESSLICH anhand von free_game_form: "pool" → Pool-Board, "snooker" → Snooker-Board,
  // alles andere (inkl. "karambol") → Karambol-Board. Verlaessliches Signal ist table_kind aus
  // dem disciplines-Endpoint ("Pool"/"Snooker"/…); fehlt es, heuristisch ueber den Namen.
  function freeGameForm(opts = {}) {
    const tk = String(opts.tableKind || "").trim().toLowerCase();
    if (tk === "pool") return "pool";
    if (tk === "snooker") return "snooker";
    if (tk) return "karambol"; // bekannter Karambol-/Kegel-Tischtyp (Small/Match Billard, …)
    const d = String(opts.discipline || "").toLowerCase();
    if (/snooker/.test(d)) return "snooker";
    if (/pool|\b\d+\s*-?\s*ball\b|14[.\/]1/.test(d)) return "pool";
    return "karambol";
  }

  // Phase 21-07: kurze Anzeige-Suffixe für Spieler-Felder (age_class/gender). Leerstring,
  // wenn beide null (Spieler ohne qualifizierte seedings) — damit nichts hängen bleibt.
  function playerAgeGender(p) { return [p && p.age_class, p && p.gender].filter(Boolean).join(" · "); }

  // ===== Ergebnisarchiv: Zeilen-Normalisierung ============================
  // Die Anzeige in Carambus (app/views/tournaments/show.html.erb) stellt vier
  // Bedingungen. Sie werden hier EINMAL durchgesetzt, damit sie kein Schema
  // einzeln treffen muss — und weil drei davon still fehlschlagen:
  //   1. Spaltenkoepfe kommen aus .keys des ERSTEN Records. Alle Zeilen brauchen
  //      dieselben Keys in derselben Reihenfolge, sonst fehlen Spalten.
  //   2. Eine Spielzeile ohne "Ergebnis" (oder "Punkte") wird stumm uebersprungen.
  //   3. Sortiert wird ueber data["Partie"].to_i — "Partie" ist immer eine Zahl.
  //   4. "Rank" steuert die Sortierung des Endstands, als Integer.
  // "Heim"/"Gast" meiden wir bei Einzelturnieren bewusst: sind die Spalten vorhanden
  // und leer, bricht die Zeilenausgabe ab dieser Stelle ab (das skip-Flag in der View
  // wird innerhalb der Zeile nicht zurueckgesetzt). Mannschaftsschemata fuellen beide.
  function unifyColumns(rows) {
    const keys = [];
    rows.forEach(r => Object.keys(r.columns || {}).forEach(k => { if (!keys.includes(k)) keys.push(k); }));
    return rows.map(r => {
      const c = {};
      keys.forEach(k => { const v = (r.columns || {})[k]; c[k] = v == null ? "" : String(v); });
      return { ...r, columns: c };
    });
  }
  // entries: [{ player:{cc_id,dbu_nr,firstname,lastname}|null, rank, columns:{...} }]
  function buildResultStandings(entries) {
    const rows = unifyColumns((entries || []).map((e, i) => ({
      player: e.player || null,
      rank: Number.isFinite(+e.rank) ? +e.rank : i + 1,
      columns: e.columns || {}
    })));
    // Rank NACH der Vereinheitlichung setzen: unifyColumns stringifiziert, der
    // Vertrag verlangt hier aber eine Zahl.
    return rows.map(r => ({ ...r, columns: { ...r.columns, Rank: r.rank } }));
  }
  // rows: [{ gname, seqno, group_no, round_no, table_no, started_at, ended_at, columns:{...} }]
  function buildResultGames(rows) {
    return unifyColumns((rows || []).map((r, i) => {
      const columns = { ...(r.columns || {}) };
      if (columns.Partie == null || columns.Partie === "") columns.Partie = i + 1;
      // Ohne Ergebnis verschluckt die View die Zeile kommentarlos — lieber ein
      // sichtbarer Strich als eine Partie, die im Archiv fehlt.
      if (!columns.Ergebnis && !columns.Punkte) columns.Ergebnis = "—";
      return {
        gname: r.gname != null ? String(r.gname) : `g${i + 1}`,
        seqno: r.seqno != null ? r.seqno : i + 1,
        group_no: r.group_no ?? null, round_no: r.round_no ?? null, table_no: r.table_no ?? null,
        started_at: r.started_at || null, ended_at: r.ended_at || null,
        columns
      };
    }));
  }

  const util = { calcAvg, fmtAvg, escapeHtml, shuffle, tableNo, csvCell, buildCsv, downloadText, downloadJson, buildRankingCsv, buildGamesCsv, buildResultStandings, buildResultGames, freeGameForm, playerAgeGender };

  // ========================= Schema-State (localStorage, Einzelinstanz) =====
  // Legacy: ein State je Schema (z. B. 3-Band). Für instanzfähige Schemata siehe
  // die Instanz-Funktionen weiter unten.
  const STATE_PREFIX = "carambus.scheme.";
  function schemeKey(id) { return STATE_PREFIX + id; }
  function loadSchemeState(id, makeDefault) {
    try { const raw = localStorage.getItem(schemeKey(id)); if (raw) return JSON.parse(raw); }
    catch (e) { console.warn("State-Load fehlgeschlagen:", e); }
    return makeDefault ? makeDefault() : null;
  }
  function saveSchemeState(id, state) { localStorage.setItem(schemeKey(id), JSON.stringify(state)); }
  function clearSchemeState(id) { localStorage.removeItem(schemeKey(id)); }

  // ===== Turnier-Instanzen (mehrere parallele Turniere je Schema) ===========
  // Jede Instanz = ein eigenständiges Turnier (eigener State unter
  // carambus.instance.<id>). Ein Index (carambus.instances) hält die Metadaten
  // (Schema, Titel, Kategorie, Zeitstempel) für den Turnier-Manager im Launcher.
  const INSTANCE_PREFIX = "carambus.instance.";
  const INSTANCE_INDEX = "carambus.instances";

  function listInstances() {
    try { return JSON.parse(localStorage.getItem(INSTANCE_INDEX) || "[]"); }
    catch (e) { return []; }
  }
  function writeInstanceIndex(arr) { localStorage.setItem(INSTANCE_INDEX, JSON.stringify(arr)); }

  // Optional `discipline`, `source` (z. B. "registration_list:<cc_id>"),
  // `preselectedPlayers` (Array bereinigter Spieler-Refs für die Setzliste) und
  // `partyCcId` (Liga-Spieltag — schaltet das spieltag-Schema in den Live-Modus, Phase 6)
  // können beim Anlegen mitgegeben werden; das Schema liest sie beim ersten defaultState
  // aus instance.*.
  function createInstance({ schemeId, title, category, discipline, source, preselectedPlayers, partyCcId, attachTournamentId } = {}) {
    const id = `${schemeId}-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 6)}`;
    const rec = {
      id, schemeId,
      title: (title && title.trim()) || "Unbenanntes Turnier",
      category: (category || "").trim(),
      createdAt: Date.now(), updatedAt: Date.now()
    };
    if (discipline) rec.discipline = String(discipline);
    if (source) rec.source = String(source);
    if (partyCcId) rec.party_cc_id = String(partyCcId);
    // Attach-Modus (plan-Schema): PK eines im Carambus-Web angelegten Turniers, an das die
    // App sich anhängt (statt selbst Turnier anzulegen). Multi-Laptop-/Multi-Tag-fähig.
    if (attachTournamentId != null && String(attachTournamentId).trim() !== "") {
      rec.attach_tournament_id = String(attachTournamentId);
    }
    if (Array.isArray(preselectedPlayers) && preselectedPlayers.length) rec.preselected_players = preselectedPlayers;
    const arr = listInstances(); arr.push(rec); writeInstanceIndex(arr);
    return rec;
  }
  function getInstance(id) { return listInstances().find(r => r.id === id) || null; }
  function updateInstance(id, patch) {
    const arr = listInstances(); const r = arr.find(x => x.id === id);
    if (!r) return null;
    Object.assign(r, patch, { updatedAt: Date.now() });
    writeInstanceIndex(arr);
    return r;
  }
  function deleteInstance(id) {
    writeInstanceIndex(listInstances().filter(r => r.id !== id));
    localStorage.removeItem(INSTANCE_PREFIX + id);
  }
  function loadInstanceState(id, makeDefault) {
    try { const raw = localStorage.getItem(INSTANCE_PREFIX + id); if (raw) return JSON.parse(raw); }
    catch (e) { console.warn("Instanz-State-Load fehlgeschlagen:", e); }
    return makeDefault ? makeDefault() : null;
  }
  function saveInstanceState(id, state) { localStorage.setItem(INSTANCE_PREFIX + id, JSON.stringify(state)); }

  const storage = {
    loadSchemeState, saveSchemeState, clearSchemeState, schemeKey,
    listInstances, createInstance, getInstance, updateInstance, deleteInstance,
    loadInstanceState, saveInstanceState
  };

  // ========================= Verbindungs-Widget ============================
  const MODAL_ID = "carambusConnModal";
  const modalState = { onChange: null };

  function mountConnectionWidget({ badgeEl, onChange } = {}) {
    if (!badgeEl) throw new Error("mountConnectionWidget: badgeEl fehlt");
    ensureModal();
    badgeEl.classList.add("conn-badge");
    badgeEl.innerHTML = `<span class="dot"></span><span class="conn-badge-label">Carambus</span>`;
    badgeEl.title = "Carambus-Verbindung konfigurieren";
    badgeEl.addEventListener("click", openModal);

    function refresh() {
      const conn = getConnection();
      const label = badgeEl.querySelector(".conn-badge-label");
      badgeEl.classList.remove("connected", "error");
      if (isBearerValid(conn)) { badgeEl.classList.add("connected"); label.textContent = `Carambus: verbunden (${conn.region})`; }
      else if (conn.base_url) { label.textContent = "Carambus: nicht angemeldet"; }
      else { label.textContent = "Carambus: nicht verbunden"; }
    }
    modalState.onChange = () => { refresh(); if (onChange) onChange(getConnection()); };
    refresh();
    return { refresh, open: openModal };
  }

  function ensureModal() {
    if (document.getElementById(MODAL_ID)) return;
    const wrap = document.createElement("div");
    wrap.className = "modal-backdrop"; wrap.id = MODAL_ID;
    wrap.innerHTML = `
      <div class="modal">
        <h2>🔌 Carambus-Verbindung</h2>
        <div class="info">Einmal pro Gerät einrichten. Wird von allen Schemata geteilt. Der Token gilt 90 Tage.</div>
        <div class="form-row"><label>Base-URL (LAN)</label><input type="text" id="cwBaseUrl" placeholder="http://192.168.178.84:3131"></div>
        <div class="form-row"><label>Service-Account E-Mail</label><input type="text" id="cwEmail" placeholder="carambus-app-&lt;region&gt;-bridge@carambus.de"></div>
        <div class="form-row"><label>Region (Shortname)</label><input type="text" id="cwRegion" placeholder="NBV"></div>
        <div class="form-row"><label>Turnier (cc_id) — Quelle der Teilnehmer, optional / via Chat-Deep-Link vorausgefüllt</label><input type="text" id="cwTournamentCcId" placeholder="z. B. 939"></div>
        <div class="form-row"><label>Liga-Spieltag (Party cc_id) — optional / via Chat-Deep-Link vorausgefüllt</label><input type="text" id="cwPartyCcId" placeholder="z. B. 12345"></div>
        <div class="form-row" id="cwPasswordRow"><label>Passwort (nur für Login nötig)</label><input type="password" id="cwPassword" placeholder="········" autocomplete="current-password"></div>
        <div class="status-line" id="cwStatus"></div>
        <div class="actions">
          <button class="btn" id="cwLogin">🔑 Login &amp; Speichern</button>
          <button class="btn secondary" id="cwTest">🩺 Verbindung testen</button>
          <button class="btn secondary" id="cwClear" title="Token vergessen (erzwingt neuen Login)">Token vergessen</button>
          <button class="btn secondary" id="cwClose" style="margin-left:auto;">Schließen</button>
        </div>
      </div>`;
    document.body.appendChild(wrap);
    wrap.addEventListener("click", (e) => { if (e.target === wrap) closeModal(); });
    document.getElementById("cwClose").addEventListener("click", closeModal);
    document.getElementById("cwLogin").addEventListener("click", doLogin);
    document.getElementById("cwTest").addEventListener("click", doTest);
    document.getElementById("cwClear").addEventListener("click", doClear);
  }
  function openModal() {
    const conn = getConnection();
    document.getElementById("cwBaseUrl").value = conn.base_url || "";
    document.getElementById("cwEmail").value = conn.email || "";
    document.getElementById("cwRegion").value = conn.region || "";
    document.getElementById("cwTournamentCcId").value = conn.tournament_cc_id || "";
    document.getElementById("cwPartyCcId").value = conn.party_cc_id || "";
    document.getElementById("cwPassword").value = "";
    setStatus("", "");
    document.getElementById(MODAL_ID).classList.add("open");
  }
  function closeModal() { document.getElementById(MODAL_ID).classList.remove("open"); }
  function readForm() {
    return {
      base_url: document.getElementById("cwBaseUrl").value.trim(),
      email: document.getElementById("cwEmail").value.trim(),
      region: document.getElementById("cwRegion").value.trim().toUpperCase(),
      tournament_cc_id: document.getElementById("cwTournamentCcId").value.trim(),
      party_cc_id: document.getElementById("cwPartyCcId").value.trim(),
      password: document.getElementById("cwPassword").value
    };
  }
  function setStatus(msg, kind) {
    const el = document.getElementById("cwStatus");
    el.textContent = msg;
    el.className = "status-line" + (msg ? " show" : "") + (kind ? " " + kind : "");
  }
  async function doLogin() {
    const f = readForm();
    if (!f.base_url || !f.email) { setStatus("Base-URL und E-Mail sind nötig.", "err"); return; }
    const conn = getConnection();
    // Wenn der TL cc_id manuell ändert, ist die per Deep-Link gesetzte tournament_id (DB-PK)
    // u. U. nicht mehr passend → leeren, damit fetchSeeding wieder über cc_id+region auflöst.
    if (String(f.tournament_cc_id || "") !== String(conn.tournament_cc_id || "")) conn.tournament_id = "";
    conn.base_url = f.base_url; conn.email = f.email; conn.region = f.region; conn.tournament_cc_id = f.tournament_cc_id;
    conn.party_cc_id = f.party_cc_id || "";
    if (!f.password && isBearerValid(conn)) {
      saveConnection(conn); setStatus("Gespeichert (bestehender Token bleibt gültig).", "ok");
      modalState.onChange && modalState.onChange(); return;
    }
    if (!f.password) { setStatus("Passwort eingeben (für den ersten Login / nach 'Token vergessen').", "err"); return; }
    setStatus("Melde an …", "");
    try {
      const { bearer, expires_at } = await carambusLogin(f.base_url, f.email, f.password);
      conn.bearer = bearer; conn.bearer_expires_at = expires_at;
      saveConnection(conn); setStatus("✓ Angemeldet und gespeichert.", "ok");
      modalState.onChange && modalState.onChange();
    } catch (err) { setStatus("Login fehlgeschlagen: " + describeErr(err), "err"); }
  }
  async function doTest() {
    const f = readForm();
    const conn = getConnection();
    conn.base_url = f.base_url || conn.base_url; conn.region = f.region || conn.region; conn.email = f.email || conn.email;
    if (f.tournament_cc_id !== undefined) {
      if (String(f.tournament_cc_id || "") !== String(conn.tournament_cc_id || "")) conn.tournament_id = "";
      conn.tournament_cc_id = f.tournament_cc_id;
    }
    if (f.party_cc_id !== undefined) conn.party_cc_id = f.party_cc_id || "";
    saveConnection(conn);
    if (!isBearerValid(conn)) { setStatus("Kein gültiger Token — bitte zuerst Login.", "err"); return; }
    setStatus("Teste …", "");
    try { const r = await ping(); setStatus("✓ Verbindung OK" + (r.note ? " — " + r.note : ""), "ok"); modalState.onChange && modalState.onChange(); }
    catch (err) { setStatus("Fehler: " + describeErr(err), "err"); }
  }
  function doClear() {
    const conn = getConnection();
    conn.bearer = null; conn.bearer_expires_at = null;
    saveConnection(conn); setStatus("Token vergessen. Nächster Login nötig.", "ok");
    modalState.onChange && modalState.onChange();
  }
  function describeErr(err) {
    if (err instanceof CarambusError) {
      const detail = err.body != null ? " " + (typeof err.body === "string" ? err.body : JSON.stringify(err.body)) : "";
      return `HTTP ${err.status}${detail}`;
    }
    return err?.message || String(err);
  }

  // ========================= Öffentliche Schnittstelle =====================
  return {
    CONN_KEY, CONN_DEFAULTS,
    getConnection, saveConnection, isBearerValid, regionShortname, parseTournamentCcIdInput, applyDeepLinkConnection,
    CarambusError, fetchWithTimeout, carambusLogin,
    carambusFetch, ping,
    api: {
      fetchClubs, fetchClubPlayers, fetchPlayerRankings, fetchTables, fetchDisciplines, fetchRegistrationLists, fetchSeeding,
      createTournament, lockTable, startGame, acknowledgeResult, endTournament, cleanPlayerRef,
      pushTournamentResult,
      fetchRoundResult, fetchAllRoundResults,
      fetchParty, partyGameResult, partyClose
    },
    util, storage, mountConnectionWidget
  };
})();
