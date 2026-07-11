#!/usr/bin/env bash
# paul-handoff-bundle.sh
# ---------------------------------------------------------------------------
# Bündelt alle NICHT-deployten PAUL-/Claude-Artefakte dieses Checkouts, damit
# ein neuer Entwickler in einem frischen Scenario nahtlos mit Claude + PAUL
# weiterarbeiten kann (/paul:resume läuft ohne Kontextverlust an).
#
# Bündelt (alles gitignored bzw. außerhalb des Repos):
#   A) .paul/                        — PAUL-Projektgedächtnis (STATE/PROJECT/ROADMAP/phases/…)
#   B) .claude/paul-framework/       — PAUL-Maschinerie (workflows/references/templates)
#      .claude/commands/paul/        — die /paul:*-Slash-Commands
#   C) ~/.claude/projects/<hash>/memory/  — Claude Auto-Memory (pfad-gehasht!)
#   D) UX-REDESIGN*.md + CARAMBUS-API-*-HANDOFF.md — Fahrplan/Authority-Handoffs (untracked)
#   E) config/carambus.yml + .claude/launch.json — lokale/scenario-Config (nur als REFERENZ)
#
# Ausgabe: tmp/paul-handoff-<stamp>.tar.gz  (tmp/ ist gitignored)
# ---------------------------------------------------------------------------
set -euo pipefail

# --- Projekt-Root ---
PROJECT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$PROJECT_DIR"

# --- Memory-Pfad aus dem absoluten Projektpfad ableiten (Slash -> Dash) ---
PROJECT_HASH="$(printf '%s' "$PROJECT_DIR" | sed 's|/|-|g')"
MEM_DIR="$HOME/.claude/projects/${PROJECT_HASH}/memory"

# --- Git-Kontext (dokumentiert, zu welchem Code-Stand die .paul/-Historie passt) ---
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo 'n/a')"
GIT_BRANCH="$(git branch --show-current 2>/dev/null || echo 'n/a')"

# --- Staging ---
STAMP="$(date +%Y%m%d-%H%M%S)"
BUNDLE="paul-handoff-${STAMP}"
STAGE_ROOT="$(mktemp -d)"
STAGE="${STAGE_ROOT}/${BUNDLE}"
mkdir -p "$STAGE"

echo "▶ PAUL-Handoff-Bundle"
echo "  Quelle:  $PROJECT_DIR  (@ ${GIT_BRANCH} ${GIT_COMMIT})"
echo "  Memory:  $MEM_DIR"
echo ""

# Helper: kopiere Quelle -> Ziel, wenn vorhanden
copy_if() {
  local src="$1" dest="$2"
  if [ -e "$src" ]; then
    mkdir -p "$(dirname "$dest")"
    cp -R "$src" "$dest"
    echo "  ✓ $src"
  else
    echo "  ⚠ übersprungen (fehlt): $src"
  fi
}

echo "Sammle Artefakte:"
# A) PAUL-Projektgedächtnis
copy_if ".paul" "$STAGE/repo/.paul"
# B) PAUL-Maschinerie
copy_if ".claude/paul-framework" "$STAGE/repo/.claude/paul-framework"
copy_if ".claude/commands/paul"  "$STAGE/repo/.claude/commands/paul"
# D) Root-Fahrplan-/Handoff-Docs (untracked)
shopt -s nullglob
for m in UX-REDESIGN.md UX-REDESIGN-HANDOFF.md CARAMBUS-API-*-HANDOFF.md; do
  copy_if "$m" "$STAGE/repo/$m"
done
shopt -u nullglob
# C) Claude Auto-Memory (außerhalb Repo)
copy_if "$MEM_DIR" "$STAGE/claude-memory"
# E) Lokale/scenario-Config — NUR als Referenz (NICHT auto-installieren, muss adaptiert werden)
copy_if "config/carambus.yml" "$STAGE/local-config-REFERENCE/carambus.yml"
copy_if ".claude/launch.json" "$STAGE/local-config-REFERENCE/launch.json"

