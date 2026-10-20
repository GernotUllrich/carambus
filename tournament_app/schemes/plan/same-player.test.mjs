// Node-Test: Spieler-Identität bei der Ergebnis-Zuordnung (samePlayer).
//   node schemes/plan/same-player.test.mjs
// Die DBU-Nummer entscheidet, die cc_id nur ohne dbu_nr, danach der Name.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const html = readFileSync(join(here, "index.html"), "utf8");
const si = html.indexOf("const normName = "), ei = html.indexOf("\nfunction sideFromParticipant", si);
if (si < 0 || ei < 0) { console.error("normName/samePlayer in index.html nicht gefunden"); process.exit(1); }
const samePlayer = new Function(html.slice(si, ei) + "\n;return samePlayer;")();

let failures = 0;
const check = (got, want, m) => { if (got !== want) { console.error(`  ✗ ${m} (ist ${got}, soll ${want})`); failures++; } else console.log(`  ✓ ${m}`); };
const P = (o) => ({ firstname: "Max", lastname: "Muster", cc_id: null, dbu_nr: null, ...o });

check(samePlayer(P({ dbu_nr: 4711, cc_id: 10050 }), P({ dbu_nr: "4711", cc_id: 20333 })), true, "dbu_nr gleich, cc_id verschieden → derselbe Spieler");
check(samePlayer(P({ dbu_nr: 4711, cc_id: 10050 }), P({ dbu_nr: 4712, cc_id: 10050 })), false, "dbu_nr verschieden, cc_id gleich → nicht derselbe Spieler");
check(samePlayer(P({ cc_id: 10050 }), P({ dbu_nr: 4711, cc_id: 10050 })), true, "eine dbu_nr fehlt → cc_id entscheidet (gleich)");
check(samePlayer(P({ cc_id: 10050 }), P({ dbu_nr: 4711, cc_id: 10051 })), false, "eine dbu_nr fehlt → cc_id entscheidet (verschieden)");
check(samePlayer(P({}), P({ firstname: " max ", lastname: "MUSTER" })), true, "ohne IDs → Name (normalisiert)");
check(samePlayer(P({}), P({ lastname: "Anders" })), false, "ohne IDs, anderer Name");
check(samePlayer(null, P({})), false, "fehlender Spieler");

if (failures) { console.error(`\n${failures} Fehler`); process.exit(1); }
console.log("\nalle grün");
