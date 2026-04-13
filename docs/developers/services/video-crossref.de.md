# Video:: — Cross-Referencing System

Das Video:: Cross-Referencing System verknuepft `Video`-Datensaetze mit `InternationalTournament`- oder `InternationalGame`-Datensaetzen. Fuer UMB- und Kozoom-Videos wird Confidence-Scoring (`Video::TournamentMatcher`) kombiniert mit strukturierter Metadatenextraktion (`Video::MetadataExtractor`) verwendet. Fuer SoopLive-Videos erfolgt die Verknuepfung direkt ueber die `replay_no` aus der SoopLive JSON API (`SoopliveBilliardsClient`).

> **Hinweis:** Anders als andere Service-Namespaces liegen die `Video::`-Klassen in `app/models/video/`, nicht in `app/services/video/`. `SoopliveBilliardsClient` ist ein eigenstaendiger Service in `app/services/`.

---

## Komponenten-Uebersicht

| Klasse | Pfad | Typ |
|--------|------|-----|
| `Video::TournamentMatcher` | `app/models/video/tournament_matcher.rb` | ApplicationService |
| `Video::MetadataExtractor` | `app/models/video/metadata_extractor.rb` | PORO |
| `SoopliveBilliardsClient` | `app/services/sooplive_billiards_client.rb` | Plain Ruby Class |

---

## Video::TournamentMatcher

**Typ:** `ApplicationService`  
**Pfad:** `app/models/video/tournament_matcher.rb`

Verarbeitet einen Scope von `Video`-Datensaetzen und weist jedem Video dasjenige `InternationalTournament` zu, das den hoechsten Confidence-Score erreicht — sofern der Score >= `CONFIDENCE_THRESHOLD` ist.

### Oeffentliche Schnittstelle

```ruby
# Standard: alle nicht zugewiesenen Videos (Video.unassigned)
Video::TournamentMatcher.call
# => { assigned_count: Integer, skipped_count: Integer, results: Array }

# Eingeschraenkter Scope:
Video::TournamentMatcher.call(video_scope: Video.where(id: [1, 2, 3]))
# => { assigned_count: Integer, skipped_count: Integer, results: Array }
```

**Rueckgabe:**
- `assigned_count` — Anzahl erfolgreich zugewiesener Videos
- `skipped_count` — Anzahl uebersprungener Videos (bereits zugewiesen oder Score zu niedrig)
- `results` — Array von `{ video_id:, tournament_id:, confidence: }` fuer jede Zuweisung

### Confidence Scoring

Drei gewichtete Signale ergeben zusammen einen Gesamtscore zwischen 0.0 und 1.0:

| Signal | Gewicht | Methode | Details |
|--------|---------|---------|---------|
| Datumsabdeckung | 0.40 | `date_overlap_score` | Gibt 1.0 zurueck, wenn `video.published_at` im Turnierdatumsbereich liegt (+3 Tage Toleranz nach `end_date`). `nil` end_date wird als `date + 7 Tage` behandelt. |
| Spielerschnittmenge | 0.35 | `player_intersection_score` | Jaccard-Similarity zwischen erkannten Spieler-Tags des Videos und den Setzungen des Turniers |
| Titelahnlichkeit | 0.25 | `title_similarity_score` | Normalisierter Levenshtein-Abstand: `1.0 - (distance / max_length)` |

**Schwellenwert:** `CONFIDENCE_THRESHOLD = 0.75` — Videos mit Score >= 0.75 werden automatisch zugewiesen. Es gibt keine manuelle Review-Ebene (D-02 aus dem Quellcode-Kommentar).

### Testbarkeit

`confidence_score` ist eine oeffentliche Methode und kann in Tests direkt aufgerufen werden:

```ruby
matcher = Video::TournamentMatcher.new
score = matcher.confidence_score(video, tournament, metadata)
# => Float 0.0..1.0
```

`metadata` ist optional — wenn nicht uebergeben, wird `Video::MetadataExtractor.new(video).extract_all` intern aufgerufen.

---

## Video::MetadataExtractor

**Typ:** Reines PORO (kein ApplicationService)  
**Pfad:** `app/models/video/metadata_extractor.rb`

