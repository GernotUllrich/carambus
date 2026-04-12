# Phase 24: Data Source Investigation - Research

**Researched:** 2026-04-12
**Domain:** Web scraping investigation — UMB, Cuesco/Five&Six, SoopLive structured data availability
**Confidence:** MEDIUM — codebase verified HIGH; live endpoint behavior MEDIUM (WebFetch probed); hidden AJAX API endpoints LOW (require browser DevTools)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Claude's discretion on approach per source — may use Ruby probe scripts (Net::HTTP + Nokogiri), WebFetch, or document manual browser inspection steps depending on what works for each source
- **D-02:** Focus on `umb.cuesco.net` jsRender-backed AJAX endpoints as highest-priority discovery target (research identified these as most likely structured data path)
- **D-03:** Per-source deep dive format — one section per source (UMB events, Cuesco, SoopLive, Kozoom) with full technical details, sample responses, and verdict
- **D-04:** Document goes to `.planning/phases/24-data-source-investigation/24-FINDINGS.md`
- **D-05:** "Structured is enough" — if a source returns structured data (JSON/XML) at all, it's worth building an adapter even if it only covers a subset of what current UMB HTML scraping provides. Fill gaps from UMB HTML as fallback.
- **D-06:** Do NOT require a source to cover >=80% of current data. Any structured subset is valuable.
- **D-07:** Existence check only — confirm whether structured endpoints exist or not per source. Do NOT characterize pagination, rate limits, auth requirements, or error handling in this phase. Leave deep analysis to Phase 25+.
- **D-08:** Get 1-2 sample responses where a structured endpoint is found (enough to confirm data format), but don't exhaustively test.

### Claude's Discretion
- Investigation method choice per source (D-01)
- Order of source investigation
- Whether to use WebFetch directly or write throwaway scripts
- How to handle sources that require authentication

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INVEST-01 | Probe `umbevents.umb-carom.org/Reports/` endpoints for JSON responses under different Accept headers | Research confirms endpoints return HTTP 500 under WebFetch; probe script needed with request headers |
| INVEST-02 | Inspect `umb.cuesco.net` network traffic to discover AJAX/JSON endpoints for match data | Research confirms umb.cuesco.net is ECONNREFUSED in this environment; browser DevTools guidance required |
| INVEST-03 | Inspect `billiards.sooplive.com/schedule/` pages to discover structured VOD/match data endpoints | Research confirms jsRender templating hides API URLs from HTML source; browser DevTools required |
| INVEST-04 | Document findings: data availability, completeness vs current UMB scraping, go/no-go decision | Output is 24-FINDINGS.md in the phase directory |
</phase_requirements>

---

## Summary

Phase 24 is a pure investigation phase. The output is not code — it is a written findings document (`24-FINDINGS.md`) that gates the refactoring architecture for Phases 25–28. The plan must produce systematic probe steps for three sources that could not be fully characterized by static HTML fetching alone.

**Key discovery from research:** All three investigation targets (umbevents.umb-carom.org, umb.cuesco.net, billiards.sooplive.com) load their match data via client-side JavaScript that calls hidden AJAX/REST endpoints. These URLs are not present in the HTML source — they are only visible in browser network traffic. This means the investigation plan must distinguish between two probe strategies: (1) direct HTTP probing where an endpoint URL can be guessed or is known, and (2) browser-inspection guidance for the human executor where the endpoint URL must be discovered first.

**Primary recommendation:** Plan three probe tasks (one per target source) plus one findings-writing task. Each probe task should specify the testable sub-question, the recommended tool (Ruby Net::HTTP script or browser inspection), and what constitutes a pass/fail outcome. The findings task should consolidate per-source verdicts into the go/no-go decision format.

---

## Investigation Target Summary

### What Is Already Known (HIGH confidence from prior research)

