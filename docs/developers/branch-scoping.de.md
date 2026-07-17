# Branch-Tagging & Scope-Band

## 1. Zweck / Überblick

Das **Scope-Band** ist ein globaler, session-persistenter Ausschnitt der Daten
entlang mehrerer Facetten — **Region**, **Saison**, **Branch** (Billard-Sparte)
und kontext-sensitiv **Club**. Es beantwortet die Frage „welchen Ausschnitt der
Welt sieht dieser Nutzer gerade?" und wendet ihn als **Fremdschlüssel-Filter**
auf die Index-Listen an (Turniere, Ligen, Spieler …).

Zwei Bausteine bilden das Subsystem:

- **`BranchTaggable`** (Model-Concern) — leitet aus der Disziplin eines Records
  eine `branch_id` ab (Pool/Snooker/Karambol/Kegel), analog zu `region_id`. Die
  Spalte liegt auf `tournaments` und `leagues`.
- **`Scopable`** (Controller-Concern) — hält Region/Saison/Branch/Club als
  Session-Scope, stellt sie über `Current.scope` bereit und lässt sie von
  `SearchService` als FK-Filter anwenden.

**Zentrale Design-Entscheidung — kein Leck ins Suchfeld:** Der Scope wird
**getrennt** von der Volltext-Nutzersuche (`params[:sSearch]`) angewendet. Das
Band filtert über echte FK-Spalten (`region_id`, `season_id`, `discipline_id`
…); es fasst den Suchstring des Nutzers nie an. So bleiben „Ausschnitt wählen"
und „im Ausschnitt suchen" zwei unabhängige Achsen.
(Quelle: `app/controllers/concerns/scopable.rb:1-13`,
`app/services/search_service.rb:51-52`.)

**„Kein Alle" — mit einer Ausnahme:** Region und Saison sind **immer** ein
konkreter Wert (es gibt keinen „Alle Regionen"-Zustand). Nur **Branch** (und die
kontext-sensitive Club-Facette) darf leer sein und bedeutet dann „Alle Branchen"
bzw. „Alle Clubs". Branch ist genuin quer-interessant, und (noch) unklassifizierte
Disziplinen (`branch_id = nil`) fielen bei erzwungener Auswahl durchs Raster.
(Quelle: `scopable.rb:8-13`.)

---

## 2. `BranchTaggable`-Concern

Datei: `app/models/concerns/branch_taggable.rb`

### Ableitung der `branch_id`

Der Concern registriert genau einen Callback und drei Methoden:

```ruby
included do
  before_save :set_branch_id, if: -> { will_save_change_to_discipline_id? || branch_id.nil? }
end

def find_associated_branch_id
  root = discipline&.root
  root.is_a?(Branch) ? root.id : nil
end

def set_branch_id
  self.branch_id = find_associated_branch_id
end
```

(Quelle: `branch_taggable.rb:9-22`.)

- `discipline.root` läuft die `super_discipline`-Kette bis zur Baumwurzel hoch
  (`app/models/discipline.rb:585-587`).
- Ist die Wurzel ein **`Branch`** (Pool/Snooker/Karambol/Kegel), wird deren `id`
  gesetzt; sonst `nil` (z. B. eine Disziplin, die noch nicht unter einem Branch
  wurzelt — Beispiel im Code: 10-Ball bis zum Authority-Baum-Fix).
- Der Callback feuert nur bei geänderter `discipline_id` **oder** wenn
  `branch_id` noch `nil` ist — er rechnet nicht bei jedem Save neu.

### Includer

Nur zwei Modelle führen die Spalte und den Concern:

- `Tournament` — `app/models/tournament.rb:65`
- `League` — `app/models/league.rb:37`

### Bewusst schlankes Design (kein PaperTrail)

Anders als `RegionTaggable` betreibt `BranchTaggable` **keine** Version-/
PaperTrail-Maschinerie. Es gibt keine `after_save`/`after_destroy`-Callbacks, die
Versionen nachtaggen — nur die Live-Spalte `branch_id`. Der Concern ist bewusst
minimal gehalten (`branch_taggable.rb:3-5`).

