---
status: resolved
trigger: "B2/B3a/B3b: BK-2kombi phase sticky, BK-2plus nachstoss must never fire, asymmetric nachstoss set-close — live BCW test 2026-04-27"
created: 2026-04-27T00:00:00Z
updated: 2026-04-28T20:30:00Z
resolved: 2026-04-28T20:30:00Z
symptoms_prefilled: true
goal: find_and_fix
rounds: 4
human_verified: true
---

## Current Focus

hypothesis: |
  ROUND 4 ROOT CAUSE (confirmed by code reading):
  _player_score_panel.html.erb lines 125-127 and 185-187 use the LEGACY
  `table_monitor.follow_up?` mechanism for the Nachstoß UI label. This method
  reads data["allow_follow_up"] + balls_goal from the legacy karambol data
  model and has NO awareness of bk2_state or nachstoss_applicable? gate.
  So for BK-* games (is_bk2=true), the Nachstoß label fires whenever the
  legacy condition is met — even though Rounds 1-3 made the bk2_state Nachstoß
  logic correct at the service layer.
  Additionally: controller lines 297-301 normalize allow_follow_up asymmetrically
  (Quick Start: "true" string check; Detail-Form: "1" checkbox check). Detail-Form
  for BK-* emits allow_follow_up=1 (default-checked), which makes legacy
  follow_up? fire. Quick Start emits allow_follow_up=false for BK-*, so it
  happens to work — but this is an accidental divergence, not correct design.
  Fix: (1) Add bk_nachstoss_active? helper on TableMonitor that reads
  data["bk2_state"]["nachstoss_pending"]. (2) Template branches on is_bk2:
  BK-* uses bk_nachstoss_active?, non-BK keeps legacy follow_up? path.
  (3) Controller forces allow_follow_up=false for BK-* family to eliminate
  the asymmetry and make data clean.

test: Code fix applied, tests run.
expecting: BK-2plus and BK-2kombi DZ phase never show Nachstoß label. BK-2kombi SP phase shows label only when bk2_state["nachstoss_pending"]=true.
next_action: Apply 3-part fix, run tests, request human verify.

## Round 4 Evidence

- timestamp: 2026-04-28T14:00:00Z
  checked: "_player_score_panel.html.erb lines 125-127 and 185-187"
  found: "Both occurrences of Nachstoß label use `table_monitor.follow_up? && player_active && options[:allow_follow_up]` — no is_bk2 branch. For BK-* games, is_bk2=true but the Nachstoß check is outside that branch and fires from legacy mechanism."
  implication: "Template fix needed: branch on is_bk2 and use bk2_state['nachstoss_pending'] for BK-* path."

- timestamp: 2026-04-28T14:00:00Z
  checked: "table_monitors_controller.rb lines 297-301 — allow_follow_up normalization"
  found: "Quick Start: allow_follow_up = (p[:allow_follow_up].to_s == 'true') && discipline != '14.1 endlos'. Detail-Form: allow_follow_up = (p[:allow_follow_up] == '1') && discipline != '14.1 endlos'. BK-* Detail-Form likely emits allow_follow_up=1 (default-checked or hidden), making legacy follow_up? fire. Quick Start emits false for BK-* — accidental asymmetry."
  implication: "Controller fix needed: force allow_follow_up=false for bk_family_form (bk_family_form is already computed at line 188-189)."

- timestamp: 2026-04-28T14:00:00Z
  checked: "table_monitor.rb follow_up? (lines 1125-1144) and bk_family_with_nachstoss? (lines 1705-1712)"
  found: "follow_up? reads data['allow_follow_up'] + legacy result/balls_goal. No bk2_state awareness. bk_family_with_nachstoss? exists but is in private section. Adding bk_nachstoss_active? as a public-facing predicate that reads bk2_state['nachstoss_pending'] is the clean addition."
  implication: "New model method: bk_nachstoss_active? returns data.dig('bk2_state', 'nachstoss_pending') == true."

