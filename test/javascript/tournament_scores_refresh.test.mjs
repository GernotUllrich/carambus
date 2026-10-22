// Node-Test: Wann die Turnieruebersicht (sb_state=tournament_scores) neu laedt.
//   node test/javascript/tournament_scores_refresh.test.mjs
// Das Modul ist ESM ohne "type": "module" im package.json — deshalb als Text geladen.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
const here = dirname(fileURLToPath(import.meta.url));
const src = readFileSync(join(here, "../../app/javascript/channels/tournament_scores_refresh.js"), "utf8").replace(/^export /gm, "");
const { teaserChangesTournamentScores: changes } = new Function(src + "\n;return { teaserChangesTournamentScores };")();

let failures = 0;
const eq = (a, b, m) => { if (a === b) console.log("  ✓ " + m); else { console.error(`  ✗ ${m} (ist ${a}, soll ${b})`); failures++; } };
const page = { tournamentMonitorIds: new Set(["7"]), activeIds: new Set(["11", "12"]) };
const op = (id, tm, game) => ({ selector: `#teaser_${id}`, html: `<div class="teaser" data-tournament-monitor-id="${tm}" data-has-game="${game}">…</div>` });

console.log("Tisch noch nicht angezeigt:");
eq(changes(op(13, "7", true), page), true, "dieses Turnier, Spiel laeuft → neu laden (erstmals belegt)");
eq(changes(op(13, "7", false), page), false, "dieses Turnier, kein Spiel → nichts (gebunden, frei)");
eq(changes(op(21, "", true), page), false, "Training (kein TournamentMonitor) → nichts");
eq(changes(op(21, "9", true), page), false, "fremdes Turnier → nichts");

console.log("\nTisch angezeigt:");
eq(changes(op(11, "7", true), page), false, "Spielstand-Update → nichts (normaler Teaser)");
eq(changes(op(11, "7", false), page), true, "Spiel weg → neu laden (frei geworden)");
eq(changes(op(11, "", false), page), true, "Turnier weg → neu laden (geloest)");
eq(changes(op(11, "9", true), page), true, "an anderes Turnier gebunden → neu laden");

console.log("\nKeine Teaser-Operation:");
eq(changes({ selector: "#table_scores", html: "<div></div>" }, page), false, "#table_scores → nichts");
eq(changes({ selector: "#teaser_13" }, page), false, "ohne html → nichts");
eq(changes(op("12x", "7", true), page), false, "fremder Selektor → nichts");

console.log(failures ? `\n❌ ${failures} Fehler` : "\n✅ ALLE TESTS GRÜN");
process.exit(failures ? 1 : 0);
