# Architektur — Multi-Schema-Turnier-App

> Stand: 2026-05-23. Mehrere Turnier-Schemata unter einem Einstieg, **ohne Build**,
> **per Doppelklick aus dem Dateisystem (`file://`) lauffähig**.

## Leitentscheidungen

1. **Kein Build, kein Bundler, kein Server-Zwang.** Die App soll vor Ort per
   Doppelklick auf `index.html` (`file://`) starten.
2. **Self-contained Dateien.** Jede Schema-Seite **und** der Launcher sind je *eine
   eigenständige HTML-Datei* mit inline CSS + JS — kopierbar, einzeln startbar, kein
   Schema kann ein anderes brechen. Deshalb **klassische `<script>`-Blöcke statt
   ES-Module** (ES-Module lädt der Browser über `file://` nicht).
3. **DRY trotz Duplikat-Dateien — über den KI-Workflow.** Der gemeinsame Carambus-
   Kern wird *kanonisch an einer Stelle* gepflegt (`shared/`) und per Tool in jede
   Datei **inline kopiert**. Ein Sync-Check verhindert Drift. So bleibt die Pflege
   an einer Stelle, das Deliverable aber eine einzelne Datei.

## Verzeichnisstruktur

```
index.html                       ← Launcher = Turnier-Manager (self-contained): neue Turniere anlegen + Liste/Öffnen/Löschen
schemes/
  3band-team/index.html          ← bestehende 3-Band-App (self-contained, unverändert)
  doppelko/
    index.html                   ← Doppel-KO (self-contained: CSS+Kern+Engine+Controller inline)
    bracket.test.mjs             ← Node-Test (extrahiert die Engine aus index.html)
shared/
  carambus-core.js               ← KANONISCHER Kern (window.Carambus) — NICHT zur Laufzeit geladen
  carambus-core.css             ← KANONISCHES Theme — NICHT zur Laufzeit geladen
tools/
  sync-core.mjs                  ← inlinet shared/ in die self-contained Dateien (zwischen Markern)
  check-core-sync.mjs            ← verifiziert, dass keine inline-Kopie driftet (exit 1 bei Drift)
serve.sh                         ← optionaler statischer Webserver (für Live-Betrieb, siehe CORS)
```

## Der gemeinsame Kern (`window.Carambus`)

`shared/carambus-core.js` definiert ein globales Objekt `window.Carambus` mit:
Verbindung/Login (`getConnection`/`isBearerValid`/`carambusLogin`, geräteweit geteilter
`localStorage`-Key `carambus.connection`), REST-Client (`carambusFetch`, `ping` +
`api.{fetchClubs,fetchClubPlayers,fetchPlayerRankings,fetchTables,createTournament,
lockTable,startGame,acknowledgeResult,endTournament,pushTournamentResult,cleanPlayerRef}`),
`util` (CSV/Download/escape/… + `buildResultStandings`/`buildResultGames` fürs Ergebnisarchiv),
`storage` (Schema-State + **Turnier-Instanzen**, s. u.) und `mountConnectionWidget`
(Badge + Verbindungs-Modal).

Warum die Archiv-Normalisierer im Kern liegen und nicht im Schema: Die Carambus-Anzeige stellt
vier Bedingungen an die Zeilen, von denen **drei still fehlschlagen** (fehlende Spalten, stumm
übersprungene Partien, abgeschnittene Zeilen). Sie einmal zentral durchzusetzen ist der
Unterschied zwischen „fällt im Test auf" und „fällt zwei Wochen nach dem Turnier auf".
Details in [`json-schema.md`](json-schema.md#4-carambustournament_resultv1--ergebnisarchiv-app--carambus).

In jeder self-contained Datei steht dieser Kern **inline** zwischen Markern:

```
/* >>> CARAMBUS-SYNC core-js  >>> */ … window.Carambus = (…)(); … /* <<< CARAMBUS-SYNC core-js  <<< */
/* >>> CARAMBUS-SYNC core-css >>> */ … Theme …                    /* <<< CARAMBUS-SYNC core-css <<< */
```

Schema-Code außerhalb der Marker nutzt `Carambus.*` (Kapselung über ein Namespace-
Objekt — keine wilde globale Streuung).

## Pflege-Workflow (KI)

1. Kern ändern → **nur** `shared/carambus-core.{js,css}` editieren.
2. `node tools/sync-core.mjs` → inlinet in alle Ziel-Dateien.
3. `node tools/check-core-sync.mjs` → muss grün sein (CI/Pre-Commit-tauglich).

Wichtig: `shared/carambus-core.*` dürfen die **literalen Marker-Tokens nicht enthalten**
(sonst bricht der Extraktor zu früh ab).

## Turnier-Instanzen (mehrere parallele Turniere)

Ein Schema kann **mehrfach gleichzeitig** laufen (z. B. großes Vereinsturnier: Jugend +
Senioren, viele Disziplinen an vielen Tischen parallel). Dafür gibt es eine
**Instanz-Ebene** zwischen Launcher und Schema:

- Der **Launcher (`index.html`) ist der Turnier-Manager**: „Neues Turnier" (Schema +
  Titel + Kategorie) und eine Liste aller Turniere (Öffnen/Löschen).
