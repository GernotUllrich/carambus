# Scenario-abhängiges Testen

Carambus wird in mehreren Szenarien deployed (`carambus_master`, `carambus_bcw`,
`carambus_api`, `carambus_phat` …). Für die Testsuite ergeben sich daraus ein
paar Stolperfallen, die hier gebündelt sind.

Siehe auch:
- [TEST_DATABASE_SETUP.md](TEST_DATABASE_SETUP.md) — Test-DB, Fixtures, ID-Ranges
- [README.md](README.md) — allgemeiner Testing-Guide

## Scenarien auf einen Blick

| Scenario       | `carambus_api_url` | Rolle         | Konsequenz für Tests                          |
|----------------|--------------------|---------------|-----------------------------------------------|
| `carambus_master` | leer            | API-ähnlich   | PaperTrail aktiv, Scraping-Integration läuft  |
| `carambus_api`    | leer            | API-Server    | wie master                                    |
| `carambus_bcw`    | gesetzt         | Local Server  | PaperTrail aus, Scraping returnt früh         |
| `carambus_phat`   | gesetzt         | Local Server  | wie bcw                                       |

Der Schlüssel: `LocalProtector` entscheidet **einmal beim Laden der Model-Klasse**
anhand von `Carambus.config.carambus_api_url.present?`, ob `has_paper_trail`
aktiv wird. Auf Local Servern ist PaperTrail aus — `Tournament#versions`
existiert dort schlicht nicht.

## Erstinbetriebnahme pro Scenario

```bash
# 1) scenario-generierte cable.yml einspielen (gitignored!)
cp ../carambus_data/scenarios/<scenario>/development/cable.yml config/cable.yml

# 2) Test-DB aufsetzen
RAILS_ENV=test bin/rails db:drop
RAILS_ENV=test bin/rails db:create
SAFETY_ASSURED=true RAILS_ENV=test bin/rails db:test:prepare
```

Ohne cable.yml schlagen alle Tests mit `NoMethodError: undefined method 'fetch'
for nil` im ActionCable-Setup fehl — die Datei ist per `.gitignore`
ausgeschlossen, weil sie pro Scenario anders aussieht.

## Tests skippen je nach Scenario

In `test_helper.rb` sind zwei Helper definiert:

```ruby
skip_unless_api_server   # skipt, wenn wir ein Local Server sind
skip_unless_local_server # skipt, wenn wir ein API Server sind
```

Beide lesen einen beim Laden des `test_helper` **eingefrorenen** Snapshot
(`LOCAL_SERVER_SCENARIO`) — nicht den Live-Wert. Das ist Absicht:
`LocalProtector` trifft seine `has_paper_trail`-Entscheidung ebenfalls einmalig
zur Class-Load-Zeit, beide Snapshots stammen aus demselben Moment.

Verwendungsbeispiele:
- PaperTrail-Charakterisierungstests → `skip_unless_api_server` (nur auf
  API-Servern ist PaperTrail aktiv)
- `scrape_single_tournament_public` / `PublicCcScraper` Integrationspfade →
  `skip_unless_api_server` (auf Local Servern returnt der Code früh)
- Scoreboard/Broadcast-Tests, die echte `ApplicationRecord.local_server? == true`
  Semantik brauchen → entweder `skip_unless_local_server`, oder im Test
  `ApplicationRecord.stub(:local_server?, true)` verwenden

## Antipattern: Carambus.config.carambus_api_url mutieren

Tests dürfen `Carambus.config.carambus_api_url` gern temporär setzen, **müssen
aber den Originalwert sauber restaurieren**, sonst vergiften sie nachfolgende
Tests in der Suite (die Reihenfolge ist seed-abhängig):

```ruby
setup do
  @original_api_url = Carambus.config.carambus_api_url
end

teardown do
  Carambus.config.carambus_api_url = @original_api_url
end
```

Hartes `Carambus.config.carambus_api_url = nil` im `teardown` ohne setup-Merken
ist die Falle — dann laufen spätere Tests, die Scenario-Verhalten erwarten,
gegen die gepolsterte Config statt gegen die YAML-Config.

## Was ist bei Änderungen an `LocalProtector`/`TableMonitor` zu prüfen?

Wenn du die `has_paper_trail`-Bedingung oder den `after_update_commit`-Guard in
`TableMonitor` anfasst: **beide Scenarien testen**. Ein `bundle exec rails test`
auf `master` allein reicht nicht — master verhält sich wie ein API-Server. Ein
grüner master-Lauf kann auf bcw rot sein (oder umgekehrt), weil die Code-Pfade
unterschiedlich sind.