# E') Account-spezifische ~/.carambus_config (Einstiegspunkte: CARAMBUS_BASE u. a.)
#     ENTHÄLT EIN SECRET (CARAMBUS_PASSWORD) -> nur redigiertes Template ins Bundle,
#     niemals die echten Werte weiterreichen.
CC_ACCOUNT="$HOME/.carambus_config"
if [ -f "$CC_ACCOUNT" ]; then
  mkdir -p "$STAGE/local-config-REFERENCE"
  sed -E 's/^([[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*[:=]).*/\1 <HIER-EINTRAGEN>/' "$CC_ACCOUNT" \
    > "$STAGE/local-config-REFERENCE/carambus_config.example"
  echo "  ✓ ~/.carambus_config -> Template (Werte maskiert, KEIN Secret im Bundle)"
else
  echo "  ⚠ übersprungen (fehlt): ~/.carambus_config"
fi

# --- INSTALL.sh (läuft beim Ziel-Entwickler, berechnet den Memory-Hash dort neu) ---
cat > "$STAGE/INSTALL.sh" <<'INSTALL_EOF'
#!/usr/bin/env bash
# Im ZIEL-Checkout (Repo-Root des neuen Scenarios) ausführen:  bash INSTALL.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
TARGET="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

echo "▶ PAUL-Handoff installieren nach: $TARGET"

# 1) PAUL-Gedächtnis + Maschinerie + Docs ins Ziel-Repo (mergen, ohne lokale Config zu überschreiben)
cp -R "$HERE/repo/." "$TARGET/"
echo "  ✓ .paul/ + .claude/paul-framework/ + .claude/commands/paul/ + Root-Docs"

# 2) Claude Auto-Memory in den PFAD-KORREKTEN Ordner (Hash aus DIESEM Checkout-Pfad)
if [ -d "$HERE/claude-memory" ]; then
  NEW_HASH="$(printf '%s' "$TARGET" | sed 's|/|-|g')"
  NEW_MEM="$HOME/.claude/projects/${NEW_HASH}/memory"
  mkdir -p "$NEW_MEM"
  cp -R "$HERE/claude-memory/." "$NEW_MEM/"
  echo "  ✓ Claude-Memory -> $NEW_MEM"
fi

echo ""
echo "✅ Installiert. Nächste Schritte:"
echo "   1) Lokale Config anlegen/adaptieren (NICHT aus dem Bundle übernommen):"
echo "      - config/carambus.yml    (Scenario-Kontext/region/DB) -> Vorlage: local-config-REFERENCE/carambus.yml"
echo "      - .claude/launch.json     (Preview-Port)               -> Vorlage: local-config-REFERENCE/launch.json"
echo "      - ~/.carambus_config      (CARAMBUS_BASE/SSID/PASSWORD) -> Vorlage: local-config-REFERENCE/carambus_config.example"
echo "        (echtes CARAMBUS_PASSWORD separat/sicher besorgen - NICHT im Bundle)"
echo "   2) PAUL-Framework-Version prüfen (muss zur .paul/-Struktur passen)."
echo "   3) In Claude Code:  /paul:resume"
INSTALL_EOF
chmod +x "$STAGE/INSTALL.sh"

# --- README (Erklärung + manuelle Fallback-Anleitung) ---
cat > "$STAGE/PAUL-HANDOFF-README.md" <<EOF
# PAUL-Handoff-Bundle