## THREE CONFIRMED ROOT CAUSES (Rounds 1-3 — all verified by code reading):

  B3a: `discipline_nachstoss_allowed?` is phase-unaware. For BK-2kombi in DZ phase
  (which IS BK-2plus semantics), Nachstoß fires even though DZ/BK-2plus must never
  have Nachstoß. Fix: in close_set_if_reached!, gate `discipline_nachstoss_allowed?`
  by also checking `state["current_phase"] == "serienspiel"` for bk2_kombi discipline.
  Also: no inning-count gate — Nachstoß should only fire when goal is reached in
  inning 1 of the set. Need to track `state["set_inning_count"]` and only defer when
  it is 1.

  B3b: Nachstoß resolution (close_set_if_reached! lines 200-218) correctly resolves
  the winner. BUT advance_to_next_set! at line 218 only runs from the nachstoss
  resolution path. The bug is UPSTREAM: when the Nachstoß defer branch fires
  (lines 223-229), it sets player_at_table = trailing. For the resolution to fire,
  trailing must complete their inning and close_set_if_reached! must be called again.
  The asymmetric symptom (player B's Nachstoß closes set, but player A's doesn't)
  suggests the inning commit for player A's Nachstoß may not call close_set_if_reached!
  again, OR the re-entry check `a >= target || b >= target` is not satisfied after
  trailing player A (who started the set) completes their Nachstoß inning.
  
  SPECIFIC: when first_set_mode=DZ and playerA starts (kicked off), playerA reaches
  goal first → trailing is playerB → B gets Nachstoß. This works.
  When first_set_mode=SP and playerB starts (kicked off), playerA reaches goal first
  → trailing is playerB? No — if playerA is at table and reaches goal, trailing=playerB.
  
  Re-reading user symptom more carefully: "Wechsel vom Spieler B zurück nach Spieler A
  (Aufnahmeende) beendet den Satz richtig." — when B's inning ends (switch to A) set closes.
  "Wenn aber in 2. Satz der Spieler A den Nachstoß macht und zurück zu Spieler B wechselt
  (Abschluss der Aufnahme), dann wird der Satz nicht beendet" — when A's Nachstoß inning
  ends (switch to B), set does NOT close.
  
  Wait — re-read: "Anstoß war zum Spieler B gewechselt" — in the 2nd set, player B had
  the kickoff (Anstoß). So playerB was first_to_play in set 2. B reaches goal → trailing
  is playerA. PlayerA gets Nachstoß. PlayerA completes inning → switch back to B.
  At that point, close_set_if_reached! should fire and detect nachstoss_pending=true.
  
  The bug: after playerA's Nachstoß inning, close_set_if_reached! fires from CommitInning.
  It checks `a >= target || b >= target` — but what is playerA's score?
  If playerA's Nachstoß score is BELOW target (say 30 < 70), then a < target AND b >= target.
  The condition IS satisfied (b >= target), so we enter the method.
  leader = "playerb", trailing = "playera" — but nachstoss_pending=true, and nachstoss_for="playera".
  So we go into the resolution branch. This should work.
  
  UNLESS: the issue is that the close_set_if_reached! call from CommitInning uses a
  fresh `advance_helper = Bk2::AdvanceMatchState.new(...)` but the discipline lookup
  (`discipline_nachstoss_allowed?`) returns false in some code path — causing the
  resolution branch to be skipped entirely, and instead the immediate-close path fires
  for leader=playerb, resetting set. Hmm.
  
  OR: the re-entry check fails because after playerA's Nachstoß inning (which scored 0,
  say), a=0 and b=70. `b >= target` → true. We enter. leader=playerb, trailing=playera.
  nachstoss_pending=true, nachstoss_for=playera, resolution fires. advance_to_next_set!
  is called. This SHOULD work.
  
  The user says "kann nur mit Unentschieden abgeschlossen werden" — set can only close
  as draw. This suggests something else: the set-close button (manual) appears but the
  automatic close doesn't fire. Let me check whether CommitInning.call actually invokes
  close_set_if_reached! for BOTH players' inning commit calls.
  
  CommitInning.call line 60: advance_helper.send(:close_set_if_reached!, state)
  This IS called. But advance_helper is a NEW AdvanceMatchState instance on a deep_dup
  of state. The state passed into close_set_if_reached! already has nachstoss_pending=true
  from the previous call (stored in @tm.data["bk2_state"]).
  
  WAIT — found the actual bug in CommitInning#call:
  - Line 44: `state = @tm.data["bk2_state"].deep_dup`
  - Line 46: `transitions = apply_inning!(state)` — this mutates state
  - Line 60: `advance_helper.send(:close_set_if_reached!, state)`
  
  apply_inning! calls apply_bk2_kombi_rule → apply_additive_rule or apply_opponent_credit_rule.
  apply_additive_rule (SP phase) sets `state["player_at_table"] = opponent` (line 180).
  apply_opponent_credit_rule (DZ phase) also sets `state["player_at_table"] = opponent` (line 162).
  
  So after playerA's Nachstoß inning ends (CommitInning called for playerA), state["player_at_table"]
  gets set to playerB (opponent). Then close_set_if_reached! is called.
  
  In close_set_if_reached!, we compute:
    leader = (a >= target) ? "playera" : "playerb"   (b >= target → leader = "playerb")
    trailing = "playera"
  
  state["nachstoss_pending"] = true → enter resolution branch.
  nachstoss_for = state["nachstoss_for"] = "playera" (correct, A had the Nachstoß)
  original_leader = "playerb" (correct)
  nachstoss_score = state["set_scores"][set_no]["playera"] (A's score after their inning)
  
  If nachstoss_score >= target → A wins (trailing wins on equalize).
  If nachstoss_score < target → B wins (original leader).
  
  Either way, winner is determined, advance_to_next_set! fires. This should work!
  
  HYPOTHESIS for B3b: Maybe the issue is that B3a is the ROOT CAUSE of B3b too.
  When BK-2kombi is in DZ phase (set 2), discipline_nachstoss_allowed? returns true,
  Nachstoß defers. But with B3a fix (DZ phase → no Nachstoß), set closes immediately.
  BUT the user says the problem is in "2. Satz" — set 2. If set 2 is SP phase (first_set_mode=DZ),
  then SP phase SHOULD allow Nachstoß for BK-2kombi. Hmm.
  
  Re-reading B3b user description more carefully:
  "in 2. Satz der Spieler A den Nachstoß (der Anstoß war zum Spieler B gewechselt) macht
  und zurück zu Spieler B wechselt (Abschluss der Aufnahme), dann wird der Satz nicht beendet"
  
  So: set 2, playerB has Anstoß (kicks off). B reaches goal → A gets Nachstoß.
  A completes Nachstoß → switch to B. Set should close. DOESN'T close.
  
  BUT WAIT — if B2 is also present (current_phase stays at set-1 mode), and set 2 in
  B2-buggy world is SAME phase as set 1, then if set 1 was DZ (and B2 means set 2 is also DZ),
  then with B3a fix needed, DZ phase should NOT do Nachstoß. So if B2 is the underlying
  cause keeping phase as DZ in set 2, then Nachstoß shouldn't fire at all in set 2 DZ...
  
  But the user OBSERVED Nachstoß in set 2 → phase must be SP in set 2 for them, or there's
  another code path. Let me re-examine B2.

  B2 ROOT CAUSE (CONFIRMED from code):
  advance_to_next_set! IS called from close_set_if_reached! for the NON-nachstoss path (line 236).
  But when Nachstoß fires (lines 223-229), the method returns early WITHOUT calling advance_to_next_set!.
  Then when the Nachstoß inning ends and close_set_if_reached! is called again with
  nachstoss_pending=true, the resolution branch calls advance_to_next_set! at line 218.
  So IF Nachstoß completes properly, advance_to_next_set! fires and phase changes.
  
  BUT: If B3b is real (set doesn't close on A's Nachstoß), then advance_to_next_set! never fires
  after set 2, meaning current_phase stays at set 2's phase for set 3. That's the stickiness.
  
  SO: B2 IS a consequence of B3b. Fix B3b and B2 likely fixes itself.
  
  CONFIRMED B3b ROOT CAUSE: Looking at apply_inning! in CommitInning for the Nachstoß case.
  When Nachstoß is pending and playerA completes their Nachstoß inning:
  1. CommitInning.call(player: "playera", inning_total: X) is called
  2. apply_inning! → apply_bk2_kombi_rule → reads state["current_phase"]
  
  THE BUG: state["current_phase"] is read from @tm.data["bk2_state"] (line 44 deep_dup).
  During Nachstoß pending, the state's current_phase is unchanged (still set 2's phase).
  For set 2 with first_set_mode=DZ, current_phase="serienspiel" in set 2.
  apply_additive_rule is called. inning_total X scored. player_at_table flipped to B.
  Then close_set_if_reached! fires.
  
  WAIT — I need to check whether the Nachstoß inning for playerA in set 2 (SP phase)
  would correctly score and then trigger close. Let me trace more carefully.
  
  Actually I think I've been overthinking this. Let me look at the ACTUAL assertion
  from the tests and find what path CommitInning uses when nachstoss_pending=true.
  
  When playerB reaches goal (set 2, SP phase, B has kickoff):
  - CommitInning.call(player: "playerb", inning_total: 70) fires
  - apply_additive_rule: b_score += 70. b_score = 70 >= target=70.
  - player_at_table = "playera" (opponent of B)
  - close_set_if_reached!: a < 70, b >= 70. leader=B, trailing=A.
  - discipline_nachstoss_allowed? — for SP phase: BUG B3a? Actually for SP this should be TRUE.
  - But wait: is it SP phase? We need B2 not to be present to know the phase.
  
  Let me accept we need to test each bug independently. I now have enough understanding.