| Source | Current State | What Needs Probing |
|--------|--------------|-------------------|
| `files.umb-carom.org` | Confirmed HTML-only. Sequential IDs to 500, known URL patterns. No undiscovered API. | Nothing — fully characterized. Not an investigation target. |
| `umbevents.umb-carom.org/Reports/` | HTML pages confirmed, jQuery UI. `/Reports/ViewAllRanks`, `/ViewTimetable`, `/ViewPlayers`, etc. known. Login required for some. | Whether endpoints respond to `Accept: application/json` or have JSON-returning query params. Reports returned HTTP 500 under WebFetch — may require auth or specific parameters. |
| `umb.cuesco.net` | jsRender-based (`{{:match_no}}` template vars). ECONNREFUSED under WebFetch — domain not accessible from this environment. | The AJAX API URL that jsRender calls to populate templates. Must be found via browser network tab. |
| `billiards.sooplive.com/schedule/` | jsRender-based templates. Data-seq/data-broad_no attributes confirmed. API URL hidden in external JS bundle — not in HTML. | The REST endpoint(s) that populate the schedule/results templates. Must be found via browser network tab. |
| `api.kozoom.com` | Already integrated REST JSON API in KozoomScraper. `/events/days`, `/videos` endpoints known and working. | Nothing — fully characterized. Not an investigation target. |

[VERIFIED: WebFetch probe of umbevents.umb-carom.org — HTTP 500 on /Reports/ paths]
[VERIFIED: WebFetch probe of umb.cuesco.net — ECONNREFUSED]
[VERIFIED: WebFetch probe of billiards.sooplive.com/schedule/156 — page loads but API URL not in HTML source]
[VERIFIED: FEATURES.md — Cuesco jsRender template pattern, SoopLive data-seq confirmed]
[VERIFIED: STACK.md — Kozoom already integrated, files.umb-carom.org confirmed HTML-only]

---

## Architecture Patterns

### Investigation Method by Source

The three probe approaches depend on what is accessible programmatically:

#### Pattern A: Direct HTTP Probe (Net::HTTP with custom headers)

Use when: An endpoint URL is known or can be guessed, and the question is just "what does it return?"

Applies to: `umbevents.umb-carom.org/Reports/ViewAllRanks` and similar paths (URLs are known, response format is unknown).

```ruby
# Throwaway probe script — does not get committed to the codebase
# Run with: bundle exec ruby tmp/probe_umbevents.rb

require 'net/http'
require 'json'
require 'uri'

def probe(url, headers = {})
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.read_timeout = 15

  request = Net::HTTP::Get.new(uri.path + (uri.query ? "?#{uri.query}" : ""), headers)
  response = http.request(request)

  puts "Status: #{response.code}"
  puts "Content-Type: #{response['content-type']}"
  puts "Body (first 500 chars):"
  puts response.body[0..500]
rescue => e
  puts "Error: #{e.message}"
end

# Probe 1: Default (HTML)
probe("https://umbevents.umb-carom.org/Reports/ViewAllRanks")

# Probe 2: Ask for JSON
probe("https://umbevents.umb-carom.org/Reports/ViewAllRanks",
      "Accept" => "application/json",
      "X-Requested-With" => "XMLHttpRequest")

# Probe 3: With event_id parameter (common in tournament sites)
probe("https://umbevents.umb-carom.org/Reports/ViewAllRanks?event_id=1")
```

[ASSUMED] The `/Reports/` endpoints may require a session cookie or event ID parameter — the HTTP 500 responses seen in research may be parameter-missing errors rather than auth failures. The probe script should try multiple parameter variations.

#### Pattern B: Browser DevTools Inspection (Manual)

Use when: The page loads data via JavaScript from a hidden API URL, and the URL itself is not in the HTML source.

Applies to: `umb.cuesco.net` and `billiards.sooplive.com/schedule/[N]`.

The plan must document step-by-step browser inspection instructions that a developer follows manually:

```
1. Open Chrome/Firefox DevTools (F12)
2. Go to Network tab, filter by "XHR" or "Fetch"
3. Navigate to the target URL
4. Wait for the page to fully load (data populates in the template)
5. Identify all XHR/Fetch requests that return JSON
6. Copy the URL, request headers, and response body (first 1-2 matches)
7. Document in 24-FINDINGS.md
```

This approach is required for Cuesco and SoopLive because their AJAX endpoint URLs are loaded from external JavaScript bundles (not the HTML source), and those bundles are minified/bundled in ways that make static analysis impractical.

[VERIFIED: WebFetch probe of billiards.sooplive.com/schedule/156 — confirmed API URL not in HTML; external JS bundles not accessible via WebFetch]

#### Pattern C: URL Pattern Inference + Direct Probe

Use when: Prior research or community sources suggest a likely API path that can be probed directly.

Applies to: Any source where a plausible API URL pattern can be constructed from what's known.

For SoopLive: The VOD URLs follow `https://vod.sooplive.com/player/[ID]` — this suggests an API at `https://api.sooplive.com/` or similar. Try probing `https://billiards.sooplive.com/schedule/api/127` or `https://billiards.sooplive.com/api/schedule/127`.

[ASSUMED] SoopLive likely has an internal API at a path like `/api/schedule/[N]/matches` or similar. This is a guess based on common web app patterns — needs verification.

---

## Probe Task Specifications

Each investigation task needs a clear sub-question, a method, and a pass/fail criterion.

### Task A: umbevents.umb-carom.org JSON Probe (INVEST-01)

**Sub-question:** Do any `/Reports/` endpoints return JSON when requested with `Accept: application/json` or `X-Requested-With: XMLHttpRequest`?

**Method:** Ruby probe script (Pattern A above). Run from repo root: `bundle exec ruby tmp/probe_umbevents.rb`.

**Probe URLs:**
- `https://umbevents.umb-carom.org/Reports/ViewAllRanks`
- `https://umbevents.umb-carom.org/Reports/ViewTimetable`
- `https://umbevents.umb-carom.org/Reports/ViewPlayers`
- Each with: default headers, `Accept: application/json`, `Accept: application/json` + `X-Requested-With: XMLHttpRequest`

**Pass criterion (GO):** Any endpoint returns `Content-Type: application/json` and parseable JSON with tournament/match data fields.

**Fail criterion (NO-GO):** All endpoints return HTML, require authentication that cannot be bypassed, or return HTTP 4xx/5xx for all header combinations.

**Sample collection:** If JSON found, save 1-2 full response bodies to `tmp/samples/umbevents/`.

**Important note:** The HTTP 500 responses seen during research may indicate that the endpoints require specific query parameters (event ID, year) rather than just headers. The probe script should try the base URL, then add `?event_id=1`, `?year=2025`, `?id=1`.

[ASSUMED] A session cookie from a prior login may be required — if all unauthenticated probes return 500, document that auth is a blocker and mark as requiring manual browser inspection.

### Task B: umb.cuesco.net AJAX Endpoint Discovery (INVEST-02)

**Sub-question:** What AJAX/JSON API endpoints does umb.cuesco.net use to populate match data in its jsRender templates?

**Method:** Browser DevTools inspection (Pattern B). The domain was ECONNREFUSED from this research environment — it may require VPN or be temporarily down — but the site is listed as accessible on the cuesco.eu homepage.

**Step-by-step instructions for executor:**
1. Open Chrome DevTools (F12) → Network tab → Filter "XHR"
2. Navigate to `http://umb.cuesco.net/` (note: HTTP, not HTTPS — cuesco.eu uses HTTP)
3. Click on a live or recent tournament
4. Record all XHR/Fetch requests that return non-HTML content
5. For each JSON-returning request: copy URL, method, request headers, and first 200 lines of response
6. Look specifically for endpoints returning match arrays with player names, scores, and round data

