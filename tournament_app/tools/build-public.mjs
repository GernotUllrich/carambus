#!/usr/bin/env node
// ============================================================================
// tools/build-public.mjs — baut die ausgelieferte App unter <repo>/public/app/
// ----------------------------------------------------------------------------
// Quelle: tournament_app/index.html (Launcher) + tournament_app/schemes/<id>/index.html.
// Ziel:   public/app/ im Carambus-Repo. Die Dateien gehen mit jedem Carambus-Deploy
// mit; nginx liefert /app/ nur aus, wenn das Szenario serve_tournament_app: true setzt
// (templates/nginx/nginx_conf.erb).
//
// Bewusst NUR die HTMLs (alle Schemas sind self-contained, der Core wird via
// tools/sync-core.mjs inline einkopiert). KEIN PoolSchemata/, KEIN shared/, KEIN tools/.
//
// Workflow nach Code-Änderungen (aus dem Repo-Root):
//   node tournament_app/tools/sync-core.mjs      # inlinet shared/* in die HTMLs
//   node tournament_app/tools/build-public.mjs   # spiegelt die HTMLs nach public/app/
//   Quelle UND public/app/ committen — CI prüft mit --check, dass beide gleich sind
//
// Aufruf:
//   node tournament_app/tools/build-public.mjs
//   node tournament_app/tools/build-public.mjs --check   # nur verifizieren (Exit 1 bei Drift)
// ============================================================================
import { copyFileSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, relative } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "..", "public", "app");
const CHECK = process.argv.includes("--check");

// Quelldateien — exakt die zur Laufzeit geladenen HTMLs. Jede ist self-contained
// (sync-core hat alle shared/-Inhalte schon eingebettet).
const FILES = [
  "index.html",
  "schemes/doppelko/index.html",
  "schemes/plan/index.html",
  "schemes/3band-team/index.html",
  "schemes/spieltag/index.html"
];

// Zusätzliche Seiten, die woanders liegen, aber unter /app/ erreichbar sein sollen:
// [Quelle relativ zu tournament_app/, Ziel relativ zu public/app/]. Derzeit keine —
// die Turnierleiter-Anleitung steht in der Carambus-Doku (docs/managers/tournament-app).
const EXTRA = [];

// Alles, was am Ende in public/app/ liegen darf: 1:1-Kopien + die Extras unter ihrem Zielnamen.
const TARGETS = [...FILES, ...EXTRA.map(([, dst]) => dst)];

// Defensive Pfad-Validierung: keine `/`-Pfade in href/src — die würden unter
// `https://<host>/app/` 404 geben (zeigen auf den Carambus-Server-Root).
function assertNoAbsoluteRefs(content, file) {
  const errors = [];
  // src="/…" oder href="/…" (außer "//" für protocol-relative — die nicht erlaubt sein sollten, aber egal)
  const rx = /\b(src|href)\s*=\s*"\/(?!\/)/g;
  let m;
  while ((m = rx.exec(content)) !== null) {
    const ctx = content.slice(Math.max(0, m.index - 40), Math.min(content.length, m.index + 80));
    errors.push(`  ${file}: absoluter Pfad bei index ${m.index} — Auszug: …${ctx.replace(/\s+/g, " ")}…`);
  }
  return errors;
}

function readAllFilesIn(dir) {
  const out = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = join(dir, entry.name);
    if (entry.isDirectory()) out.push(...readAllFilesIn(full));
    else out.push(full);
  }
  return out;
}

let pathErrors = [];
for (const rel of [...FILES, ...EXTRA.map(([src]) => src)]) {
  const src = join(ROOT, rel);
  if (!existsSync(src)) { console.error(`✗ Quelle fehlt: ${rel}`); process.exit(1); }
  pathErrors.push(...assertNoAbsoluteRefs(readFileSync(src, "utf8"), rel));
}
if (pathErrors.length) {
  console.error("✗ Absolute Pfade in den HTMLs gefunden — würden unter /app/ 404 geben:");
  pathErrors.forEach(e => console.error(e));
  process.exit(1);
}

// --check-Modus: nur prüfen, ob public/app/ mit den Quellen übereinstimmt.
if (CHECK) {
  if (!existsSync(OUT)) { console.error("DRIFT: public/app/ existiert nicht. 'node tournament_app/tools/build-public.mjs' ausführen."); process.exit(1); }
  let drift = 0;
  for (const [rel, dst] of [...FILES.map(f => [f, f]), ...EXTRA]) {
    const a = readFileSync(join(ROOT, rel), "utf8");
    const b = existsSync(join(OUT, dst)) ? readFileSync(join(OUT, dst), "utf8") : null;
    if (a !== b) { console.error(`DRIFT: public/app/${dst} weicht von tournament_app/${rel} ab`); drift++; }
  }
  // Zusätzlich: keine Geistereinträge in public/app/ (außer _README.txt)
  const existing = readAllFilesIn(OUT).map(p => relative(OUT, p));
  const allowed = new Set([...TARGETS, "_README.txt"]);
  for (const p of existing) {
    if (!allowed.has(p)) { console.error(`DRIFT: public/app/${p} ist fremd (nicht gelistet)`); drift++; }
  }
  if (drift > 0) { console.error(`❌ ${drift} Drift(s) in public/app/.`); process.exit(1); }
  console.log(`✅ public/app/ in Sync mit ${TARGETS.length} Quelldateien.`);
  process.exit(0);
}

// Build: public/app/ leeren + neu aufbauen (echte Kopien, keine Symlinks).
if (existsSync(OUT)) rmSync(OUT, { recursive: true, force: true });
mkdirSync(OUT, { recursive: true });

for (const [rel, target] of [...FILES.map(f => [f, f]), ...EXTRA]) {
  const dst = join(OUT, target);
  mkdirSync(dirname(dst), { recursive: true });
  copyFileSync(join(ROOT, rel), dst);
  console.log(`copied  public/app/${target}${target === rel ? "" : `  ← ${rel}`}`);
}

writeFileSync(join(OUT, "_README.txt"),
  "AUTOGENERIERT von tournament_app/tools/build-public.mjs — nicht von Hand editieren.\n" +
  "Quelle: tournament_app/index.html + tournament_app/schemes/<id>/index.html (self-contained).\n" +
  "Ausgeliefert unter /app/, wenn das Szenario serve_tournament_app: true setzt.\n" +
  "\n" +
  "Nach Code-Änderungen (aus dem Repo-Root):\n" +
  "  node tournament_app/tools/sync-core.mjs\n" +
  "  node tournament_app/tools/build-public.mjs\n"
);

console.log(`\n✓ ${TARGETS.length} Datei(en) in public/app/ aktualisiert.`);
