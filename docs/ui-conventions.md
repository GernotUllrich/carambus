# UI-/CSS-Konventionen (Carambus)

Verbindliche Regeln für UI-Code seit dem Redesign („Richtung A" — helle SaaS-
Ästhetik, ruhiger Teal-Akzent, warmes Neutralgrau). Ziel: **keine hartkodierten
Farben mehr**, überall Design-Token, überall Dark-Mode.

Die mechanische Wache `rake ui:no_hardcoded_hex` (pre-commit + CI) erzwingt den
Kern dieser Regeln. Der Migrations-Workflow steckt im Skill
`.agents/skills/hex-to-token-migration/`.

---

## 1. Grundregeln

- **ERB-Views:** ausschließlich Tailwind-Utility-Klassen. **KEINE** inline
  `style="…"` mit Farbe, **KEINE** `<style>`-Blöcke.
  `theme()` löst in ERB **nicht** auf (kein PostCSS-Durchlauf) — dort also
  Utility-Klassen (`bg-primary-600`, `text-gray-800`, …), nicht `theme()`.
- **Kompiliertes CSS** (die per `@import` in
  `app/assets/stylesheets/application.tailwind.css` eingebundenen `.css`-Dateien):
  Farben über `theme('colors.x.y')` beziehen, nie als Hex hartkodieren.
- **Token sind Single-Source:** alle Farben leiten aus `tailwind.config.js` ab
  (Ramps `primary`, `gray`, `danger`, `success`, `warning`, `info` sowie
  `surface.*` und `discipline.*`). Neue Farbe nötig? → erst Token definieren,
  dann verwenden. Kein „schnelles Hex".
- **Dark-Mode ist Pflicht** auf farbigen Flächen (siehe §2).
- **Ausnahmen** (Kiosk/Scoreboard, Print, Vendor-Widgets) sind bewusst aus dem
  Scope: siehe `config/ui_hex_allowlist.txt`. Nur dort eintragen, wenn eine
  Datei GENUINE außerhalb der Token-Ästhetik liegt — nicht, um eine unbequeme
  Migration zu umgehen.

---

## 2. Dark-Mode (Pflicht)

Dark-Mode ist **class-basiert** (`.dark` am `<html>`), **nicht**
`prefers-color-scheme`. Auf jeder farbigen Fläche gehört zur Light-Utility die
passende `dark:`-Variante:

| Zweck            | Light                    | + Dark                          |
|------------------|--------------------------|---------------------------------|
| Panel / Fläche   | `bg-white` / `bg-gray-50`| `dark:bg-gray-800` / `-gray-900`|
| Text (dunkel)    | `text-gray-800`          | `dark:text-gray-100`            |
| Text (sekundär)  | `text-gray-500/600`      | `dark:text-gray-300/400`        |
| Border           | `border-gray-200/300`    | `dark:border-gray-700`          |

Faustregel: helle Panels → `dark:bg-gray-800/900`, dunkler Text →
`dark:text-gray-100`, Borders → `dark:border-gray-700`.

---

## 3. Mapping-Tabelle: Flatui-Alt-Palette → Token-Utility

Die alten Views nutzten eine „flatui"-Hex-Palette. Beim Migrieren jeden Hex
über diese Tabelle auf ein Token ziehen. (ERB → Utility-Klasse; CSS →
`theme('colors.…')` mit gleicher Ramp/Shade.)

**Neutral / Grund:**

| Alt-Hex                                             | Token       |
|----------------------------------------------------|-------------|
| `#fff` `#ffffff`                                    | `white`     |
| `#000`                                              | `black`     |
| `#f8f9fa` `#f8f8f8` `#f3f4f6`                        | `gray-50/100` |
| `#e2e8f0` `#dee2e6` `#ddd` `#d1d5db` `#e9ecef`       | `gray-200/300` |
| `#ccc`                                              | `gray-300`  |
| `#6c757d` `#6b7280` `#7f8c8d`                        | `gray-500`  |
| `#666`                                              | `gray-500/600` |
| `#495057` `#4a5568`                                 | `gray-600/700` |
| `#374151` `#2d3748`                                 | `gray-700/800` |
| `#1a202c`                                           | `gray-900`  |