**Fallback if site is down:** Navigate to `https://cuesco.eu` → find a live tournament on the site map → apply same DevTools inspection.

**Pass criterion (GO):** JSON endpoint found returning structured match data (player names, scores, round, group).

**Fail criterion (NO-GO):** All requests return HTML, or site requires authenticated session that cannot be established.

**Sample collection:** If JSON found, save the raw response to `tmp/samples/cuesco/`.

[VERIFIED: FEATURES.md — "jsRender-style {{:match_no}} template variables seen in DOM" — confirms AJAX data loading exists; endpoint URL unknown]
[ASSUMED] The cuesco.eu API may use a sub-path like `/api/matches/` or `/Match/GetMatchData` — document any URL patterns visible in the network tab even if the response is non-JSON.

### Task C: billiards.sooplive.com API Discovery (INVEST-03)

**Sub-question:** What REST API endpoint populates `billiards.sooplive.com/schedule/[N]` with match data? Do the data-seq attributes contain numeric VOD IDs in the actual responses?

**Method:** Browser DevTools inspection (Pattern B) + URL pattern inference (Pattern C).

**Direct probes to try first (from research evidence):**
- `https://billiards.sooplive.com/api/schedule/127` (common Rails-style API path)
- `https://billiards.sooplive.com/schedule/127/matches` (REST convention)
- `https://billiards.sooplive.com/schedule/127.json` (Rails content negotiation)

**Browser inspection step-by-step:**
1. Open Chrome DevTools → Network tab → Filter "Fetch/XHR"
2. Navigate to `https://billiards.sooplive.com/schedule/127?sub1=result`
3. Wait for match results to load (player names and scores should appear)
4. Find the XHR/Fetch request that populated the match list
5. Copy the exact URL, and 1-2 complete match records from the JSON response

**Specific data points to capture if JSON found:**
- Field names for: tournament title, player names, scores, round, group, match sequence ID, VOD broadcast number
- Whether `data-seq` values match a `vod.sooplive.com/player/[ID]` URL pattern (confirms VOD linkage)

**Pass criterion (GO):** JSON endpoint found with match data including player names, scores, and a linkable VOD or broadcast ID.

**Fail criterion (NO-GO):** All requests return HTML or 401/403; match data only available by scraping rendered HTML.

**Sample collection:** If JSON found, save 1-2 full match records (not entire response) to `tmp/samples/sooplive/`.

[VERIFIED: billiards.sooplive.com/schedule/156 — data-seq="{{:match_no}}", data-broad_no="{{:broad_no}}" template variables confirmed in HTML]
[VERIFIED: FEATURES.md — "SoopLive match pages embed VOD IDs directly in data-seq attributes" — this is the high-precision cross-reference target]
[ASSUMED] The API base URL for SoopLive schedule data likely resolves to a sub-path under `billiards.sooplive.com` — but may also be on a separate API subdomain (api.sooplive.com or similar).

---

## Findings Document Format (INVEST-04)

The `24-FINDINGS.md` document should follow this structure. The planner should create a plan that writes this document as the phase's primary deliverable.

```markdown
# Phase 24: Data Source Investigation — Findings

**Investigated:** [date]
**Investigator:** [name]

## Executive Summary

[One paragraph: what was found, what was not found, go/no-go verdicts]

## Source 1: umbevents.umb-carom.org

**Probe method:** [Ruby Net::HTTP script / manual inspection]
**Endpoints tested:** [list]
**Results:** [HTTP codes, content types, response excerpts]
**Sample response:** [if JSON found, first 20-30 lines]
**Verdict:** GO / NO-GO
**Rationale:** [why]

## Source 2: umb.cuesco.net (Cuesco/Five&Six)

[Same structure]

## Source 3: billiards.sooplive.com

[Same structure]
**VOD linkage finding:** [can data-seq values be used to construct vod.sooplive.com/player/[ID] URLs?]

## Architecture Impact

**If any GO verdict:**
- JSON API found → UmbScraper refactoring should include a lightweight API client layer
- HTML scraping becomes fallback, not primary path
- Phase 26 service boundary: add `Umb::CuescoClient` or `Umb::SoopClient` alongside HTML parsers

**If all NO-GO verdicts:**
- No architecture change required
- Phase 26 proceeds with HTML-scraping-only service extraction
- SoopLive video cross-referencing in Phase 28 uses title+date matching only (no data-seq linking)

## Go/No-Go Decision

| Source | Verdict | Data Available | Adapter Worth Building? |
|--------|---------|----------------|------------------------|
| umbevents | GO/NO-GO | [fields list] | YES/NO |
| Cuesco | GO/NO-GO | [fields list] | YES/NO |
| SoopLive | GO/NO-GO | [fields list] | YES/NO |
```