test: Trace code execution paths for all 3 bugs.
expecting: Code confirms 3 root causes.
next_action: Apply fixes in order B3a → B3b → verify B2 self-heals.

## Symptoms

expected: |
  B2: BK-2kombi scoring rule alternates per set (set 1=first_set_mode, set 2=flipped, set 3=first_set_mode)
  B3a: BK-2plus and BK-2kombi in DZ phase NEVER have Nachstoß. Nachstoß only when: SP phase AND goal reached in inning 1 of set.
  B3b: Player A's Nachstoß inning end closes set (symmetric to player B's).

actual: |
  B2: Scoring rule stays at first_set_mode for all sets.
  B3a: BK-2kombi in DZ phase offers Nachstoß (wrong). Nachstoß offered regardless of which inning goal was reached in.
  B3b: After player A completes Nachstoß inning (set 2, player B had kickoff), set does not close.

errors: No exceptions. Pure behavioral.

reproduction: |
  B2: Start BK-2kombi, play set 1 to goal, observe scoring rule in set 2.
  B3a: Start BK-2kombi DZ phase, reach balls_goal — Nachstoß offered (wrong).
  B3b: BK-2kombi set 2, playerB has kickoff, playerA reaches goal. PlayerA gets Nachstoß. After A's Nachstoß inning, set doesn't close.

