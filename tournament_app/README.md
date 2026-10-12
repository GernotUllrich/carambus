# Carambus Turnier-App

Die Turnier-App ist Teil von Carambus. Sie führt Turnierformen, die der Turnier-Monitor
nicht abdeckt, und legt die Partien auf die Carambus-Scoreboards. `index.html` ist der
Launcher, jede Turnierform liegt unter `schemes/<id>/`:

| Form | Verzeichnis | Kurz |
|------|-------------|------|
| KO-System (Einzel) | `schemes/doppelko/` | Einfach-/Doppel-KO, alle ClubCloud-Pläne (Quelle `PoolSchemata/`, geparst nach `schemes/ko/plans.js`) |
| 3-Band Mannschaftsmeisterschaft | `schemes/3band-team/` | 4 Mannschaften × 4 Spieler |
| TournamentPlan (T01–T24) | `schemes/plan/` | Carambus-Pläne, Gruppen + Finalrunde; kann sich an ein Carambus-Turnier anhängen |
| Liga-Spieltag (Party) | `schemes/spieltag/` | Mannschaftsspieltag aus dem Spielplan der Liga |

**Anleitung für Turnierleiter und Admins:** Carambus-Doku,
[`docs/managers/tournament-app`](../docs/managers/tournament-app.de.md).
Schnittstelle: [`docs/developers/external-tournament-bridge`](../docs/developers/external-tournament-bridge.de.md).

## Auslieferung

Die ausgelieferten Dateien liegen unter `public/app/` im Carambus-Repo und gehen mit jedem
Deploy mit. nginx liefert `/app/` nur aus, wenn das Szenario `serve_tournament_app: true`
setzt. Die App leitet dann ihre Server-Adresse aus der Browser-Adresse ab (Same-Origin).

## Entwickeln

Jede Schema-Seite ist eine self-contained HTML-Datei; der gemeinsame Kern (`shared/`)
wird eingebettet. Nach einer Änderung, aus dem Repo-Root:

```bash
node tournament_app/tools/sync-core.mjs          # shared/* in die HTMLs einbetten
node tournament_app/tools/build-public.mjs       # nach public/app/ spiegeln
node tournament_app/tools/build-public.mjs --check   # Drift-Prüfung (läuft auch in CI)
```

Quelle und `public/app/` gehören in denselben Commit.

Offline lässt sich `tournament_app/index.html` direkt im Browser öffnen (`file://`);
ohne Server-Anbindung bleibt es beim Datei-Austausch. Für die Live-Anbindung von einem
anderen Rechner aus: `tournament_app/serve.sh` (lokaler Webserver, Port 8123) — Carambus
muss dann CORS für diese Adresse erlauben.

Tests:

```bash
node tournament_app/tools/test-ko-engine.mjs
node --test tournament_app/schemes/plan/plan-engine.test.mjs tournament_app/shared/result-archive.test.mjs
```

Neue KO-Pläne aus der ClubCloud: HTML-Plantabelle nach `PoolSchemata/` legen, dann
`node tournament_app/tools/parse-pool-schemes.mjs` (schreibt `schemes/ko/plans.json` und `plans.js`),
danach `sync-core` und `build-public` wie oben.

## Weitere Doku

- `docs/ARCHITECTURE.md` — Aufbau, neues Schema hinzufügen
- `docs/json-schema.md` — JSON-Verträge App ↔ Carambus (`carambus.seeding/v1`, `round_start/v1`, `round_result/v1`)
- `docs/tournament-plan-executor.md` — Ausführung der Carambus-Turnierpläne
- `docs/examples/*.json` — Beispieldateien

Bis September 2026 lag die App im eigenen Repository `3band-turnier`; seine Historie ist
dort archiviert.