---

## Common Pitfalls

### Pitfall 1: Treating HTTP 500 as "endpoint does not exist"
**What goes wrong:** The umbevents.umb-carom.org/Reports/ endpoints return HTTP 500 during WebFetch probing. This looks like the server is broken, but is likely a parameter-missing error (the endpoint requires query parameters like event_id that were not provided).
**How to avoid:** Try the URL with `?id=1`, `?event_id=1`, `?year=2025` before concluding a NO-GO. The endpoint returning 500 with no parameters is different from returning 500 with all required parameters.
**Warning signs:** HTTP 500 with an HTML error page containing "Required parameter" or similar — look at the error body.

### Pitfall 2: Concluding NO-GO from HTML-source inspection alone
**What goes wrong:** WebFetch returns HTML with jsRender placeholders — no API URL visible. Executor concludes "no JSON API exists."
**Reality:** The API URL is in an external JavaScript bundle, not the HTML. The API almost certainly exists (the page works in browsers). The correct conclusion is "API URL not discoverable from static HTML — requires browser DevTools."
**How to avoid:** Any site using jsRender/Mustache/Handlebars templates should be investigated with browser DevTools, not static HTML analysis.

### Pitfall 3: Confusing SoopLive Open API with the billiards schedule API
**What goes wrong:** The SOOP Open API at `openapi.sooplive.co.kr` is documented — executor finds it and concludes "SoopLive has no match data API."
**Reality:** The Open API covers VOD embedding and broadcast management. The billiards schedule/match data is served by a separate, undocumented internal API at `billiards.sooplive.com`. These are different systems.
**How to avoid:** The investigation target is `billiards.sooplive.com/schedule/[N]`, not the Open API.

[VERIFIED: openapi.sooplive.co.kr/apidoc — confirmed Open API covers VOD embedding and streaming only, no match/schedule data]

### Pitfall 4: umb.cuesco.net connectivity issues
**What goes wrong:** `umb.cuesco.net` returns ECONNREFUSED or times out in the development environment. Executor concludes "site is down."
**Reality:** The domain uses HTTP (not HTTPS) and may be blocked by network security policies or firewalls. The cuesco.eu homepage confirms the product is actively used.
**How to avoid:** Try both `http://umb.cuesco.net/` and `https://umb.cuesco.net/`. If still blocked, use browser with VPN or try from a different network. The investigation can proceed with cuesco.eu if umb.cuesco.net is inaccessible.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| HTTP probe scripts | Custom HTTP library | `net/http` (already used in all scrapers) — reuse `fetch_url` pattern from UmbScraperV2 |
| JSON parsing in probe scripts | Custom parser | `JSON.parse` (stdlib) |
| Sample response storage | Database | `tmp/samples/[source]/` directory with `.json` files — throwaway, gitignored |

---

## Code Examples

### Reusable fetch_url Pattern (from UmbScraperV2)