> Hinweis: `gray` ist im Projekt eine **warme** Neutral-Ramp (`warmGray`), die
> die kühlen Alt-Greys bewusst wärmer harmonisiert — das ist gewollt.

**Akzent:**

| Alt                          | Token             |
|------------------------------|-------------------|
| Teal-Töne                    | `primary.<shade>` (600 = Accent) |

**Status:**

| Bedeutung | Alt-Hex                                             | Token     |
|-----------|----------------------------------------------------|-----------|
| success   | `#10b981` `#28a745` `#27ae60` `#4CAF50`             | `success` |
| warning   | `#fbbf24` `#f59e0b` `#f39c12` `#f67f32` `#ffc107`    | `warning` |
| danger    | `#ef4444` `#e53e3e` `#e74c3c` `#dc3545` `#ff6b6b`    | `danger`  |
| info/blau | `#3957f4` `#2f87ee` `#3498db` `#007bff`             | `info`    |
| violet    | `#8b5cf6`                                           | `violet` (Tailwind-Default) |
| indigo/purple-Gradient | `#667eea` → `#764ba2`                 | `indigo-500` → `purple-800` |

**Beispiel (ERB):**

```erb
<%# vorher %>
<div style="background: #f8f9fa; border: 2px solid #dee2e6; color: #2c3e50;">

<%# nachher %>
<div class="bg-gray-50 dark:bg-gray-800 border-2 border-gray-300 dark:border-gray-700 text-gray-800 dark:text-gray-100">
```

**Beispiel (kompiliertes CSS):**

```css
/* vorher */  background: #0f5f56;
/* nachher */ background: theme('colors.primary.600');
```

Referenz-Commits als Muster: `faa29460` (Status-Tokens + Core-CSS),
`d61441ee` (Admin-View inline `style=` → Utilities+Dark),
`4c6a20f6` (Admin-View inkl. Tabelle/Badges/Buttons).

---

## 4. Precompile-Falle (wichtig!)

Preview/Dev serviert **precompiled** Assets. Neue Utility-Klassen (die Tailwind
erst beim Build aus den Views scannt) erscheinen **nicht** automatisch — erst
nach:

```bash
yarn build:css                 # Tailwind neu kompilieren (scannt Views/CSS)
bin/rails assets:precompile    # precompiled Assets erneuern
# danach Server neu starten
```

Beim Deploy passiert das automatisch. Lokal führt „ich habe die Klasse doch
hinzugefügt, sie greift aber nicht" fast immer auf diesen Schritt zurück.

---

## 5. Die Wache (`rake ui:no_hardcoded_hex`)

Verhindert, dass **neue** hartkodierte Farben in den In-Scope-Bereich rutschen
(Admin-Views + bereits migrierte Core-CSS).

- **Grün ab Tag 1** über eine Ratchet-Baseline (`config/ui_hex_baseline.yml`):
  sie „grandfahtert" die Anzahl bekannter Verstoß-Zeilen je noch-nicht-
  migrierter Datei. Die Wache failt nur bei **neuen** Verstößen — mehr Hex in
  einer Datei als in der Baseline, oder Verstöße in einer nicht gelisteten Datei.
- **Beim Migrieren** einer Datei ihren Baseline-Eintrag **entfernen** → sie muss
  danach dauerhaft sauber (0) bleiben.
- **Nach absichtlichen Änderungen** Baseline neu erzeugen:
  `bin/rails ui:no_hardcoded_hex:baseline`. Niemals die Zahlen von Hand
  hochsetzen, um die Wache stumm zu schalten.
- **Ausnahmen:** `config/ui_hex_allowlist.txt` (Kiosk/Print/Vendor).

**Lokal auslösen:**

```bash
bin/rails ui:no_hardcoded_hex        # oder direkt: ruby bin/ui-hex-guard
bundle exec overcommit --install     # einmalig: pre-commit-Hook scharf schalten
bundle exec overcommit --sign        # nach Änderung an .overcommit.yml
```

**In CI:** läuft als Schritt „UI-Guardrail" im `lint`-Job von
`.github/workflows/ci.yml`.

Implementierung: `lib/ui_hex_guard.rb` (Logik, Rails-frei),
`bin/ui-hex-guard` (Standalone-Einstieg), `lib/tasks/ui.rake` (rake-Wrapper).