- Jede Instanz hat eine eigene **ID** und wird als `…/index.html?t=<id>` geöffnet.
- State pro Instanz unter `carambus.instance.<id>`; ein Index `carambus.instances`
  hält die Metadaten (Schema, Titel, Kategorie, Disziplin, Spielerzahl, Phase, Zeit).
- Kern-API (`Carambus.storage`): `listInstances`, `createInstance`, `getInstance`,
  `updateInstance`, `deleteInstance`, `loadInstanceState`, `saveInstanceState`.
- **Live:** jede Instanz nutzt eine **eindeutige** Carambus-`external_id` (`app-<id>`),
  damit parallele Turniere gleicher Disziplin nicht kollidieren. Verschiedene Instanzen
  binden verschiedene Tische (lock_table); Doppelbelegung meldet Carambus als Konflikt.
- **Kategorie** (Jugend/Senioren/…) ist derzeit ein Label (Titel/Übersicht/CSV).
  Automatisches Filtern der Spieler nach Kategorie braucht Carambus-Daten → Handoff.
- Schema-Flag `instanceAware`: `true` → Manager legt Instanzen an (Doppel-KO **und**
  3-Band). `false` → Einzelinstanz, direkt geöffnet (kein `?t=`). Aktuell sind beide
  Schemata instanzfähig.

## Neues Schema hinzufügen

1. `schemes/<id>/index.html` als self-contained Datei anlegen mit den beiden
   CARAMBUS-SYNC-Marker-Paaren (leer) + schema-spezifischem CSS/JS, das `Carambus.*` nutzt.
2. `node tools/sync-core.mjs` → Kern wird eingesetzt.
3. Im Launcher (`index.html`) **einen Eintrag** im `SCHEMES`-Array ergänzen
   (`{id,title,subtitle,description,players,icon,entry,status}`).

Mehr braucht es nicht.

## Starten

- **Offline / Planung:** `index.html` doppelklicken (`file://`). Voll funktionsfähig
  inkl. Doppel-KO-Offline-Modus (Demo-/manuelle Teilnehmer, Ergebnisse von Hand).
- **Live gegen Carambus:** über `./serve.sh` ausliefern (LAN-`http://`-Origin), damit
  die Cross-Origin-Calls an Carambus von dessen CORS erlaubt werden — die `file://`-
  Origin (`null`) ist standardmäßig nicht erlaubt. Siehe README + Carambus-Handoff.

## Tests / Verifikation

- `node schemes/doppelko/bracket.test.mjs` — extrahiert die Doppel-KO-Engine aus der
  HTML und prüft sie (8/16/32, Bracket-Reset, Freilose).
- `node tools/check-core-sync.mjs` — Kern-Sync.
- Browser-Smoke: per `./serve.sh` (oder Doppelklick) Launcher → Schema → Offline-Durchlauf.

## Status der Schemata

| Schema | id | Status | Notizen |
|---|---|---|---|
| 3-Band Mannschaft | `3band-team` | stabil | self-contained; **instanzfähig**; nutzt den `shared/`-Kern (Verbindungs-/Auth-/Fetch-Primitive dedupliziert via `core-js`-Marker). Eigenes CSS + Verbindungs-Modal (mit `tournament_cc_id`) bleiben; höhere Carambus-Funktionen noch bespoke |
| Doppel-KO (Einzel) | `doppelko` | beta | nutzt den `shared/`-Kern via Inline-Marker; Live- + Offline-Modus |
| TournamentPlan (T01–T24) | `plan` | beta | **datengetrieben**: interpretiert Carambus-`executor_params` (Gruppen + Finalrunde) app-seitig; Engine inline (`PLAN-ENGINE`-Block, Node-getestet via `plan-engine.test.mjs`). Nutzt `disciplines`-Endpoint (Pläne+Params) + Demo-Pläne offline. Spec: `docs/tournament-plan-executor.md` |

## Doppel-KO im Detail

- **Engine** (inline in `schemes/doppelko/index.html`, Block `BRACKET-ENGINE`): echtes
  Doppel-KO — Gewinner-Bracket (WB), Verlierer-Bracket (LB), Grand Final **mit
  Bracket-Reset**. 8–32 Spieler, auf Zweierpotenz (8/16/32) aufgefüllt; Freilose lösen
  sich automatisch auf.
- **Match-Graph statt Runden:** Jedes Match hat zwei Slots, gefüllt durch Setzplatz oder
  winner/loser eines Vorgängers; „ready", sobald beide Slots echte Spieler sind — **keine
  Rundensperre**. Dadurch: *Tisch frei → nächstes bereites Spiel einzeln starten*.
- **Setzliste** über `player_rankings` (Carambus-Endpoint, via Handoff an Paul);
  Fallback: manuelle Reihenfolge.
- **Betriebsarten:** Live (Carambus) und Lokal/Offline (Demo-/manuelle Teilnehmer).
