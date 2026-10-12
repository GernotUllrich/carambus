// Verifiziert die generische KO-Engine gegen ALLE Registry-Pläne.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const src = readFileSync(join(ROOT, "shared", "ko-engine.js"), "utf8");
const mod = { exports: {} };
new Function("module", "exports", "window", src)(mod, mod.exports, undefined);
const KO = mod.exports;
const registry = JSON.parse(readFileSync(join(ROOT, "schemes", "ko", "plans.json"), "utf8"));

function players(n) { return Array.from({ length: n }, (_, i) => ({ seed: i + 1, cc_id: 1000 + i, firstname: "P" + (i + 1), lastname: "" })); }

function simulate(plan, count, pick) {
  const run = KO.buildRun(plan, players(count), { shuffle: a => a.slice() }); // identische "Auslosung" → deterministisch
  let guard = 0;
  while (!KO.isFinished(run) && guard++ < 5000) {
    const ready = KO.readyMatches(run);
    if (!ready.length) break;
    for (const m of ready) {
      const slot = pick ? pick(m) : ((m.a.seed ?? 9e9) <= (m.b.seed ?? 9e9) ? "a" : "b"); // default: bessere Setzung gewinnt
      KO.recordMatch(run, m.nr, slot, { a: { balls: slot === "a" ? 100 : 50, innings: 20, hs: 10 }, b: { balls: slot === "b" ? 100 : 50, innings: 20, hs: 10 } });
    }
  }
  return run;
}

function check(plan, count) {
  const run = simulate(plan, count);
  const errs = [];
  if (!KO.isFinished(run)) errs.push("nicht beendet (stuck)");
  const pl = KO.placements(run);
  if (pl.length !== count) errs.push(`platziert ${pl.length} ≠ Spieler ${count}`);
  if (!pl.some(p => p.place === 1)) errs.push("kein Rang 1");
  // jeder reale Spieler genau einmal:
  const seen = new Set(pl.map(p => p.player.cc_id));
  if (seen.size !== pl.length) errs.push("Spieler doppelt platziert");
  // bei "bessere Setzung gewinnt": Champion = Setzplatz 1
  const champ = pl.find(p => p.place === 1);
  if (champ && champ.player.seed !== 1) errs.push(`Champion Setzplatz ${champ.player.seed} (erwartet 1)`);
  return { errs, placed: pl.length, games: KO.playedGames(run).length, ranks: [...new Set(pl.map(p => p.place))].sort((a, b) => a - b) };
}

console.log("=== Alle Pläne: voll besetzt + mit Freilosen ===");
let totalErr = 0;
for (const plan of registry.plans) {
  const full = check(plan, plan.size);
  const reduced = Math.max(2, plan.size - Math.floor(plan.size / 4)); // erzeugt Freilose
  const part = check(plan, reduced);
  const e = full.errs.length + part.errs.length; totalErr += e;
  const tag = e ? "✗" : "✓";
  console.log(`${tag} ${plan.id.padEnd(34)} voll(${plan.size}): ${full.placed} platz., ${full.games} Sp.` +
    `${full.errs.length ? " ⚠ " + full.errs.join("; ") : ""}` +
    ` | Freilos(${reduced}): ${part.placed} platz.${part.errs.length ? " ⚠ " + part.errs.join("; ") : ""}`);
}

// === Spezifisch: DKO-Grand-Final-Reset ===
console.log("\n=== DKO-004 Grand-Final-Reset ===");
const dko4 = registry.plans.find(p => p.id.startsWith("DKO-004"));
// Reset erzwingen: in der GF-Partie (a=winnerOf3 [WB], b=winnerOf5 [LB]) gewinnt der LB-Spieler (b)
const resetRun = simulate(dko4, 4, m => {
  const isGF = m.aRef && m.aRef.winnerOf === 3 && m.bRef && m.bRef.winnerOf === 5;
  if (isGF) return "b"; // LB-Sieger gewinnt 1. Finale → Reset nötig
  const reset = KO.resetSourceOf(m);
  if (reset != null) return "a"; // im Reset gewinnt a (loserOf6 = WB-Finalist)
  return (m.a.seed ?? 9) <= (m.b.seed ?? 9) ? "a" : "b";
});
const resetMatch = dko4.matches.find(m => KO.resetSourceOf({ aRef: m.a, bRef: m.b }) != null);
console.log("Reset-Partie P" + resetMatch.nr + " Status:", resetRun.matches.get(resetMatch.nr).status, "(erwartet: done)");
console.log("Platzierung:", KO.placements(resetRun).map(p => `R${p.place}:S${p.player.seed}`).join(" "));

console.log("\n=== DKO-004 ohne Reset (WB-Sieger gewinnt 1. Finale) ===");
const noReset = simulate(dko4, 4, m => {
  const isGF = m.aRef && m.aRef.winnerOf === 3 && m.bRef && m.bRef.winnerOf === 5;
  if (isGF) return "a"; // WB-Sieger gewinnt → kein Reset
  return (m.a.seed ?? 9) <= (m.b.seed ?? 9) ? "a" : "b";
});
console.log("Reset-Partie P" + resetMatch.nr + " Status:", noReset.matches.get(resetMatch.nr).status, "(erwartet: skipped)");
console.log("Platzierung:", KO.placements(noReset).map(p => `R${p.place}:S${p.player.seed}`).join(" "));

console.log(`\nGesamt-Validierungsfehler: ${totalErr}`);