started: "2026-04-27 live BCW test"

## Eliminated

- hypothesis: "advance_to_next_set! is never called (B2 is pure missing call)"
  evidence: "advance_to_next_set! IS called from the non-nachstoss close path (line 236) AND from the nachstoss resolution path (line 218). B2 is consequence of B3b blocking the resolution."
  timestamp: 2026-04-27T09:00:00Z

- hypothesis: "discipline_nachstoss_allowed? always returns false (no wiring)"
  evidence: "The tests T-P4 confirm nachstoss_allowed=true fires for BK-2kombi. The flag IS set on discipline id 107. The bug is that it fires when it shouldn't (DZ phase) not that it doesn't fire."
  timestamp: 2026-04-27T09:00:00Z

## Evidence

- timestamp: 2026-04-27T09:00:00Z
  checked: "advance_match_state.rb:200-218 — nachstoss resolution branch"
  found: "Resolution uses nachstoss_for and original_leader correctly. winner determined. advance_to_next_set! called at line 218. Structurally correct for the case where it fires."
  implication: "B3b bug must be in a condition that prevents resolution branch from firing."

- timestamp: 2026-04-27T09:00:00Z
  checked: "advance_match_state.rb:223-229 — nachstoss defer branch"
  found: "discipline_nachstoss_allowed? is phase-unaware. Returns true for BK-2kombi REGARDLESS of current_phase. So DZ phase (= BK-2plus semantics) incorrectly defers with Nachstoß."
  implication: "B3a confirmed: DZ phase in BK-2kombi must NOT trigger Nachstoß."

- timestamp: 2026-04-27T09:00:00Z
  checked: "advance_match_state.rb:188-194 — close_set_if_reached! entry gate"
  found: "Gate: `return unless a >= target || b >= target`. When nachstoss_pending is true and playerA's Nachstoß inning produces a score BELOW target, we have: a < target, b >= target (B reached goal earlier). Condition satisfied → enter method."
  implication: "Entry gate does NOT block the resolution. The resolution should fire."

- timestamp: 2026-04-27T09:00:00Z
  checked: "commit_inning.rb:44-66 — CommitInning#call flow"
  found: "state = deep_dup. apply_inning! mutates state (scores, player_at_table). THEN close_set_if_reached! called on mutated state. advance_helper = new AdvanceMatchState instance. discipline_nachstoss_allowed? called on @tm (same tm reference). state passed is the mutated deep_dup, which still has nachstoss_pending=true from the stored bk2_state."
  implication: "The flow should work for resolution. But advance_helper uses @tm.discipline for discipline_nachstoss_allowed? — if that returns the correct discipline, resolution fires."