### Backfill globaler Records — historischer Hinweis (Gotcha)

> **Achtung — veralteter Kommentar im Code.** Der Kopfkommentar in
> `branch_taggable.rb:5` verweist auf einen Backfill-Task
> `lib/tasks/branch_taggings.rake`. **Diese Datei existiert nicht mehr** — sie
> wurde in Commit `56e67264` (Phase 17 17-03, „Branch-Facette Scope-Band auf
> discipline.root", SB-2) entfernt.

Der ursprüngliche Ansatz war ein `update_all`-Backfill über `discipline.root`
(bypasst `LocalProtector`, weil `update_all` keine Callbacks auslöst). Er wurde
verworfen, weil er für **gesyncte globale Records** (`id < MIN_ID`) prinzipiell
nicht zuverlässig funktioniert:

1. Der Version-Apply schreibt Attribute per `update_columns` — das umgeht den
   `BranchTaggable`-`before_save`, `branch_id` wird also nicht gefüllt.
2. `LocalProtector` sperrt anschließend jeden Re-Save globaler Records auf lokalen
   Servern.
3. → `branch_id` bleibt auf gesyncten Global-Records **NULL**.

Deshalb löst das Scope-Band die Branch-Facette **zur Query-Zeit** über
`discipline.root` auf statt die (bei Global-Records leere) `branch_id`-Spalte
abzufragen — siehe Abschnitt 3 und `Branch.discipline_ids_for`
(`app/models/branch.rb:22-58`). Die `branch_id`-Spalte wird auf der Authority
über den `before_save` beim normalen Speichern gefüllt und dient dort als
abgeleitete Dimension; für die Filterung ist sie jedoch **nicht** die Quelle der
Wahrheit.

---

## 3. `Scopable`-Concern (das Scope-Band)

Datei: `app/controllers/concerns/scopable.rb`.
Eingebunden in `ApplicationController` (`app/controllers/application_controller.rb:21`).

### `SCOPE_FACETS` — Facette → FK-Spalte

```ruby
SCOPE_FACETS = {
  "region" => "region_id",
  "season" => "season_id",
  "branch" => "branch_id",
  "club"   => "club_id"
}.freeze
```

(Quelle: `scopable.rb:19-24`.) `club` ist die kontext-sensitive 3. Facette für
Modelle mit `scope_extra_facet == :club` (Player) und wird join-basiert
gefiltert.

### Request-Verdrahtung

`ApplicationController` reiht zwei before_actions ein
(`application_controller.rb:42-43`):

1. **`capture_scope`** — liest `params[:scope]` und merged die Werte in
   `session[:scope]`. Werte sind konkrete IDs (kein „Alle"). Bei echter Änderung
   wird zusätzlich `persist_scope_preference` aufgerufen
   (`scopable.rb:47-60`).
2. **`set_current_scope`** — legt den aufgelösten FK-Scope in `Current.scope` ab,
   den `SearchService` pro Request konsumiert (`scopable.rb:79-94`).

**Write-back in User-Preferences:** Angemeldete Nutzer merken sich ihren
Ausschnitt über Sessions hinweg in `preferences["scope"]`. Geleerte Facetten
(„Alle Branchen") werden aus der Preference entfernt, damit der Default wieder
greift. Das Schreiben ist fehlerrobust — ein fehlgeschlagener Preference-Write
bricht den Request nie ab (`scopable.rb:65-76`).

### Die „kein Alle außer Branch"-Regel

Die konkreten Default-/Leer-Regeln liegen im `ScopeResolver` (Abschnitt zu
Defaults unten). Für das Band gilt:

- **Region, Saison:** immer konkret. Fallback-Kette Session → Preference →
  Server-Kontext (nur Region) → Default.
- **Branch, Club:** dürfen leer bleiben (`nil`), was „Alle Branchen"/„Alle Clubs"
  bedeutet — dann wird für diese Facette **kein** Filter gesetzt.

### Defaults (`ScopeResolver`)

Datei: `app/services/scope_resolver.rb`. Der Resolver ist reine Ableitung aus
Session + User und wird sowohl vom HTTP-Controller (`Scopable`) **als auch** vom
`SearchReflex` (ActionCable-Live-Suche) genutzt — so existieren die Default-Regeln
nur an einer Stelle (`scope_resolver.rb:1-12`, `app/reflexes/search_reflex.rb:44`).

- **Region** (`scope_resolver.rb:32-34`): Session → Preference →
  Server-Kontext-Region → **NBV** (per `shortname`, sonst erste Region;
  `scope_resolver.rb:76-78`). Regionale Server setzen die Region aus dem
  Server-Kontext (`Carambus.config.context` = Region-Shortname,
  `scope_resolver.rb:68-73`); der globale Server nutzt den NBV-Default.
- **Saison** (`scope_resolver.rb:37-39`): Session → Preference → aktuelle Saison;
  im **Saison-Umbruch** (heute ≤ 15.08. des Startjahres) gilt die **Vorsaison**
  als Default (`scope_resolver.rb:82-98`). `season_transition?` meldet diesen
  Zustand für einen dezenten Band-Hinweis (`scope_resolver.rb:53-55`).
- **Branch** (`scope_resolver.rb:42-44`): Session → Preference; sonst `nil` =
  „Alle Branchen". Eine gesetzte Branch-Preference wird als Default respektiert.
- **Club** (`scope_resolver.rb:47-49`): analog Branch.

`fk_scope` baut den Hash `{ "region_id" => …, "season_id" => …, "branch_id" => …,
"club_id" => … }` und **entfernt `nil`-Werte per `compact`** — leere Facetten
erzeugen so keinen Filter (`scope_resolver.rb:22-29`).

### `scope_extra_facet` — welche 3. Facette zeigt das Band?

Neben Region und Saison zeigt das Band eine kontext-abhängige dritte Facette. Sie
richtet sich nach dem aktuellen Controller-Modell über die Klassenmethode
`scope_extra_facet` (`scopable.rb:207-215`):

| Modell   | `scope_extra_facet` | Quelle                              |
|----------|---------------------|-------------------------------------|
| Default (`ApplicationRecord`) | `:branch` | `application_record.rb:50-52` |
| `Player` | `:club`             | `player.rb:42-44`                   |
| `Club`   | `:none`             | `club.rb:54-56`                     |
| `Location` | `:none`           | `location.rb:90-92`                 |

Bei unbekanntem Controller fällt `scope_extra_facet` defensiv auf `:branch`
zurück (`scopable.rb:213-215`).

### Drill-down-Modus (`DRILL_FOCUS_KEYS`)

```ruby
DRILL_FOCUS_KEYS = %w[tournament_id league_id club_id party_id].freeze
```

(Quelle: `scopable.rb:30`.) Der Drill-down ist die Verallgemeinerung des früheren
`region_focus`: ein **ephemerer Ankunftskontext** aus `params[:drill] =
{ <parent_fk> => <id> }`, der die Kind-Liste auf einen Parent einengt (z. B.
„zeige die Ligen dieses Clubs").

- Die **Allowlist** `DRILL_FOCUS_KEYS` verhindert **Column-Injection**: nur diese
  vier FK-Spalten landen im Drill-Kontext (`scopable.rb:101-114`).
- Ein aktiver Drill ersetzt das Scope-Band durch **Breadcrumbs**
  (`drill_focus_crumbs`, `scopable.rb:122-147`) und wird **getrennt** vom
  Scope-Band gehalten: `set_current_scope` setzt `Current.drill` und leert
  `Current.scope` (`scopable.rb:80-86`).
- Der Drill schreibt **nichts** in die Session (ephemer).

Ein **temporärer Region-Fokus** (`params[:region_focus]`, aus `regions/show`) ist
ein separater, ebenfalls ephemerer Param mit **höherer Priorität** als der
persistente Band-Wert: er überschreibt `region_id` nur für diesen Request, ohne
`session[:scope]` zu ändern (`scopable.rb:88-92`, `scopable.rb:160-176`).

### `Current.scope` / `Current.drill`

`Current` (`app/models/current.rb`) ist ein `ActiveSupport::CurrentAttributes`
mit u. a. zwei Attributen:

- **`Current.scope`** — der FK-Filter-Hash des Scope-Bands, pro Request gesetzt
  (`current.rb:8`).
- **`Current.drill`** — der ephemere Parent-FK des Drill-downs, **getrennt** vom
  Scope-Band, damit `SearchService` ihn direkt (`where(fk => id)`) filtert und
  nicht die Facetten-Spezial-Logik (club_id-Join) durchläuft (`current.rb:12`).

### Anwendung durch `SearchService` (FK-Filter)

Datei: `app/services/search_service.rb`. Der Service ruft in `call` erst
`apply_scope`, dann `apply_drill` auf — **vor** der Volltextsuche
(`search_service.rb:22-28`).

**`apply_scope`** (`search_service.rb:57-113`):

1. Ist `Current.scope` leer → unverändert zurück (`:59`).
2. **Column-Injection-Allowlist:** Modelle können sich per `scope_exempt?` ganz
   ausnehmen (Picker-Listen wie `Region`) → early-return (`:61`,
   `region.rb:136`). Andernfalls wird jede Facette nur angewandt, wenn das Modell
   die Spalte tatsächlich führt (`cols.include?(col)`, `:95`).
3. **Club** (`:72-83`): join-basiert und saison-gebunden. Nur Modelle mit einer
   `season_participations`-Assoziation (Player) werden gefiltert
   (`joins(:season_participations).where(club_id:, season_id:)`, distinct); andere
   Modelle ignorieren die Club-Facette.
4. **Branch** (`:88-93`): Die `branch_id`-Spalte wird **nicht** abgefragt (bei
   Global-Records NULL, SB-2). Stattdessen Auflösung über den Disziplin-Teilbaum:
   `where(discipline_id: Branch.discipline_ids_for(value))`. Modelle ohne
   `discipline_id` ignorieren die Branch-Facette (verhaltensneutral).
5. **Region** (`:97-110`): Strikte Modelle (`scope_region_strict? == true`:
   Location/Player/Club) zeigen ausschließlich die eigene `region_id`.
   Nicht-strikte Modelle (Ligen/Turniere) schließen zusätzlich
   `global_context = TRUE` ein (regionsübergreifend gültige Records, z. B.
   DBU-Ligen).

**`apply_drill`** (`search_service.rb:38-49`): filtert jeden vorhandenen
Drill-FK direkt per `where(col => value)` — defensiv nur für Spalten, die das
Modell führt.

`Branch.discipline_ids_for(branch_id)` (`app/models/branch.rb:32-58`) liefert alle
Disziplin-`id`s, deren Baum-Wurzel diese Branch ist (inkl. der Branch-`id`
selbst). Es baut einmalig einen prozessweit memoisierten Baum-Index (`ids_by_root`,
ein `pluck`, kein N+1-Root-Walk); `reset_discipline_ids_cache!` erzwingt
Neuberechnung. Der Baum ändert sich nur per Sync/Scrape, der Cache wird bei
Code-Reload (dev) bzw. Deploy/Neustart (prod) frisch aufgebaut.

### Options-Quellen für die Band-View

Alle Options-Helper liefern `[Anzeige, id]`-Paare (Werte = IDs, kein „Alle"):

- `scope_region_options` — alle Regionen außer `UNKNOWN`, nach shortname
  (`scopable.rb:269-271`).
- `scope_season_options` — echte „yyyy/yyyy+1"-Namen von 2009 bis
  aktuelles Jahr + 2, absteigend (`scopable.rb:275-280`).
- `scope_branch_options` — `Branch.order(:name)` (`scopable.rb:282-284`).
- `scope_club_options` — Clubs der aktuellen Scope-Region, Anzeige
  `COALESCE(shortname, name)`, namenlose Stubs ausgelassen (`scopable.rb:289-295`).

---

## 4. Verhältnis zu `RegionTaggable`

`BranchTaggable` ist bewusst als **schlankes Analogon** zu `RegionTaggable`
(`app/models/concerns/region_taggable.rb`) gebaut. Gemeinsamkeit: beide leiten
eine FK-Dimension aus dem Record ab und speisen sie in den Scope-Filter. Die
Unterschiede:

| Aspekt | `RegionTaggable` | `BranchTaggable` |
|--------|------------------|------------------|
| Abgeleitete Spalte | `region_id` (+ `global_context`) | `branch_id` |
| Ableitungslogik | `find_associated_region_id` — großes `case` über Modell-Klasse **und** `tournament_type`; liefert eine **einzelne** ID (`region_taggable.rb:11-53`) | `find_associated_branch_id` — nur `discipline.root`, ein Zweig (`branch_taggable.rb:15-18`) |
| Version-/PaperTrail-Tagging | ja — `after_save`/`after_destroy :update_version_region_data`, taggt Versionen für Region-Sync (`region_taggable.rb:7-8`, `:123-143`) | **nein** — nur Live-Spalte, keine Version-Maschinerie |
| `global_context` | ja — `global_context?` markiert regionsübergreifend gültige Records (`region_taggable.rb:55-79`) | nein |
| Includer | 16 Modelle (Region, Club, Tournament, League, Party, Player, Game, …) | 2 Modelle (Tournament, League) |
| Backfill-Task | `lib/tasks/region_taggings.rake` (existiert, kuratiert) | entfernt — Query-Zeit-Auflösung via `discipline.root` |

Der frühere `find_associated_region_ids` (Array) wurde auf eine **einzelne** ID
vereinfacht (`find_associated_region_id`); siehe
[`region-tagging-cleanup-summary.de.md`](region-tagging-cleanup-summary.de.md).
`BranchTaggable` übernahm diese schlanke Form von Anfang an — plus den Verzicht auf
die Version-Maschinerie.

**Filter-Asymmetrie in `SearchService`:** `region_id` wird direkt als Spalte
gefiltert (mit `global_context`-OR bei nicht-strikten Modellen). `branch_id`
dagegen **nie** als Spalte, sondern immer über `discipline.root` aufgelöst —
genau wegen des NULL-Problems bei gesyncten Global-Records (Abschnitt 2).

---

## 5. DB-Spalten & Rake-Backfill-Tasks

### Migration

`db/migrate/20260702061649_add_branch_id_to_tournaments_and_leagues.rb`:

```ruby
disable_ddl_transaction!

add_column :tournaments, :branch_id, :integer unless column_exists?(...)
add_column :leagues,     :branch_id, :integer unless column_exists?(...)
add_index  :tournaments, :branch_id, algorithm: :concurrently unless ...
add_index  :leagues,     :branch_id, algorithm: :concurrently unless ...
```

Abgeleitete FK-Dimension analog `region_id`: **nullable**, **kein**
FK-Constraint (Discipline ist global), Index concurrently (strong_migrations).

### Schema

- `tournaments.branch_id` (integer) + `index_tournaments_on_branch_id`
  (`db/schema.rb:1462`, `:1464`).
- `leagues.branch_id` (integer) + `index_leagues_on_branch_id`
  (`db/schema.rb:542`, `:544`).

### Rake-Backfill-Tasks

- **Branch:** **kein aktiver Task.** Der frühere
  `lib/tasks/branch_taggings.rake` (`namespace :branch_taggings`, Task
  `update_all_branch_id`) wurde in `56e67264` entfernt (siehe Abschnitt 2). Ein
  Backfill globaler Records ist nicht möglich; das Band löst die Branch-Facette
  zur Query-Zeit auf.
- **Region (Analogon):** `lib/tasks/region_taggings.rake` existiert und ist die
  kuratierte Quelle der Wahrheit für DE-Tagging. Wichtige Tasks:
  - `region_taggings:update_all_region_id` — organische Region-Ableitung top-down
    (Region → Club → SeasonParticipation → Player usw.).
  - `region_taggings:fix_international_organizer_context` — taggt internationale
    Organizer-Regionen als `global_context` (nur Authority, PaperTrail-getrackt;
    `ARMED=1` mutiert). DRY-RUN als Default.
  - Ein **Recurrence-Schutz** (`guard_derivation_retag!`,
    `region_taggings.rake:126-137`) sperrt die derivation-basierten Re-Tag-Tasks,
    weil `RegionTaggable#global_context?`/`#find_associated_region_id`
    unvollständig sind und die kuratierte globale Taggung still herunterrissen.
    Override: `FORCE_DERIVATION_RETAG=1`.

---

## 6. Gotchas

1. **`branch_id = nil` bei unklassifizierten Disziplinen.** Disziplinen, deren
   Baumwurzel (noch) kein `Branch` ist, liefern `find_associated_branch_id == nil`
   (`branch_taggable.rb:15-18`). Solche Records tragen keine Branch und erscheinen
   nur im Zustand „Alle Branchen". Das ist der Grund für die „kein Alle außer
   Branch"-Ausnahme (`scopable.rb:11-13`).

2. **`branch_id`-Spalte ist NICHT die Filter-Quelle.** Auf gesyncten
   Global-Records (`id < MIN_ID`) bleibt `branch_id` NULL (update_columns beim
   Version-Apply umgeht den `before_save`, `LocalProtector` sperrt den Re-Save).
   `SearchService` fragt deshalb **nie** `branch_id` ab, sondern löst über
   `Branch.discipline_ids_for` / `discipline.root` auf
   (`search_service.rb:88-93`). Wer die Spalte für eine eigene Query nutzt, muss
   diese Lücke kennen.

3. **Veralteter Backfill-Verweis im Concern-Kommentar.** `branch_taggable.rb:5`
   nennt `lib/tasks/branch_taggings.rake` — die Datei existiert nicht mehr (in
   `56e67264` entfernt). Kein Backfill vorhanden.

4. **Globaler vs. regionaler Server — Region-Default.** Regionale Server setzen
   die Default-Region aus `Carambus.config.context` (Region-Shortname). Der
   globale Server (leerer Context) fällt auf **NBV** zurück (aktuell die einzige
   real genutzte Region; `scope_resolver.rb:31-34`, `:66-78`). DBU ist einfach
   eine wählbare Region, kein Sonderzustand.

5. **Saison-Umbruch verschiebt den Default.** Bis zum 15.08. des Startjahres der
   aktuellen Saison ist die **Vorsaison** der Saison-Default (Endergebnisse/
   Ranglisten stehen, die neue Saison ist noch in Planung;
   `scope_resolver.rb:82-98`). `scope_season_transition?` signalisiert das für den
   Band-Hinweis.

6. **Region-strikte vs. nicht-strikte Modelle.** Bei `region_id`-Filterung zeigen
   strikte Modelle (Player/Club/Location, `scope_region_strict? == true`)
   **ausschließlich** die eigene Region; `global_context` ist dort ein
   Sync-Retention-Marker und wird nie eingeblendet. Nicht-strikte Modelle
   (Turniere/Ligen) inkludieren `global_context = TRUE`
   (`search_service.rb:97-110`, `player.rb:49`, `club.rb:61`, `location.rb:97`).

7. **`SearchReflex` umgeht die Controller-before_actions.** Die ActionCable-
   Live-Suche läuft nicht durch `set_current_scope`. Sie setzt `Current.scope`
   selbst über denselben `ScopeResolver`
   (`search_reflex.rb:44`) — sonst wäre der Scope in der Live-Suche `nil`.
