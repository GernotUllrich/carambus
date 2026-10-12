// Node-Test der Doppel-KO-Engine: node schemes/doppelko/bracket.test.mjs
// Die Engine lebt INLINE in index.html (self-contained, file://-tauglich). Dieser
// Test extrahiert den Block zwischen den BRACKET-ENGINE-Markern und evaluiert ihn —
// so gibt es nur EINE Quelle der Engine (die HTML) und sie bleibt trotzdem testbar.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const START = "/* >>> BRACKET-ENGINE >>> */";
const END = "/* <<< BRACKET-ENGINE <<< */";
const s = html.indexOf(START), e = html.indexOf(END, s + START.length);
if (s === -1 || e === -1) { console.error("BRACKET-ENGINE-Block in index.html nicht gefunden"); process.exit(1); }
const code = html.slice(s + START.length, e);

const factory = new Function(code + "\n;return { BYE, isBye, isPlayer, bracketSize, standardSeedOrder, generateBracket, resolveMatch, winnerFromResult, readyMatches, runningMatches, placements, progress };");
const B = factory();

let failures = 0;
function assert(cond, msg) { if (!cond) { console.error("  ✗ " + msg); failures++; } }
function mkPlayers(n) { return Array.from({ length: n }, (_, i) => ({ id: i + 1, lastname: "P" + (i + 1), seed: i + 1 })); }

function playOut(bracket, pickWinner) {
  let guard = 0;
  while (!bracket.champion) {
    const ready = B.readyMatches(bracket);
    if (ready.length === 0) { console.error("  ✗ DEADLOCK"); failures++; return; }
    for (const m of ready) {
      const slot = pickWinner(m);
      B.resolveMatch(bracket, m.id, slot, {
        a: { balls: slot === "a" ? 30 : 10, innings: 20 },
        b: { balls: slot === "b" ? 30 : 10, innings: 20 }
      });
    }
    if (++guard > 1000) { console.error("  ✗ Endlosschleife"); failures++; return; }
  }
}
const bySeed = (m) => (m.a.seed < m.b.seed ? "a" : "b");

console.log("bracketSize/seedOrder:");
assert(B.bracketSize(8) === 8, "bracketSize(8)=8");
assert(B.bracketSize(9) === 16, "bracketSize(9)=16");
assert(B.bracketSize(17) === 32, "bracketSize(17)=32");
assert(JSON.stringify(B.standardSeedOrder(8)) === JSON.stringify([1, 8, 4, 5, 2, 7, 3, 6]), "seedOrder(8) korrekt");

for (const P of [8, 16, 32]) {
  console.log(`\nVolles Bracket P=${P}:`);
  const b = B.generateBracket(mkPlayers(P));
  assert(b.size === P, "size=" + P);
  playOut(b, bySeed);
  assert(b.champion && b.champion.seed === 1, `Champion ist Setzplatz 1 (war #${b.champion?.seed})`);
  const pr = B.progress(b);
  assert(pr.finished && pr.done === pr.total, `alle Spiele done (${pr.done}/${pr.total})`);
  console.log(`  Spiele gesamt: ${pr.total}, Champion #${b.champion.seed}`);
}

console.log("\nBracket-Reset (LB-Champion gewinnt GF.1):");
{
  const b = B.generateBracket(mkPlayers(8));
  let guard = 0;
  while (true) {
    const ready = B.readyMatches(b);
    const gf1 = ready.find(m => m.id === "GF.1");
    if (gf1 && ready.length === 1) break;
    if (ready.length === 0 || ++guard > 1000) break;
    for (const m of ready) {
      if (m.id === "GF.1") continue;
      B.resolveMatch(b, m.id, bySeed(m), { a: { balls: bySeed(m) === "a" ? 30 : 9, innings: 20 }, b: { balls: bySeed(m) === "b" ? 30 : 9, innings: 20 } });
    }
  }
  assert(b.matches.get("GF.1").status === "ready", "GF.1 ready");
  B.resolveMatch(b, "GF.1", "b", { a: { balls: 10, innings: 20 }, b: { balls: 30, innings: 20 } });
  const gf2 = b.matches.get("GF.2");
  assert(gf2 && gf2.status !== "skipped", "GF.2 aktiviert (Reset)");
  assert(!b.champion, "noch kein Champion vor GF.2");
  B.resolveMatch(b, "GF.2", "a", { a: { balls: 30, innings: 20 }, b: { balls: 12, innings: 20 } });
  assert(!!b.champion, "Champion nach GF.2");
}

console.log("\nKein Reset (WB-Champion gewinnt GF.1):");
{
  const b = B.generateBracket(mkPlayers(8));
  let guard = 0;
  while (true) {
    const ready = B.readyMatches(b);
    const gf1 = ready.find(m => m.id === "GF.1");
    if (gf1 && ready.length === 1) break;
    if (ready.length === 0 || ++guard > 1000) break;
    for (const m of ready) {
      if (m.id === "GF.1") continue;
      B.resolveMatch(b, m.id, bySeed(m), { a: { balls: bySeed(m) === "a" ? 30 : 9, innings: 20 }, b: { balls: bySeed(m) === "b" ? 30 : 9, innings: 20 } });
    }
  }
  B.resolveMatch(b, "GF.1", "a", { a: { balls: 30, innings: 20 }, b: { balls: 12, innings: 20 } });
  assert(!!b.champion, "Champion direkt nach GF.1");
  assert(b.matches.get("GF.2").status === "skipped", "GF.2 übersprungen");
}

for (const N of [11, 12, 13, 20, 24, 31]) {
  console.log(`\nFreilose N=${N}:`);
  const b = B.generateBracket(mkPlayers(N));
  assert(b.size === B.bracketSize(N), `size=${B.bracketSize(N)}`);
  playOut(b, bySeed);
  assert(b.champion && b.champion.seed === 1, `Champion Setzplatz 1 (war #${b.champion?.seed})`);
  const pr = B.progress(b);
  assert(pr.finished && pr.done === pr.total, `alle echten Spiele done (${pr.done}/${pr.total})`);
  console.log(`  echte Spiele: ${pr.total}, Champion #${b.champion.seed}`);
}

console.log("\n" + (failures === 0 ? "✅ ALLE TESTS GRÜN" : `❌ ${failures} FEHLER`));
process.exit(failures === 0 ? 0 : 1);