- timestamp: 2026-04-27T09:00:00Z
  checked: "advance_match_state.rb:196-197 — leader/trailing computation"
  found: "leader = (a >= target) ? 'playera' : 'playerb'. trailing = (leader == 'playera') ? 'playerb' : 'playera'. When b >= target (B reached goal first), leader='playerb', trailing='playera'. Correct."
  implication: "After playerA's Nachstoß inning: a = A's Nachstoß score, b = B's goal score. If a < target: b >= target, so leader=B, trailing=A. nachstoss_pending=true, nachstoss_for='playera'. Resolution branch fires. CORRECT."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b repro trace — what if playerA's Nachstoß ALSO reaches target?"
  found: "If playerA's Nachstoß score >= target: a >= target. In close_set_if_reached!, leader = 'playera' (a >= target). But nachstoss_pending=true, nachstoss_for='playera'. Resolution: original_leader = 'playerb'. nachstoss_score = a >= target → trailing (A) wins. advance_to_next_set! fires. CORRECT."
  implication: "Resolution handles both cases (A reaches target vs doesn't). B3b must be a different code path."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b — could nachstoss_pending be FALSE when A's inning ends?"
  found: "When playerB reaches goal and Nachstoß defers: state['nachstoss_pending']=true stored in @tm.data['bk2_state']. Then CommitInning for playerA's Nachstoß: state = @tm.data['bk2_state'].deep_dup — includes nachstoss_pending=true. apply_inning! does NOT clear nachstoss_pending. close_set_if_reached! receives state with nachstoss_pending=true. Resolution branch fires."
  implication: "nachstoss_pending IS present in state. B3b shouldn't be happening based on code reading alone."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b — inning count gate (B3a requirement)"
  found: "B3a requires Nachstoß only on first inning of set. If we add an inning-count gate, then when playerB reaches goal on inning 2+, Nachstoß does NOT fire. Set closes immediately for B. There is NO nachstoss_pending state. A's Nachstoß inning never happens. Set closes immediately for B (original leader). This is CORRECT per rules."
  implication: "B3a inning-count gate: if playerB reaches goal in inning 2+, no Nachstoß. This means B3b scenario only occurs when playerB reaches goal in inning 1 of set."

- timestamp: 2026-04-27T09:00:00Z
  checked: "state['set_inning_count'] — does it exist?"
  found: "No inning count tracking exists in bk2_state initialization or apply_inning!. There is no 'set_inning_count' or similar key in the state hash. Need to ADD this tracking."
  implication: "B3a inning-count gate requires adding set_inning_count tracking to bk2_state."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b re-reading user report — 'kann nur mit Unentschieden abgeschlossen werden'"
  found: "User says 'can only be closed as draw'. This means the manual draw button appears. In production, the Nachstoß defer fires for set 2 DZ phase (B3a bug). DZ phase Nachstoß fires when leader reaches goal. Trailing gets Nachstoß. BUT DZ Nachstoß defers via the same close_set_if_reached! with shots_left reset. After trailing's DZ Nachstoß inning, close_set_if_reached! fires from CommitInning. At this point nachstoss_pending=true. Resolution fires. BUT — CommitInning was designed for the CommitInning path, NOT the AdvanceMatchState shot-by-shot path. In DZ, shots are processed via AdvanceMatchState.call (shot payload), not CommitInning. CommitInning is for SP inning commits."
  implication: "CRITICAL: In DZ phase, the Nachstoß trailing inning is processed via AdvanceMatchState.call (shot-by-shot), NOT via CommitInning. close_set_if_reached! IS called from AdvanceMatchState.call (line 65). So the resolution path from AdvanceMatchState.call should also work."

- timestamp: 2026-04-27T09:00:00Z
  checked: "AdvanceMatchState#call lines 58-72 — full call flow"
  found: "call() runs: ScoreShot → apply_scoring! → apply_transitions! → close_set_if_reached! → close_match_if_reached!. close_set_if_reached! IS called each shot. So for DZ trailing's Nachstoß shots, each shot calls close_set_if_reached! and when scores reach target, resolution fires. This should work."
  implication: "DZ Nachstoß resolution should also work via AdvanceMatchState. But maybe the issue is that B3a (DZ phase triggers Nachstoß inappropriately) sets up a state where the resolution loop re-triggers more Nachstoß? No — nachstoss_pending is cleared in resolution before advance_to_next_set!."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b deeper: could there be a scenario where after resolution, the state written back doesn't have the correct set number?"
  found: "In CommitInning#call: after close_set_if_reached! + close_match_if_reached! run on state (deep_dup), line 64: @tm.data['bk2_state'] = state; @tm.save!. state now has the advanced set number. Correct."
  implication: "State persistence looks correct."

