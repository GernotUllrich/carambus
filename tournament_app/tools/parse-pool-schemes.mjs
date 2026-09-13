#!/usr/bin/env node
// Parst die gespeicherten ClubCloud-Turnierplan-Seiten in PoolSchemata/*.html in eine
// normalisierte JSON-Registry (schemes/ko/plans.json). P1 der Scheme-Registry.
//
// Jede Partie:  { nr, round, a, b, winnerRang?, loserRang? }
//   a/b ∈ { seed:N (+bye:true) } | { winnerOf:N } | { loserOf:N } | { lot:true } | { raw:"…" }
//   winnerRang/loserRang = Endplatz aus der GEWINNER/VERLIERER-Spalte (sonst spielt der
//   Spieler weiter und wird von einer späteren Partie referenziert).
//
// Aufruf:  node tools/parse-pool-schemes.mjs          (schreibt JSON + Report)
//          node tools/parse-pool-schemes.mjs --check  (nur validieren, nichts schreiben)

import { readFileSync, writeFileSync, readdirSync, mkdirSync, existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC_DIR = join(ROOT, "PoolSchemata");
const OUT_DIR = join(ROOT, "schemes", "ko");
const OUT_FILE = join(OUT_DIR, "plans.json");
const CHECK = process.argv.includes("--check");

const stripTags = s => String(s).replace(/<br\s*\/?>/gi, " ").replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/gi, " ").replace(/&amp;/gi, "&").replace(/\s+/g, " ").trim();

function parseRef(s) {
  s = stripTags(s);
  let m;
  if ((m = /Setzplatz\s+(\d+)/i.exec(s))) { const r = { seed: +m[1] }; if (/Freilos/i.test(s)) r.bye = true; return r; }
  if ((m = /Gewinner\s+Partie\s+(\d+)/i.exec(s))) return { winnerOf: +m[1] };
  if ((m = /Verlierer\s+Partie\s+(\d+)/i.exec(s))) return { loserOf: +m[1] };
  if (/Auslosung/i.test(s)) return { lot: true };
  if (!s || s === ":") return null;
  return { raw: s };
}
const parseRang = s => { const m = /Rang\s+(\d+)/i.exec(stripTags(s)); return m ? +m[1] : null; };

function classify(name) {
  let m;
  if ((m = /^DKO-(\d+)\s*\+\s*(\d+)\s*EKO/i.exec(name))) return { type: "DKO+EKO", size: +m[1], ekoSize: +m[2] };
  if ((m = /^DKO-(\d+)/i.exec(name))) return { type: "DKO", size: +m[1] };
  if ((m = /^EKO-(\d+)/i.exec(name))) return { type: "EKO", size: +m[1] };
  return { type: "?", size: null };
}

function parseFile(html, fallbackName) {
  const clean = html.replace(/<script[\s\S]*?<\/script>/gi, "").replace(/<style[\s\S]*?<\/style>/gi, "");
  const titleM = /Turnierplan:\s*<\/td>\s*<td[^>]*>\s*<b>([^<]+)<\/b>/i.exec(clean) || /<b>([A-Z]KO-[^<]+)<\/b>/i.exec(clean);
  const name = titleM ? stripTags(titleM[1]) : fallbackName;

  // Tokens (Rundenkopf | Datenzeile) in Dokumentreihenfolge einsammeln
  const tokens = [];
  let rx = /<th\b[^>]*colspan="6"[^>]*>([\s\S]*?)<\/th>/gi, m;
  while ((m = rx.exec(clean))) tokens.push({ pos: m.index, kind: "round", text: stripTags(m[1]) });
  rx = /<tr\b[^>]*>\s*<td[^>]*>\s*<b>\s*(\d+)\s*<\/b>\s*<\/td>([\s\S]*?)<\/tr>/gi;
  while ((m = rx.exec(clean))) tokens.push({ pos: m.index, kind: "row", nr: +m[1], rest: m[2] });
  tokens.sort((a, b) => a.pos - b.pos);

  const matches = [];
  let round = "";
  for (const t of tokens) {
    if (t.kind === "round") { round = t.text; continue; }
    const cells = [...t.rest.matchAll(/<td\b[^>]*>([\s\S]*?)<\/td>/gi)].map(c => c[1]);
    // erwartet: [SPIELER1, ":", SPIELER2, GEWINNER, VERLIERER]
    const sp1 = cells[0], sp2 = cells[2], gew = cells[3] ?? "", ver = cells[4] ?? "";
    const match = { nr: t.nr, round, a: parseRef(sp1), b: parseRef(sp2) };
    const wr = parseRang(gew), lr = parseRang(ver);
    if (wr != null) match.winnerRang = wr;
    if (lr != null) match.loserRang = lr;
    matches.push(match);
  }
  matches.sort((a, b) => a.nr - b.nr);
  return { name, ...classify(name), matches };
}

