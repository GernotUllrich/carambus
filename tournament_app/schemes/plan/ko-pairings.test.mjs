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
// EK12 aus der Carambus-Planliste (Plan 28-05): Viertelfinale direkt aus Gruppenplätzen, vf2.b mit Leerzeichen ("g1.rk3 ")
const EK12 = '{"GK":37,"g1":{"pl":6,"rs":"eae","sq":{"r1":{"t1":"2-5","t2":"3-4"},"r2":{"t1":"1-6","t2":"2-4"},"r3":{"t1":"3-6","t2":"1-5"},"r4":{"t1":"1-4","t2":"2-3"},"r5":{"t1":"5-6","t2":"1-3"},"r6":{"t1":"4-5","t2":"2-6"},"r7":{"t1":"4-6","t2":"3-5"},"r8":{"t1":"1-2"}}},"g2":{"pl":6,"rs":"eae","sq":{"r1":{"t3":"2-5","t4":"3-4"},"r2":{"t3":"1-6","t4":"2-4"},"r3":{"t3":"3-6","t4":"1-5"},"r4":{"t3":"1-4","t4":"2-3"},"r5":{"t3":"5-6","t4":"1-3"},"r6":{"t3":"4-5","t4":"2-6"},"r7":{"t3":"4-6","t4":"3-5"},"r8":{"t3":"1-2"}}},"vf1":{"r9":{"t1":["g1.rk1","g2.rk4"]}},"vf2":{"r9":{"t2":["g2.rk2","g1.rk3 "]}},"vf3":{"r9":{"t3":["g1.rk2","g2.rk3"]}},"vf4":{"r9":{"t4":["g2.rk1","g1.rk4"]}},"hf1":{"r10":{"t1":["vf1.rk1","vf2.rk1"]}},"hf2":{"r10":{"t3":["vf3.rk1","vf4.rk1"]}},"fin":{"r11":{"t-admin-1-4":["hf1.rk1","hf2.rk1"]}},"RK":["fin.rk1","fin.rk2","hf1.rk2","hf2.rk2","vf1.rk2","vf2.rk2","vf3.rk2","vf4.rk2","g1.rk5","g2.rk5","g1.rk6","g2.rk6"]}';
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
  // Seit 28-05: das Halbfinale aus Gruppenplätzen ist tauschbar (Erste unter sich, Zweite unter sich); Runde 5 (Finale +
  // Platz 3) und Platz 5–6 (g1.rk3–g2.rk3, Rang 3 nur in einer Partie) weiter nicht.
  eq(classKeys(parsePlan(T06)), ["g-rk1:hf1.a,hf2.a", "g-rk2:hf1.b,hf2.b"], "T06: Halbfinale aus Gruppenplätzen tauschbar, R5 und Platz 5–6 nicht");
  eq(classKeys(parsePlan(EK12)), ["g-rk1:vf1.a,vf4.a", "g-rk4:vf1.b,vf4.b", "g-rk2:vf2.a,vf3.a", "g-rk3:vf2.b,vf3.b", "rk1:hf1.a,hf1.b,hf2.a,hf2.b"],
    "EK12: Viertelfinale je Rang tauschbar (auch der Verweis mit Leerzeichen), Halbfinale wie bisher");
}

console.log("\nTausch unter Gruppenplätzen (T06-Halbfinale, Plan 28-05):");
{
  const plan = parsePlan(T06);
  const players = Array.from({ length: 6 }, (_, i) => ({ seed: i + 1, pid: "s" + (i + 1) }));
  const ov = swapPairingSlots(plan, {}, { key: "hf1", side: "b" }, { key: "hf2", side: "b" }); // die beiden Gruppenzweiten
  eq(ov, { hf1: { b: "g1.rk2" }, hf2: { b: "g2.rk2" } }, "Tausch der Zweiten erzeugt beide Plätze");
  const run = createRun(applyPairingOverrides(plan, ov).plan, players);
  const hf = k => run.plan.games.find(g => g.key === k);
  eq([hf("hf1").a, hf("hf1").b, hf("hf2").a, hf("hf2").b], ["g1.rk1", "g1.rk2", "g2.rk1", "g2.rk2"], "hf1 jetzt g1.rk1–g1.rk2 (gleiche Gruppe, erlaubt)");
  eq(resolveSlot(run, hf("hf1").b), null, "vor den Gruppen noch kein Name");
  for (let guard = 0; guard < 50; guard++) {
    const ready = runReadyGames(run).filter(g => g.kind === "group"); if (!ready.length) break;
    for (const g of ready) { const aw = g.playerA.seed < g.playerB.seed; recordResult(run, g.key, { a: { balls: aw ? 30 : 10, innings: 10 }, b: { balls: aw ? 10 : 30, innings: 10 } }); }
  }
  const second = n => runGroupStandings(run, n)[1].player.seed;
  eq([resolveSlot(run, hf("hf1").b).seed, resolveSlot(run, hf("hf2").b).seed], [second(1), second(2)], "nach den Gruppen: hf1 bekommt den Zweiten aus Gruppe 1");
  const fourPlayers = [hf("hf1").a, hf("hf1").b, hf("hf2").a, hf("hf2").b].map(r => resolveSlot(run, r).seed);
  eq(new Set(fourPlayers).size, 4, "jeder Spieler genau einmal im Halbfinale");
  eq(applyPairingOverrides(plan, { hf1: { b: "g1.rk1" } }).dropped, ["hf1"], "Erster an einen Zweiten-Platz → verworfen (Rang fremd)");
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

console.log("\nKeine doppelten Funktionsnamen in index.html:");
{
  // Phase 28-04: eine zweite `function koRoundName` weiter unten überschrieb still die aus dem Engine-Block —
  // die Engine-Tests sahen nur ihren Block und blieben grün, die Oberfläche brach. Funktionsdeklarationen
  // sind global; die spätere gewinnt ohne Meldung.
  const names = [...html.matchAll(/^\s*(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(/gm)].map(m => m[1]);
  const dup = [...new Set(names.filter((n, i) => names.indexOf(n) !== i))];
  eq(dup, [], "jede Funktion genau einmal deklariert");
}

console.log(failures ? `\n${failures} Fehler` : "\nAlle Prüfungen bestanden.");
process.exit(failures ? 1 : 0);
