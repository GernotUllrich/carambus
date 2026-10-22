// Node-Test: Paarungen späterer KO-Runden ändern (Eingriff 2, Plan 28-03).
//   node schemes/plan/ko-pairings.test.mjs
// Overlay neben dem Plan: getauscht werden Plan-Verweise derselben Art (Sieger/Verlierer) innerhalb einer Runde.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const S = "/* >>> PLAN-ENGINE >>> */", E = "/* <<< PLAN-ENGINE <<< */";
const si = html.indexOf(S), ei = html.indexOf(E, si + S.length);
if (si < 0 || ei < 0) { console.error("PLAN-ENGINE-Block in index.html nicht gefunden"); process.exit(1); }
const { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished, runGroupStandings, resolveSlot,
        koSwapClasses, applyPairingOverrides, swapPairingSlots } =
  new Function(html.slice(si + S.length, ei) + "\n;return { parsePlan, biathlonGpPlan, biathlonVariant, createRun, runReadyGames, recordResult, finalRanking, runFinished, runGroupStandings, resolveSlot, koSwapClasses, applyPairingOverrides, swapPairingSlots };")();

let failures = 0;
const assert = (c, m) => { if (!c) { console.error("  ✗ " + m); failures++; } };
const eq = (a, b, m) => assert(JSON.stringify(a) === JSON.stringify(b), `${m} (ist ${JSON.stringify(a)}, soll ${JSON.stringify(b)})`);

const T06 = '{"GK":11,"g1":{"pl":3,"rs":"eae","sq":{"r1":{"t1":"2-3"},"r2":{"t1":"1-3"},"r3":{"t1":"1-2"}}},"g2":{"pl":3,"rs":"eae","sq":{"r1":{"t2":"2-3"},"r2":{"t2":"1-3"},"r3":{"t2":"1-2"}}},"hf1":{"r4":{"t-rand-1-2":["g1.rk1","g2.rk2"]}},"hf2":{"r4":{"t-rand-1-2":["g2.rk1","g1.rk2"]}},"p<5-6>":{"r4":{"t3":["g1.rk3","g2.rk3"]}},"fin":{"r5":{"t-admin-1-3":["hf1.rk1","hf2.rk1"]}},"p<3-4>":{"r5":{"t-admin-1-3":["hf1.rk2","hf2.rk2"]}},"RK":["fin.rk1","fin.rk2","p<3-4>.rk1","p<3-4>.rk2","p<5-6>.rk1","p<5-6>.rk2"]}';
const classKeys = plan => koSwapClasses(plan).map(c => `${c.kind}:${c.slots.map(s => s.key + "." + s.side).join(",")}`);

// Durchlauf wie biathlon-gp.test: der kleinere Setzplatz gewinnt; stop(run) beendet vorzeitig.
function simulate(n, ov, stop) {
  const { plan, dropped } = applyPairingOverrides(parsePlan(biathlonGpPlan(n)), ov);
  const run = createRun(plan, Array.from({ length: n }, (_, i) => ({ seed: i + 1, pid: "s" + (i + 1) })));
  run.dropped = dropped;
  for (let guard = 0; !runFinished(run) && guard < 500; guard++) {
    if (stop?.(run)) break;
    const ready = runReadyGames(run); if (!ready.length) { assert(false, `${n}: Durchlauf hängt`); break; }
    for (const g of ready) {
      const goal = biathlonVariant(plan, g).balls_goal, aWins = g.playerA.seed < g.playerB.seed;
      recordResult(run, g.key, { a: { balls: aWins ? goal : goal / 2, innings: 10 }, b: { balls: aWins ? goal / 2 : goal, innings: 10 } });
    }
  }
  return run;
}
const pair = (run, k) => [run.results[k].a.seed, run.results[k].b.seed];
const slots = (run, k) => { const g = run.plan.games.find(x => x.key === k); return [resolveSlot(run, g.a)?.seed ?? null, resolveSlot(run, g.b)?.seed ?? null]; };
const finalSeeds = run => finalRanking(run).map(r => r.player?.seed ?? null);
const SWAP = { hf1: { b: "qf3.rk1" }, hf2: { a: "qf2.rk1" } };

console.log("Tauschklassen — nur, wo es Alternativen gibt:");
{
  const gp16 = parsePlan(biathlonGpPlan(16));
  eq(classKeys(gp16), ["rk1:hf1.a,hf1.b,hf2.a,hf2.b"], "GP 16: nur das Halbfinale (VF aus ks.rk = koOrder, Finale allein)");
  const gp28 = parsePlan(biathlonGpPlan(28));
  eq(classKeys(gp28).length, 2, "GP 28: Viertelfinale (aus AF-Siegern) und Halbfinale");
  assert(!koSwapClasses(gp28).some(c => c.slots.some(s => s.key === "fin" || /^8f/.test(s.key) || /^quali/.test(s.key))),
    "GP 28: kein Finale, kein Achtelfinale (ks.rk), keine Quali (Gruppenplätze)");
  eq(classKeys(parsePlan(T06)), [], "T06: Runde 5 (Finale + Platz 3) und Halbfinale aus Gruppenplätzen bieten nichts an");
}