function validate(plan) {
  const errs = [];
  const nrs = new Set(plan.matches.map(m => m.nr));
  for (const m of plan.matches) {
    for (const side of ["a", "b"]) {
      const r = m[side];
      if (!r) { errs.push(`P${m.nr}: Slot ${side} leer`); continue; }
      if (r.raw) errs.push(`P${m.nr}.${side}: unparsbar "${r.raw}"`);
      if ((r.winnerOf != null && !nrs.has(r.winnerOf)) || (r.loserOf != null && !nrs.has(r.loserOf)))
        errs.push(`P${m.nr}.${side}: verweist auf fehlende Partie ${r.winnerOf ?? r.loserOf}`);
      if (r.seed != null && plan.size && r.seed > plan.size) errs.push(`P${m.nr}.${side}: Setzplatz ${r.seed} > Größe ${plan.size}`);
    }
  }
  // jeder Teilnehmer-Endrang sollte am Ende vergeben sein (grobe Plausibilität): Rang 1 & 2 existieren
  const rangs = new Set(plan.matches.flatMap(m => [m.winnerRang, m.loserRang].filter(x => x != null)));
  if (!rangs.has(1)) errs.push("kein Rang 1 vergeben");
  return errs;
}

// ---- Lauf ----
const files = readdirSync(SRC_DIR).filter(f => /\.html$/i.test(f));
const plans = [];
const report = [];
let totalErr = 0;
for (const f of files.sort()) {
  const html = readFileSync(join(SRC_DIR, f), "utf8");
  const plan = parseFile(html, f.replace(/\.html$/i, "").trim());
  const id = plan.name.replace(/\s+/g, " ").trim();
  plan.id = id;
  const errs = validate(plan);
  totalErr += errs.length;
  const lot = plan.matches.filter(m => m.a?.lot || m.b?.lot).length;
  report.push(`${errs.length ? "✗" : "✓"} ${id.padEnd(34)} [${plan.type}/${plan.size}] ${plan.matches.length} Partien${lot ? `, ${lot}× Auslosung` : ""}${errs.length ? "  → " + errs.join("; ") : ""}`);
  plans.push(plan);
}

console.log(report.join("\n"));
console.log(`\n${plans.length} Pläne, ${totalErr} Validierungsfehler.`);

if (!CHECK) {
  if (!existsSync(OUT_DIR)) mkdirSync(OUT_DIR, { recursive: true });
  // nach id deduplizieren (es gibt Datei-Dubletten)
  const byId = new Map();
  for (const p of plans) byId.set(p.id, p);
  const registry = { schema: "carambus.ko-plans/v1", generated: new Date().toISOString().slice(0, 10), plans: [...byId.values()] };
  writeFileSync(OUT_FILE, JSON.stringify(registry, null, 2));
  console.log(`\n→ ${OUT_FILE} (${byId.size} eindeutige Pläne)`);
  // Kompaktes JS-Modul (window.KO_PLANS) für die file://-taugliche Einbettung ins KO-Schema
  // (wird via tools/sync-core.mjs zwischen den CARAMBUS-SYNC ko-plans-Markern inline kopiert).
  const OUT_JS = join(OUT_DIR, "plans.js");
  writeFileSync(OUT_JS, "// AUTOGENERIERT von tools/parse-pool-schemes.mjs — nicht von Hand editieren.\n" +
    "// Quelle: PoolSchemata/*.html → schemes/ko/plans.json (Schema carambus.ko-plans/v1).\n" +
    "window.KO_PLANS = " + JSON.stringify(registry) + ";\n");
  console.log(`→ ${OUT_JS}`);
}