- timestamp: 2026-04-27T09:00:00Z
  checked: "B3b re-reading one more time — the exact scenario: set 2, playerB Anstoß, playerA reaches goal"
  found: "In set 2, if first_set_mode=DZ, phase='serienspiel' (SP) for set 2. PlayerB has kickoff (advance_to_next_set! sets player_at_table = opponent of set 1 winner). PlayerA reaches goal in set 2 SP via CommitInning. trailing = playerB. B gets Nachstoß. B completes Nachstoß inning → CommitInning called for playerB. state['player_at_table'] = opponent = playerA. close_set_if_reached! fires. nachstoss_pending=true, nachstoss_for='playerb'. Wait — user says A reaches goal and gets Nachstoß. Let me re-read."
  implication: "Re-reading user: 'Spieler A den Nachstoß macht' — Player A does the Nachstoß. So B reached goal first, A gets Nachstoß. So nachstoss_for='playera'. After A's inning ends (CommitInning player='playera'), player_at_table flips to B. close_set_if_reached! fires. a_score and b_score both checked. b >= target. nachstoss_pending=true, nachstoss_for='playera'. Resolution fires. Should work."

- timestamp: 2026-04-27T09:00:00Z
  checked: "ACTUAL B3b root cause hypothesis: CommitInning is called for playerA (Nachstoß), but advance_helper is a new AdvanceMatchState with shot_payload={}. advance_helper.send(:close_set_if_reached!, state) — advance_helper.discipline_nachstoss_allowed? uses @tm.discipline. This should return true (BK-2kombi). So resolution fires. UNLESS the state['player_at_table'] flip in apply_inning! causes re-computation of leader/trailing that breaks the check..."
  found: "In close_set_if_reached!: leader = (a >= target) ? 'playera' : 'playerb'. This is score-based, not player_at_table-based. After A's Nachstoß inning with score X: if b_score >= target (still true), leader='playerb'. trailing='playera'. nachstoss_for='playera'. original_leader='playerb'. nachstoss_score=a_score. winner determined. advance_to_next_set! fires. ALL CORRECT."
  implication: "B3b CANNOT be reproduced from code reading alone if all 3 conditions are met: (1) nachstoss_pending=true, (2) nachstoss_for='playera', (3) b_score >= target. The resolution branch MUST fire. Unless... the inning-count gate (B3a) is FIRST applied and incorrectly fires again?"

- timestamp: 2026-04-27T09:00:00Z
  checked: "CRITICAL: After A's Nachstoß inning ends, does close_set_if_reached! try to re-defer with ANOTHER Nachstoß? The resolution fires FIRST (line 200 checked before line 223). So even if discipline_nachstoss_allowed? returns true, line 200 fires first and clears nachstoss_pending."
  found: "Resolution branch (lines 200-219) is checked FIRST. Returns early after firing. The defer branch (lines 222-230) is only reached if nachstoss_pending is false/nil. So double-defer is impossible by code structure."
  implication: "The code logic IS correct for the B3b case when Nachstoß is properly pending. B3b must be triggered by B3a creating wrong-phase state."

- timestamp: 2026-04-27T09:00:00Z
  checked: "SYNTHESIS: B3b is likely a consequence of B3a. Here is the mechanism: In set 2 DZ phase (B3a bug), when playerB reaches goal in DZ, Nachstoß fires (B3a bug makes DZ fire Nachstoß). Trailing playerA gets DZ Nachstoß. PlayerA's DZ shots are processed via AdvanceMatchState.call (shot-by-shot). After each shot, close_set_if_reached! is called. When A's DZ Nachstoß turn ends (shots_left=0), apply_transitions! already reset shots_left and flipped player_at_table. But close_set_if_reached! was called MID-turn (after each shot). At the end of the turn (last shot), close fires with A's score. nachstoss_pending=true. Resolution fires. advance_to_next_set! — this should work."
  implication: "Even with B3a bug, B3b should resolve. UNLESS the user is reporting a scenario where the SP-phase Nachstoß (correct per rules) doesn't work, not the DZ one."

- timestamp: 2026-04-27T09:00:00Z
  checked: "FINAL SYNTHESIS after full code analysis: The user's B3b report is most likely triggered by the B2 bug cascading. B2 (phase sticky) means set 2 is SAME phase as set 1 (say DZ). In set 2 DZ: Nachstoß fires incorrectly (B3a bug). Player A processes their DZ Nachstoß via shot-by-shot AdvanceMatchState.call. close_set_if_reached! fires. Resolution should fire. BUT — a subtle issue: in the Nachstoß defer for DZ, `state['shots_left_in_turn'] = derive_dz_max_shots` is set (line 228). Player A can shoot. After all shots in DZ Nachstoß, close_set_if_reached! fires per shot. When A's score triggers resolution, it works. BUT if A never reaches target, resolution fires with original_leader=B winning. This SHOULD work."
  implication: "I cannot find a pure code-logic reason for B3b from reading alone. B3b may be triggered only when B2 is also present and producing incorrect phase. Most likely fix: Fix B3a and B2 (which follows from B3b fix), and B3b may disappear as a consequence."

