// ============================================================================
// tools/sync-core.mjs — inlinet den kanonischen Kern in die self-contained Dateien
// ----------------------------------------------------------------------------
// Liest shared/carambus-core.js + shared/carambus-core.css und ersetzt in jeder
// Ziel-HTML (index.html + schemes/*/index.html) den Inhalt zwischen den Markern:
//     /* >>> CARAMBUS-SYNC core-js  >>> */ … /* <<< CARAMBUS-SYNC core-js  <<< */
//     /* >>> CARAMBUS-SYNC core-css >>> */ … /* <<< CARAMBUS-SYNC core-css <<< */
// So bleiben die Deliverables eigenständige Einzeldateien (file://-tauglich), die
// Kern-Pflege passiert aber nur an EINER Stelle (shared/).
//
//   node tools/sync-core.mjs          # inlinen
//   node tools/sync-core.mjs --check  # nur prüfen (kein Schreiben) → wie check-core-sync
// ============================================================================
import { readFileSync, writeFileSync, existsSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const CHECK_ONLY = process.argv.includes("--check");

// Optionale Regionen (z. B. die generische KO-Engine + Plan-Registry) werden nur in
// Dateien eingebettet, die die passenden Marker enthalten — fehlt die Quelldatei, wird die
// Region übersprungen (so bleibt sync-core auch ohne generierte plans.js lauffähig).
function readOptional(rel) { const p = join(ROOT, rel); return existsSync(p) ? readFileSync(p, "utf8").trim() : null; }

const REGIONS = {
  "core-js": readFileSync(join(ROOT, "shared/carambus-core.js"), "utf8").trim(),
  "core-css": readFileSync(join(ROOT, "shared/carambus-core.css"), "utf8").trim()
};
const koEngine = readOptional("shared/ko-engine.js");
if (koEngine != null) REGIONS["ko-engine"] = koEngine;
const koPlans = readOptional("schemes/ko/plans.js");
if (koPlans != null) REGIONS["ko-plans"] = koPlans;

function targetFiles() {
  const files = [];
  if (existsSync(join(ROOT, "index.html"))) files.push(join(ROOT, "index.html"));
  const schemesDir = join(ROOT, "schemes");
  if (existsSync(schemesDir)) {
    for (const entry of readdirSync(schemesDir, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const f = join(schemesDir, entry.name, "index.html");
      if (existsSync(f)) files.push(f);
    }
  }
  return files;
}

function markers(region) {
  return {
    start: `/* >>> CARAMBUS-SYNC ${region} >>> */`,
    end: `/* <<< CARAMBUS-SYNC ${region} <<< */`
  };
}

// Ersetzt/extrahiert den Inhalt zwischen den Markern. Liefert {found, content, replaced}.
function regionRange(text, region) {
  const { start, end } = markers(region);
  const s = text.indexOf(start);
  if (s === -1) return null;
  // LETZTEN End-Marker nehmen (greedy): falls durch einen früheren Fehler eine
  // verwaiste Doppel-Kopie + zweiter End-Marker im File steht, wird die ganze
  // Spanne ersetzt → selbstheilend (kollabiert zu genau einer Kopie).
  const e = text.lastIndexOf(end);
  if (e === -1 || e < s) throw new Error(`Start-Marker ohne (gültigen) End-Marker für '${region}'`);
  return { s: s + start.length, e, start, end };
}

let changed = 0, drift = 0, scanned = 0;
for (const file of targetFiles()) {
  let text = readFileSync(file, "utf8");
  let fileTouched = false;
  for (const region of Object.keys(REGIONS)) {
    const r = regionRange(text, region);
    if (!r) continue;
    scanned++;
    const canonical = REGIONS[region];
    const current = text.slice(r.s, r.e).trim();
    if (current === canonical) continue;
    if (CHECK_ONLY) {
      drift++;
      console.error(`DRIFT: ${file} [${region}] weicht von shared/ ab`);
      continue;
    }
    text = text.slice(0, r.s) + "\n" + canonical + "\n" + text.slice(r.e);
    fileTouched = true;
  }
  if (fileTouched) { writeFileSync(file, text); changed++; console.log(`inlined → ${file.replace(ROOT + "/", "")}`); }
}

if (CHECK_ONLY) {
  if (drift > 0) { console.error(`\n❌ ${drift} Region(en) driften. 'node tools/sync-core.mjs' ausführen.`); process.exit(1); }
  console.log(`✅ ${scanned} Region(en) in Sync mit shared/.`);
} else {
  console.log(changed ? `\n✓ ${changed} Datei(en) aktualisiert.` : "\n✓ Bereits in Sync.");
  if (changed > 0) {
    console.log(`\nHinweis: bei Bedarf 'node tools/build-public.mjs' nachziehen,\n` +
                `damit public/ (Capistrano-rsync-Quelle) den frischen Stand hat.`);
  }
}