```ruby
# Source: app/services/umb_scraper_v2.rb lines 57-91
# Copy this pattern verbatim into probe scripts — it handles redirects and SSL

def fetch_url(url, headers = {})
  uri = URI(url)
  redirects = 0
  max_redirects = 5

  loop do
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # OK for probe scripts
    http.read_timeout = 15

    path = uri.path.empty? ? '/' : uri.path
    path += "?#{uri.query}" if uri.query
    request = Net::HTTP::Get.new(path, headers)

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      return response
    when Net::HTTPRedirection
      redirects += 1
      return nil if redirects >= max_redirects
      location = response['location']
      uri = location.start_with?('http') ? URI(location) : URI.join(uri, location)
    else
      puts "HTTP #{response.code} for #{url}"
      return response  # Return non-success for inspection
    end
  end
rescue => e
  puts "Error: #{e.message}"
  nil
end
```

### Accept Header Probe

```ruby
# Pattern for probing JSON vs HTML response format
headers_to_try = [
  {},
  { "Accept" => "application/json" },
  { "Accept" => "application/json", "X-Requested-With" => "XMLHttpRequest" },
  { "Accept" => "application/json, text/javascript, */*; q=0.01",
    "X-Requested-With" => "XMLHttpRequest" }
]

headers_to_try.each do |headers|
  response = fetch_url("https://umbevents.umb-carom.org/Reports/ViewAllRanks", headers)
  next unless response
  puts "Headers: #{headers}"
  puts "Status: #{response.code}"
  puts "Content-Type: #{response['content-type']}"
  puts "Body prefix: #{response.body[0..200]}"
  puts "---"
end
```

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| net/http | Probe scripts | ✓ | Ruby stdlib | — |
| Nokogiri | HTML parsing if needed | ✓ | Already in Gemfile | — |
| Chrome/Firefox DevTools | Cuesco + SoopLive investigation | ✓ | Browser with DevTools | Any browser with Network tab |
| `tmp/` directory | Sample storage | ✓ | Already exists (gitignored) | Create if missing |
| umbevents.umb-carom.org | INVEST-01 | Accessible (HTTP 500 on /Reports/) | Unknown version | None — required |
| umb.cuesco.net | INVEST-02 | ECONNREFUSED from this environment | — | Try from browser or different network |
| billiards.sooplive.com | INVEST-03 | ✓ (pages load) | — | — |

**Missing dependencies with no fallback:**
- None that would block the full investigation — umb.cuesco.net accessibility issue can be worked around with browser inspection from any network.

**Missing dependencies with fallback:**
- umb.cuesco.net inaccessible from dev machine → use browser with VPN, or inspect via cuesco.eu.

[VERIFIED: WebFetch probe of umbevents.umb-carom.org/ — homepage loads, login link present]
[VERIFIED: WebFetch probe of billiards.sooplive.com/schedule/ — site loads correctly]
[VERIFIED: WebFetch probe of umb.cuesco.net — ECONNREFUSED]

---

## Project Constraints (from CLAUDE.md)

- **No new gems:** Zero new dependencies for this phase. All probing uses `net/http` (Ruby stdlib) already used in all five scrapers. [VERIFIED: STACK.md — "Zero new gems required for this milestone"]
- **Probe scripts go in `tmp/`** — not committed to `app/services/`. These are throwaway investigation scripts.
- **Minitest, not RSpec** — not applicable for this phase (no test files in the investigation phase).
- **Frozen string literal** — not applicable for throwaway probe scripts, but would apply if any code were committed.
- **`frozen_string_literal: true`** — add to any Ruby file that gets committed.
- **German comments for business logic** — not applicable (no business logic in probe scripts).
- **`bin/rails test` must stay green** — investigation phase adds no production code, so no risk.
- **`brakeman` must stay clean** — investigation phase adds no production code, so no risk.
- **Behavior preservation** — investigation phase changes no behavior.

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | HTTP 500 on umbevents /Reports/ may be a parameter-missing error, not auth failure | Pitfall 1, Task A | If actually auth-required, all unauthenticated probes will fail — need to document as blocker |
| A2 | SoopLive billiards schedule data is served from a separate internal API under `billiards.sooplive.com` | Task C | If served from `api.sooplive.com` or different domain, direct URL guesses will fail — browser DevTools required |
| A3 | Cuesco AJAX API URL is discoverable via browser DevTools network tab | Task B | If API traffic is obfuscated or uses WebSockets, endpoint may not be visible as a standard XHR call |
| A4 | `tmp/` directory exists and is gitignored for sample response storage | Architecture Patterns | Create `tmp/samples/` if missing; verify `.gitignore` covers `tmp/` |