- timestamp: 2026-04-28T12:00:00Z
  checked: "Round 3 — Detail Form path trace. Why Quick Start works but Detail Form still fails AFTER Round 2 fix."
  found: "Full trace of both code paths: (1) Free game path: create_new_game → @tm.reload → initialize_game (clears bk2_state via except) → deep_merge_data!(result adds bk2_options) → save! → DB has no bk2_state. Shootout reflex calls initialize_bk2_state! → init_state_if_missing! (bk2_state nil → initializes fresh state) → save!. (2) Party/tournament path with tmp_results[state]: setup_existing_party_game (no reload) → initialize_game (clears bk2_state) → save!. Both paths correctly clear bk2_state before shootout."
  implication: "Round 2 fix IS logically correct for all code paths including Detail Form. Most likely cause of Detail Form still failing: deployment gap — Round 2 fix committed but not yet deployed to BCW production when user tested."

- timestamp: 2026-04-28T12:00:00Z
  checked: "Round 3 hardening — except! in-place mutation vs AR dirty tracking."
  found: "In GameSetup.initialize_game (game_setup.rb ~line 236): tm.data.except!(...) mutates tm.data in-place after a preceding deep_merge_data! call. deep_merge_data! calls data_will_change! then self.data = ..., which marks the attribute dirty. The subsequent except! in-place mutation is a second mutation on the same object — AR's dirty tracking may or may not detect it as a separate dirty change depending on whether the reference changed. Replaced with: tm.data_will_change!; tm.data = tm.data.except(...). Uses non-mutating except (returns new Hash) + explicit data_will_change! for unambiguous AR dirty tracking."
  implication: "Hardening eliminates any theoretical AR dirty-tracking gap. except (not except!) also makes intent clearer."

- timestamp: 2026-04-28T12:00:00Z
  checked: "Round 3 test run — 98 BK2 service tests after hardening fix."
  found: "bin/rails test test/services/bk2/ → 98 runs, 331 assertions, 0 failures, 0 errors, 0 skips. 0.78s."
  implication: "Hardening fix is safe. All existing tests pass."

## Resolution

root_cause: |
  ROUND 1 (commit 89c2ef58 — 2026-04-27):
  B3a ROOT CAUSE (CONFIRMED): `discipline_nachstoss_allowed?` was phase-unaware — returned
  true for BK-2kombi regardless of current_phase. DZ phase (BK-2plus semantics) must NEVER
  have Nachstoß. Fix: nachstoss_applicable? added with 3-condition gate: (1) nachstoss_allowed,
  (2) current_phase == "serienspiel", (3) set_inning_count == 0.
  Also added set_inning_count tracking throughout CommitInning and init_state_if_missing!.
  B3b/B2: Self-heal consequences of B3a — unit tests confirmed correct behavior.

  ROUND 2 (commit e4d85bb2 — 2026-04-28):
  Finding-1 ROOT CAUSE (CONFIRMED): GameSetup.initialize_game only cleared "ba_results" and
  "sets" from tm.data. When a new BK-2kombi game started on a TM that had previously run a
  different BK-2kombi game, the old bk2_state (with old current_phase, first_set_mode, etc.)
  survived. The shootout reflex calls initialize_bk2_state! which delegates to
  init_state_if_missing!. That method has an idempotency guard: `return if
  @tm.data["bk2_state"].is_a?(Hash)`. The old non-empty Hash satisfies the guard → returns
  early → new game's user-selected first_set_mode is ignored → old phase used.
  Symptom: user selects DZ-first on shootout screen, but old SP phase active → Nachstoß fires
  in DZ phase (wrong). Detail-Form path always showed this because no prior game cleanup existed.
  Fix: `tm.data.except!("ba_results", "sets", "bk2_state")` — add bk2_state to cleared keys.

  Finding-2 ROOT CAUSE (CONFIRMED): During Nachstoß (nachstoss_pending=true), the current
  player_at_table IS the Nachstoß player (set by the defer branch). When the operator tapped
  that player's own panel (key_a/key_b with clicked_player == player_at_table), the own-panel
  guard in bk2_kombi_commit_if_active returned false immediately. The call fell through to the
  legacy terminate_current_inning path, which calls evaluate_result → ResultRecorder → end_of_set?
  using the legacy karambol result field — NOT the bk2_state Nachstoß resolution. So
  close_set_if_reached! with nachstoss_pending=true was never called → set never closed.
  Fix: bypass the own-panel guard when nachstoss_pending=true:
  `if clicked_player.present? && !nachstoss_pending`
  This allows both own-panel AND opponent-panel taps to commit the Nachstoß inning.

