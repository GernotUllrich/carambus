# Reflexes ohne Autorisierung — Prüffrage, kein Befund

**Erfasst:** 2026-08-14 · **Status:** offen, **nicht verifiziert**
**Einordnung:** strukturelle Beobachtung. Ob daraus ein Risiko folgt, hängt von der
Erreichbarkeit ab — und genau das ist ungeprüft.

## Beobachtung

Reflexes sind über ActionCable erreichbar. Seit `67dfa40f` (Variante C) sind anonyme
Cable-Verbindungen ausdrücklich zugelassen — mit `current_user = nil` statt, wie vorher,
mit der Identität von `User.first`.

Übersicht über Autorisierungs-Gates vs. Schreiboperationen:

| Reflex | `current_user&.admin?`-Gates | Schreibops |
|---|---|---|
| `table_monitor_reflex.rb` | 2 | 46 |
| `game_protocol_reflex.rb` | **0** | **15** |
| `party_monitor_reflex.rb` | 2 | 10 |
| `tournament_reflex.rb` | **0** | **7** |
| `filter_popup_reflex.rb` | 0 | 1 |
| übrige (`search`, `settings`, `location`, `counter`, `example`) | 0 | 0 |

`GameProtocolReflex` schreibt u. a. über `increment_points`, `decrement_points`,
`delete_inning`, `insert_inning`, `confirm_result` — also Punktestandsänderungen.

Die beiden Gates in `TableMonitorReflex` (Zeilen 353, 463) greifen nur für
`remote_request?`, decken also nicht die übrigen 44 Schreibpfade ab.

## Warum das vermutlich Absicht ist

Scoreboards werden **am Tisch ohne Login** bedient. `LocationsController#show` meldet
anonyme Besucher per `bypass_sign_in(User.scoreboard)` an — der Scoreboard-User hat Rolle
`player`, nicht `admin`. Ein `admin?`-Gate auf `increment_points` würde den
Normalbetrieb lahmlegen.

Die fehlenden Gates sind hier also plausibel gewollt, nicht vergessen.

## Die eigentliche, ungeprüfte Frage

Der Verzicht auf Autorisierung ist für ein **LAN im Vereinsheim** eine andere Aussage als
für eine **im Internet erreichbare** Instanz.

Zu klären:

1. Haben internetseitige Instanzen (insb. `api.carambus.de`) überhaupt aktive
   `TableMonitor`-/`Game`-Objekte, auf die diese Reflexes wirken könnten? Laut
   `CLAUDE.md` ist `TableMonitor` eine **lokale** Entität und `ApiProtector` schützt die
   Authority — dann liefe der Angriff dort ins Leere.
2. Falls ja: Genügt es, dass ein Client den Reflex-Namen und eine gültige Objekt-ID kennt?
   Eine Cable-Verbindung kann jeder öffnen (das ist gewollt, siehe Variante C).
3. Wären `location_id`-/`table_id`-Prüfungen der pragmatischere Schutz als Rollen-Gates —
   also „darf dieser Client diesen Tisch bedienen", statt „ist dieser Client Admin"?

## Wie zu prüfen wäre

Empirisch, nicht durch Code-Lesen (mehrfach hat in dieser Sitzung das Gegenteil geholfen):
eine Cable-Verbindung gegen eine **Testinstanz** öffnen, `GameProtocolReflex#increment_points`
mit einer gültigen `TableMonitor`-ID senden und beobachten, ob der Punktestand sich ändert.

**Nicht gegen Produktion.** Der Reflex schreibt.

## Zusammenhang

- `67dfa40f` — Variante C, anonyme Cable-Verbindungen zugelassen
- Historisch war die Lage **nicht besser**: Vor `1efa7995` erhielt jede Verbindung die
  Identität von `User.first`. Wer damals einen Reflex auslösen konnte, tat das mit
  dessen Rechten — inklusive der `admin?`-Gates, falls `User.first` ein Admin war.
  Variante C hat die Identität ehrlich gemacht, das Autorisierungsthema aber nicht berührt.