---

## Open Questions

1. **Does umbevents require authentication for all `/Reports/` paths?**
   - What we know: Homepage loads without auth; `/Reports/` paths return HTTP 500 via WebFetch
   - What's unclear: Whether 500 = missing params or 500 = auth wall
   - Recommendation: The probe script should inspect the response body for clues (error message content)

2. **Is umb.cuesco.net accessible from the development machine?**
   - What we know: ECONNREFUSED during research; cuesco.eu confirms the product is active
   - What's unclear: Whether this is a firewall issue, DNS issue, or temporary outage
   - Recommendation: Try `curl -v http://umb.cuesco.net/` from terminal. If blocked, proceed with browser + VPN.

3. **What sequential IDs do SoopLive schedule pages use?**
   - What we know: IDs 127 (Ho Chi Minh), 129, 130, 137 (Porto), 156 (Antwerp) confirmed — these match World Cup 2025 events
   - What's unclear: Full ID range for archive coverage
   - Recommendation: Not needed for this phase (D-07: existence check only, not deep characterization)

---

## Sources

### Primary (HIGH confidence)
- `app/services/umb_scraper_v2.rb` — fetch_url pattern, HTTP handling, redirect logic
- `app/services/umb_scraper.rb` — BASE_URL patterns, tournament ID range
- `app/services/kozoom_scraper.rb` — REST JSON API integration pattern (model for what success looks like)
- `.planning/research/STACK.md` — umbevents URL patterns, HTML-only confirmation for files.umb-carom.org
- `.planning/research/FEATURES.md` — Cuesco jsRender templates, SoopLive data-seq, Kozoom confirmed structured
- `.planning/phases/24-data-source-investigation/24-CONTEXT.md` — locked decisions and phase scope

### Secondary (MEDIUM confidence)
- WebFetch probe: `umbevents.umb-carom.org/` — homepage structure, navigation links, login requirement confirmed
- WebFetch probe: `billiards.sooplive.com/schedule/156?sub1=result` — jsRender template placeholders confirmed, API URL not in HTML
- WebFetch probe: `billiards.sooplive.com/schedule/127?sub1=result` — data-seq="{{:match_no}}", data-broad_no="{{:broad_no}}" confirmed
- WebFetch probe: `openapi.sooplive.co.kr/apidoc` — Open API covers VOD/broadcast only, not match data

### Tertiary (LOW confidence — needs verification)
- ASSUMED: umbevents /Reports/ HTTP 500 is parameter-missing, not auth-only
- ASSUMED: SoopLive internal API is accessible from `billiards.sooplive.com/api/` or similar path
- ASSUMED: Cuesco AJAX endpoint discoverable via DevTools XHR filter

---

## Metadata

**Confidence breakdown:**
- umbevents endpoint behavior: LOW — HTTP 500 observed but root cause unknown; probing required
- Cuesco API existence: MEDIUM — jsRender templates confirm AJAX data loading, but URL unknown
- SoopLive API existence: MEDIUM — jsRender templates confirm AJAX data loading, data-seq confirmed, URL unknown
- Kozoom (already known): HIGH — integrated and working
- files.umb-carom.org (already known): HIGH — HTML-only confirmed

**Research date:** 2026-04-12
**Valid until:** 2026-05-12 (stable target sites, but API endpoints may change)
