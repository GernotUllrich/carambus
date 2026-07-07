---
name: hex-to-token-migration
description: Migrates hardcoded color hex (`#rgb`/`#rrggbb`), `<style>` blocks and inline `style="…color…"` in UI code to Tailwind design-token utilities with class-based dark mode. Use when migrating an admin/UI view or CSS file off hardcoded colors, when adding UI that must follow the new design conventions, or when `rake ui:no_hardcoded_hex` flags a new violation.
---

# Hex → Token Migration

Workflow der Phase-7 „Hex-Migration" (UX-Redesign): hartkodierte Farben in
UI-Code durch Tailwind-Token-Utilities + class-basierten Dark-Mode ersetzen —
**verhaltensneutral**, nur die Farbherkunft ändert sich.

Konventionen (Single-Source): **[`docs/ui-conventions.md`](../../../docs/ui-conventions.md)**.
Diese enthält die vollständige Flatui→Token-Mapping-Tabelle. Immer dort nachsehen.

## Wann anwenden

- Eine Admin-/UI-View oder eine kompilierte `.css` von Hex befreien.
- Neue UI schreiben, die den Design-Konventionen folgen muss.
- `rake ui:no_hardcoded_hex` (pre-commit/CI) meldet einen **neuen** Verstoß.

## Kernregeln (kurz)

- **ERB:** nur Utility-Klassen. KEINE inline `style=` mit Farbe, KEIN `<style>`.
  `theme()` löst in ERB NICHT auf.
- **Kompiliertes CSS:** `theme('colors.x.y')` statt Hex.
- **Dark-Mode Pflicht** auf farbigen Flächen: helle Panels → `dark:bg-gray-800/900`,
  dunkler Text → `dark:text-gray-100`, Borders → `dark:border-gray-700`.
  Dark ist **class-basiert** (`.dark` am `<html>`), nicht `prefers-color-scheme`.
- **Token:** `primary`(teal) · `gray`(warmGray) · `danger` · `success` · `warning`
  · `info` · `surface.*` · `discipline.*` (alle in `tailwind.config.js`).

## Schritte

1. **Hex-Recon** — betroffene Stellen finden:
   ```bash
   grep -rnE "#[0-9a-fA-F]{3,6}" <pfad>
   grep -rn "<style\|style=" <pfad>       # <style>-Blöcke + inline styles
   ```

2. **Mapping anwenden** — jeden Hex über die Tabelle in `docs/ui-conventions.md`
   auf ein Token ziehen (kühle Greys → warmGray-Ramp; Teal → `primary`; Status →
   `success`/`warning`/`danger`/`info`).

3. **Utilities + `dark:` an die Elemente** — inline `style=`/`<style>` **entfernen**,
   durch Utility-Klassen ersetzen und je farbiger Fläche die `dark:`-Variante
   ergänzen. Beispiel:
   ```erb
   <%# vorher %>
   <div style="background:#f8f9fa; border:2px solid #dee2e6; color:#2c3e50;">
   <%# nachher %>
   <div class="bg-gray-50 dark:bg-gray-800 border-2 border-gray-300 dark:border-gray-700 text-gray-800 dark:text-gray-100">
   ```
   Muster-Commits: `d61441ee` (inline `style=` → Utilities+Dark),
   `4c6a20f6` (View inkl. Tabelle/Badges/Buttons), `faa29460` (CSS `theme()`).

4. **Build** — Tailwind muss die neuen Klassen sehen:
   ```bash
   yarn build:css
   ```

5. **Precompile + Server-Neustart** — ⚠️ **kritisch**: Preview/Dev serviert
   PRECOMPILED Assets. Neue Utility-Klassen greifen erst nach:
   ```bash
   bin/rails assets:precompile
   # danach Server neu starten
   ```
   (Beim Deploy passiert das automatisch. „Klasse hinzugefügt, greift nicht" =
   fast immer dieser Schritt.)

6. **Visuell verifizieren in Light UND Dark** — die migrierte View in beiden
   Modi ansehen; Kontraste, Panels, Badges, Buttons prüfen. Verhalten muss
   identisch bleiben (Links, `method`/`confirm`, Uploads etc.).

7. **Baseline nachziehen** — die migrierte Datei aus der Ratchet-Baseline
   entfernen, damit sie dauerhaft sauber bleiben muss:
   ```bash
   bin/rails ui:no_hardcoded_hex:baseline   # regeneriert config/ui_hex_baseline.yml
   bin/rails ui:no_hardcoded_hex            # muss grün sein
   ```

## Fallstricke

- **`theme()` in ERB** löst nicht auf → dort Utility-Klassen.
- **Precompile vergessen** → Änderung „unsichtbar" in Preview/Dev.
- **Dark-Mode vergessen** → Fläche bricht im Dark-Mode (weißer Text auf weiß).
- **Baseline hochsetzen statt migrieren** → verboten; die Wache soll nur nach
  unten ratschen. Echte Ausnahme (Kiosk/Print/Vendor) → `config/ui_hex_allowlist.txt`.
- **Named Colors** (`color: white`, `background: red`) sind ebenfalls
  hartkodiert → auch auf Token/Utility ziehen.