Extrahiert strukturierte Metadaten aus Videotiteln und -beschreibungen. Strategie: Regex zuerst, KI nur als Fallback.

### Oeffentliche Schnittstelle

```ruby
extractor = Video::MetadataExtractor.new(video)

extractor.extract_all
# => { players: Array<String>, round: String|nil, tournament_type: String|nil, year: Integer|nil }

extractor.extract_players
# => Array<String>  (delegiert an video.detect_player_tags)

extractor.extract_round
# => String|nil  (aus GAME_TYPE_MAPPINGS-Schluessel)

extractor.extract_tournament_type
# => String|nil  (einer von: world_cup, world_championship, european_championship, masters, grand_prix)

extractor.extract_year
# => Integer|nil  (vierstelliges Jahr 2010-2029)

extractor.extract_with_ai_fallback(ai_extraction_enabled: false)
# => { players:, round:, tournament_type:, year: }
# KI-Fallback wird nur ausgeloest, wenn ALLE Regex-Werte leer sind UND ai_extraction_enabled: true
```

### Regex-First Strategie

Die Extraktion verwendet bekannte Muster aus dem Codebase:

- **`ROUND_PATTERNS`** — Schluessel von `Umb::DetailsScraper::GAME_TYPE_MAPPINGS` (geteilte Konstante, Namespace-uebergreifende Abhaengigkeit)
- **`TOURNAMENT_TYPE_PATTERNS`** — benannte Regexes fuer Turniertypbegriffe (world_cup, world_championship, european_championship, masters, grand_prix)
- **Jahresmuster:** `/\b(20[12]\d)\b/` — erfasst Jahre 2010-2029

Muster werden mit Wortgrenzen-Ankern geprueft (`/\b#{Regexp.escape(pattern)}\b/i`), um Teilstringfehler zu vermeiden.

### KI-Fallback

Der KI-Fallback greift nur dann, wenn **alle** Regex-Extraktionswerte leer sind **und** `ai_extraction_enabled: true` explizit gesetzt wurde:

- **Modell:** `gpt-4o-mini` mit `response_format: { type: "json_object" }`
- **Standard:** deaktiviert (`ai_extraction_enabled: false`) — verhindert unerwartete OpenAI-Aufrufe in Batch-Kontexten
- **Fehlerbehandlung:** Exceptions werden abgefangen und zurueck geben ein leeres Hash zurueck (kein Raise)

```ruby
# Nur bei Bedarf aktivieren:
extractor.extract_with_ai_fallback(ai_extraction_enabled: true)
```

---

## SoopliveBilliardsClient

**Typ:** Plain Ruby Class (kein ApplicationService, kein PORO)  
**Pfad:** `app/services/sooplive_billiards_client.rb`

Client fuer die JSON API von `billiards.sooplive.com`. Ermittelt Turnierlisten, Match-Daten mit `replay_no` und verknuepft VOD-URLs mit bestehenden `Video`-Datensaetzen.

### Oeffentliche Schnittstelle

```ruby
client = SoopliveBilliardsClient.new

client.fetch_games
# GET https://billiards.sooplive.com/api/games
# => Array von Turnier-Hashes (oder nil bei Fehler)

client.fetch_matches(game_no)
# GET https://billiards.sooplive.com/api/game/{game_no}/matches
# => Array von Match-Hashes: { "replay_no" => Integer, "record_yn" => "Y"|"N", ... }

client.fetch_results(game_no)
# GET https://billiards.sooplive.com/api/game/{game_no}/results
# => Array von Ergebnis-Hashes (Rangliste)

SoopliveBilliardsClient.vod_url(replay_no)
# => "https://vod.sooplive.com/player/{replay_no}"
# WICHTIG: Aufrufer muss pruefe replay_no != 0 vor Verwendung (replay_no == 0 bedeutet kein VOD)

client.link_match_vods(game_no, international_game: game)
# => Array von { video_id:, replay_no: } fuer jedes verknuepfte Video

SoopliveBilliardsClient.cross_reference_kozoom_videos
# => { assigned_count: Integer }
```

### replay_no == 0 Guard (Pitfall)

