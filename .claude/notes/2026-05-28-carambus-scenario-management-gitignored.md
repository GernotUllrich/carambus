---
date: "2026-05-28 00:02"
promoted: false
---

add Carambus scenario-management: NIEMALS gitignored Files in den Scenario-Repos (config/deploy.rb, config/deploy/production.rb, config/database.yml, config/carambus.yml, etc.) manuell editieren. Diese werden ALLE durch `rake scenario:generate_configs[<scenario>,production]` aus Templates in `carambus_master/lib/templates/` + Scenario-Configs in `carambus_data/scenarios/<scenario>/config.yml` generiert. Edits außerhalb des Generator-Pipelines sind Anti-Pattern (User-Direktive 2026-05-28 nach Plan-21-09v1-Spec-Failure). Korrekte Reihenfolge bei Konfig-Änderung: (1) Template in carambus_master/lib/templates/deploy/*.erb ändern, (2) Scenario-Config in carambus_data/scenarios/<s>/ anpassen falls Variable nötig, (3) `rake scenario:generate_configs[<s>,production]` ausführen, (4) `rake scenario:create_rails_root[<s>]` o.ä. zum Kopieren in Local-Repo, (5) `cap production deploy`. Vor Edit immer prüfen: `git check-ignore <file>` — wenn IGNORED → Templates first!