console.log("\nTausch im Halbfinale (GP 16):");
{
  const plain = simulate(16), run = simulate(16, SWAP);
  eq(run.dropped, [], "Override gültig");
  eq([pair(plain, "hf1"), pair(plain, "hf2")], [[1, 4], [3, 2]], "Plan: HF 1–4, 3–2");
  eq([pair(run, "hf1"), pair(run, "hf2")], [[1, 3], [4, 2]], "getauscht: HF 1–3, 4–2");
  eq(pair(run, "fin"), [1, 2], "Finale löst weiter hf1.rk1/hf2.rk1 auf");
  eq(["qf1", "qf2", "qf3", "qf4"].map(k => pair(run, k)), ["qf1", "qf2", "qf3", "qf4"].map(k => pair(plain, k)), "VF-Ergebnisse unverändert");
  eq([1, 2, 3, 4].map(n => runGroupStandings(run, n).map(s => s.player.seed)), [1, 2, 3, 4].map(n => runGroupStandings(plain, n).map(s => s.player.seed)), "Gruppentabellen unverändert");
  const fs = finalSeeds(run); eq(new Set(fs).size, 16, "Endstand vollständig, ohne Dubletten"); assert(!fs.includes(null), "Endstand ohne Lücke");
  const hf = [...pair(run, "hf1"), ...pair(run, "hf2")].sort(); eq(hf, [1, 2, 3, 4], "Permutation: jeder HF-Spieler genau einmal");
  const g = run.plan.games.find(x => x.key === "hf1");
  eq([g.overridden, g.planB], [["b"], "qf2.rk1"], "Partie trägt Planverweis und geänderte Seite");
}

console.log("\nTausch vor Feststehen der Sieger:");
{
  const run = simulate(16, SWAP, r => r.plan.games.filter(g => g.kind === "group").every(g => r.results[g.key])); // stoppt vor den VF
  eq(slots(run, "hf1"), [null, null], "HF-Plätze leer, solange die VF laufen");
  const done = simulate(16, SWAP, r => ["qf1", "qf2", "qf3", "qf4"].every(k => r.results[k]));
  eq([slots(done, "hf1"), slots(done, "hf2")], [[1, 3], [4, 2]], "nach den VF-Ergebnissen die getauschten Namen");
}

console.log("\nUngültige Overrides werden verworfen, nicht still angewandt:");
{
  const plan = parsePlan(biathlonGpPlan(16));
  const miss = applyPairingOverrides(plan, { hf9: { a: "qf1.rk1" } });
  eq(miss.dropped, ["hf9"], "fehlender Key → dropped");
  const foreign = applyPairingOverrides(plan, { hf1: { a: "qf1.rk2" } });
  eq(foreign.dropped, ["hf1"], "klassenfremder Verweis (Verlierer an Siegerplatz) → dropped");
  eq(foreign.plan.games.find(g => g.key === "hf1").a, "qf1.rk1", "Paarung = Plan");
  const half = applyPairingOverrides(plan, { hf1: { b: "qf3.rk1" } });
  eq(half.dropped, ["hf1"], "nur ein Platz gesetzt (qf3-Sieger doppelt) → dropped");
  const fin = applyPairingOverrides(parsePlan(T06), { fin: { a: "hf1.rk2" } });
  eq(fin.dropped, ["fin"], "T06: Finale bietet nichts an → dropped");
  eq(applyPairingOverrides(plan, {}).plan, plan, "leeres Overlay → Plan unverändert (dasselbe Objekt)");
}

console.log("\nTauschen und Zurücktauschen:");
{
  const plan = parsePlan(biathlonGpPlan(16));
  const once = swapPairingSlots(plan, {}, { key: "hf1", side: "b" }, { key: "hf2", side: "a" });
  eq(once, SWAP, "Tausch erzeugt beide Plätze");
  const applied = applyPairingOverrides(plan, once).plan;
  eq(swapPairingSlots(applied, once, { key: "hf1", side: "b" }, { key: "hf2", side: "a" }), {}, "zurücktauschen → Overlay leer");
  eq(swapPairingSlots(plan, {}, { key: "hf1", side: "a" }, { key: "fin", side: "a" }), null, "klassenübergreifend → null");
  eq(swapPairingSlots(plan, {}, { key: "hf1", side: "a" }, { key: "hf1", side: "a" }), null, "derselbe Platz → null");
  const three = swapPairingSlots(applied, once, { key: "hf1", side: "a" }, { key: "hf1", side: "b" });
  eq(three, { hf1: { b: "qf1.rk1", a: "qf3.rk1" }, hf2: { a: "qf2.rk1" } }, "Folgetausch auf geändertem Stand");
  eq(applyPairingOverrides(plan, three).dropped, [], "Folgetausch bleibt eine gültige Vertauschung");
}

console.log("\nPersistenz (Sicherung als JSON):");
{
  const ov = JSON.parse(JSON.stringify(SWAP));
  const a = simulate(16, SWAP), b = simulate(16, ov);
  eq(["hf1", "hf2", "fin"].map(k => pair(b, k)), ["hf1", "hf2", "fin"].map(k => pair(a, k)), "identische Paarungen nach JSON-Rundweg");
}

console.log(failures ? `\n${failures} Fehler` : "\nAlle Prüfungen bestanden.");
process.exit(failures ? 1 : 0);