`replay_no == 0` bedeutet, dass kein VOD fuer dieses Match vorhanden ist. `link_match_vods` ueberspringt diese Matches automatisch. Beim direkten Aufruf von `vod_url` **muss** der Aufrufer selbst pruefe:

```ruby
# Korrekt:
if replay_no != 0
  url = SoopliveBilliardsClient.vod_url(replay_no)
end

# Falsch — replay_no == 0 erzeugt eine ungueltige URL:
url = SoopliveBilliardsClient.vod_url(replay_no)  # replay_no koennte 0 sein!
```

Zusaetzlich: `record_yn != "Y"` wird ebenfalls von `link_match_vods` uebersprungen.

### Verhalten von link_match_vods

`link_match_vods` erstellt **keine neuen** `Video`-Datensaetze. Es verknuepft ausschliesslich bereits bestehende `Video`-Datensaetze mit dem uebergebenen `InternationalGame`. Uebersprungen werden:

- Matches mit `replay_no == 0` (kein VOD)
- Matches mit `record_yn != "Y"` (nicht aufgezeichnet)
- Videos, die bereits einem anderen Datensatz zugewiesen sind (`videoable_id` gesetzt)

### Kozoom-Cross-Referencing

```ruby
SoopliveBilliardsClient.cross_reference_kozoom_videos
```

Klassenmethode fuer Batch-Verarbeitung. Sucht nicht zugewiesene `Video`-Datensaetze aus der Kozoom-Quelle, die `json_data["eventId"]` gesetzt haben, und verknuepft sie mit dem passenden `InternationalTournament` ueber `external_id`.

---

## Operativer Workflow

Drei Betriebsmodi — je nach Kontext wird der passende Pfad gewaehlt:

### 1. Inkrementell (neues Turnier)

Wird verwendet, wenn ein neues SoopLive-Turnier importiert wird und VOD-URLs direkt zugewiesen werden sollen:

```ruby
# 1. Match-Daten fuer das Turnier abrufen
matches = client.fetch_matches(game_no)

# 2. Fuer jeden InternationalGame-Datensatz des Turniers:
client.link_match_vods(game_no, international_game: international_game)
# => VOD URLs werden direkt den bestehenden Video-Datensaetzen zugewiesen
```

Dieser Pfad ist in `DailyInternationalScrapeJob` Schritt 3a verdrahtet.

### 2. Backfill (bestehende Videos)

Wird verwendet, um bereits importierte, aber noch nicht zugewiesene Videos nachtraeglich zu verknuepfen:

```ruby
Video::TournamentMatcher.call
# => Verarbeitet alle Video.unassigned mit Confidence Scoring
# Weist Videos >= 0.75 automatisch dem passenden InternationalTournament zu
```

Oder mit eingeschraenktem Scope:

```ruby
Video::TournamentMatcher.call(video_scope: Video.where(source: "sooplive"))
```

Dieser Pfad ist als Rake-Task fuer die initiale Backfill-Verarbeitung verfuegbar.

### 3. Kozoom Cross-Reference

Separater Batch-Vorgang fuer Kozoom-Quell-Videos:

```ruby
SoopliveBilliardsClient.cross_reference_kozoom_videos
# Verknuepft Kozoom-Videos via json_data["eventId"] mit InternationalTournament.external_id
```

Klassenmethode, unabhaengig von einer Client-Instanz aufrufbar.

### Welcher Pfad wann?

| Situation | Empfohlener Pfad |
|-----------|-----------------|
| Neues SoopLive-Turnier importiert | Inkrementell: `link_match_vods` |
| Bestehende Videos ohne Turnierbezug | Backfill: `TournamentMatcher.call` |
| Kozoom-Videos ohne Turnierbezug | Kozoom: `cross_reference_kozoom_videos` |

---

## Querverweise

- [Developer Guide — Extrahierte Services](../developer-guide.de.md#extrahierte-services)
- [Umb:: Namespace](./umb.de.md) — Quelle der geteilten Konstante `GAME_TYPE_MAPPINGS` (`Umb::DetailsScraper::GAME_TYPE_MAPPINGS`), die `Video::MetadataExtractor::ROUND_PATTERNS` benoetigt