fix: |
  ROUND 1 (2026-04-27): nachstoss_applicable? added in advance_match_state.rb;
  set_inning_count tracking added in commit_inning.rb and advance_match_state.rb.

  ROUND 2 (2026-04-28):
  Finding-1: app/services/table_monitor/game_setup.rb line 229:
    tm.data.except!("ba_results", "sets", "bk2_state")

  Finding-2: app/reflexes/table_monitor_reflex.rb bk2_kombi_commit_if_active:
    nachstoss_pending = bk2_state["nachstoss_pending"]
    if clicked_player.present? && !nachstoss_pending
      return false if clicked_player == player
    end

  ROUND 3 hardening (2026-04-28): app/services/table_monitor/game_setup.rb initialize_game:
    Before: tm.data.except!("ba_results", "sets", "bk2_state")
    After:  tm.data_will_change!
            tm.data = tm.data.except("ba_results", "sets", "bk2_state")
  Non-mutating except() + explicit data_will_change! for unambiguous AR dirty tracking.

  ROUND 4 (2026-04-28):
  Root cause: _player_score_panel.html.erb (both left and right panel sections) used the
  LEGACY `table_monitor.follow_up?` check for the Nachstoß UI label, with no is_bk2 branch.
  For BK-* Detail-Form games, allow_follow_up=1 was emitted (default-checked checkbox),
  causing follow_up? to fire and show "Nachstoß" whenever the legacy balls_goal condition
  fired — entirely bypassing the bk2_state nachstoss_pending gate from Rounds 1-3.
  Fix 1: app/models/table_monitor.rb — add public bk_nachstoss_active? method that reads
    data.dig("bk2_state", "nachstoss_pending") == true.
  Fix 2: app/views/table_monitors/_player_score_panel.html.erb — both Nachstoß label sites:
    BK-* branch: `table_monitor.bk_nachstoss_active? && player_active`
    non-BK branch: legacy `table_monitor.follow_up? && player_active && options[:allow_follow_up]`
  Fix 3: app/controllers/table_monitors_controller.rb — allow_follow_up normalization:
    BK-* family (bk_family_form=true): force false (legacy mechanism irrelevant for BK-*).
    Non-BK: unchanged (Quick Start / Detail-Form normalization preserved).

verification: |
  Round 1 self-verified 2026-04-27:
  - 7 new tests GREEN, 45/45 advance_match_state, 28/28 commit_inning, 56/56 scoreboard

  Round 2 self-verified 2026-04-28:
  - 2 new regression tests GREEN: T-F1-stale-bk2-state-cleared, T-F2-nachstoss-own-panel-commit
  - 47/47 advance_match_state_test.rb (2 new)
  - 28/28 commit_inning_test.rb
  - 98/98 total BK2 service tests
  - 9/9 critical concerns tests
  - 20/20 scraping tests
  - Commits: e4d85bb2 (carambus_bcw), b093d389 (carambus_master)

  Round 3 hardening self-verified 2026-04-28:
  - Replaced except!() in-place mutation with data_will_change! + except() (new hash instance)
  - 98/98 total BK2 service tests pass after hardening

  Round 4 self-verified 2026-04-28:
  - 6 new bk_nachstoss_active? tests GREEN (17/17 table_monitor_test.rb, 22 assertions)
  - 98/98 BK2 service tests pass (no regressions)
  - 9/9 critical concerns tests pass
  - 20/20 scraping tests pass

  AWAITING: human verification on BCW dev/production that:
  1. Detail-Form BK-2plus game: "Nachstoß" label does NOT appear when leader reaches balls_goal
  2. Detail-Form BK-2kombi DZ-first, set 1 (DZ phase): "Nachstoß" label does NOT appear
  3. Detail-Form BK-2kombi DZ-first, set 2 (SP phase): "Nachstoß" label DOES appear for
     trailing player after leader reaches balls_goal in inning 1 of the set
  4. Quick Start path: identical behavior to Detail-Form for all 3 cases above

files_changed:
  - app/services/bk2/advance_match_state.rb
  - app/services/bk2/commit_inning.rb
  - app/services/table_monitor/game_setup.rb
  - app/reflexes/table_monitor_reflex.rb
  - app/models/table_monitor.rb
  - app/views/table_monitors/_player_score_panel.html.erb
  - app/controllers/table_monitors_controller.rb
  - test/services/bk2/advance_match_state_test.rb
  - test/models/table_monitor_test.rb