**Erstellt:** ${STAMP}
**Quell-Checkout:** \`${PROJECT_DIR}\`
**Code-Stand:** Branch \`${GIT_BRANCH}\`, Commit \`${GIT_COMMIT}\`
**Quell-Memory-Pfad:** \`${MEM_DIR}\`

Dieses Bundle enthält alles, was **nicht** per \`git clone\` mitkommt (gitignored
bzw. außerhalb des Repos), damit ein neuer Entwickler nahtlos mit Claude + PAUL
weiterarbeiten kann.

## Inhalt

| Ordner | Inhalt | Ziel |
|--------|--------|------|
| \`repo/.paul/\` | PAUL-Projektgedächtnis (STATE/PROJECT/ROADMAP/MILESTONES/paul.json + phases/ + handoffs/) | ins Ziel-Repo-Root |
| \`repo/.claude/paul-framework/\` | PAUL-Maschinerie (workflows/references/templates) | ins Ziel-Repo-Root |
| \`repo/.claude/commands/paul/\` | die \`/paul:*\`-Slash-Commands | ins Ziel-Repo-Root |
| \`repo/UX-REDESIGN*.md\`, \`repo/CARAMBUS-API-*-HANDOFF.md\` | Fahrplan + Authority-Handoffs | ins Ziel-Repo-Root |
| \`claude-memory/\` | Claude Auto-Memory (MEMORY.md + Einzel-Files) | **pfad-gehashter** Ordner im \$HOME (siehe unten) |
| \`local-config-REFERENCE/\` | \`carambus.yml\` + \`launch.json\` + \`carambus_config.example\` | **NUR Vorlage** — pro Scenario adaptieren, NICHT blind kopieren |

## Installation (empfohlen)

Im **Ziel-Checkout** (Repo-Root des neuen Scenarios) entpacken und ausführen:

\`\`\`bash
tar -xzf ${BUNDLE}.tar.gz
cd ${BUNDLE}
bash INSTALL.sh        # von IRGENDWO ausführbar; nimmt das Ziel-Repo via git rev-parse
\`\`\`

\`INSTALL.sh\` legt \`.paul/\` + PAUL-Maschinerie + Docs ins Ziel-Repo und kopiert
das Memory in den **korrekten** \$HOME-Ordner (Hash aus dem NEUEN Checkout-Pfad).

## ⚠️ Wichtige Gotchas

1. **Memory-Pfad ist pfad-gehasht.** Der Zielordner heißt
   \`\$HOME/.claude/projects/<ABS-PFAD-mit-Slash→Dash>/memory\`. \`INSTALL.sh\`
   berechnet das automatisch. Manuell:
   \`\`\`bash
   NEW_MEM="\$HOME/.claude/projects/\$(pwd | sed 's|/|-|g')/memory"   # aus Ziel-Repo-Root
   mkdir -p "\$NEW_MEM" && cp -R claude-memory/. "\$NEW_MEM"/
   \`\`\`
2. **PAUL-Version muss passen.** \`.paul/\` (Gedächtnis) und \`.claude/paul-framework/\`
   (Maschinerie) stammen aus demselben Stand — nicht mit einer anderen PAUL-Version mischen.
3. **Lokale Config nicht blind übernehmen.** \`config/carambus.yml\` trägt den
   Scenario-/Region-/DB-Kontext → für das neue Scenario neu setzen (Vorlage in
   \`local-config-REFERENCE/\`). \`config/credentials/*.key\` sind bereits im Git.
5. **\`~/.carambus_config\` (account-spezifisch) selbst anlegen.** Hält Einstiegspunkte
   (\`CARAMBUS_BASE\` = Basisverzeichnis der Checkouts, \`CARAMBUS_WLAN_SSID\`) **und ein
   Secret** (\`CARAMBUS_PASSWORD\`). Aus Sicherheitsgründen liegt im Bundle nur ein
   **redigiertes Template** (\`local-config-REFERENCE/carambus_config.example\`, Werte maskiert).
   Der neue Entwickler legt \`~/.carambus_config\` mit **eigenen** Werten an — die echten
   Secrets werden über einen sicheren Kanal übergeben, nicht über dieses Bundle.
4. **Danach:** in Claude Code \`/paul:resume\` — sollte am letzten Loop aufsetzen.
EOF

# --- Packen ---
mkdir -p "$PROJECT_DIR/tmp"
OUT="$PROJECT_DIR/tmp/${BUNDLE}.tar.gz"
tar -czf "$OUT" -C "$STAGE_ROOT" "$BUNDLE"
rm -rf "$STAGE_ROOT"

echo ""
echo "✅ Bundle erstellt:"
echo "   $OUT"
echo "   Größe: $(du -h "$OUT" | cut -f1)"
echo ""
echo "Weitergeben, dann beim neuen Entwickler:"
echo "   tar -xzf $(basename "$OUT") && cd ${BUNDLE} && bash INSTALL.sh"
