# Changelog — `auto` (Zero-Latency Goalkeeper AI)

Every release note the script used to carry in its own header comment, newest
first. The header now holds only the current release + the essentials; this file
is the history. Entries were written against the in-game misses each version
fixed, so they double as the design rationale for the thresholds in `CONFIG`.

---

## v2.58 — enum-proof dives, OP tackles, long-read guard (friend console #2) (2026-09-12)

- FIELD REPORT #5 arrived as a console screenshot from the friend's device, not
  prose — and it was worth both. The v2.57 markers were all live (🌈/🧊/📟
  PERF ~49 fps tier 0), and between an EXTREME commit and a CONCEDED sat
  `LOOP ERROR #3: Falling is not a valid member of "Enum.HumanoidStateType"`.
  The user's ask rode along: tackling more OP, dive detections better, counters
  better, and "bachira is not just dribbling read" — his roster rows say the
  same (aerial scissor barrage, mid-air curve bends), so the reads had to
  cover the man, not just his feet.
- THE LOOP ERROR WAS EATING SAVES. `tryAutoJump`'s moved-check read
  `humanoid:GetState() == Enum.HumanoidStateType.Falling` — and on clients
  whose enum table predates or strips members (mobile/older executors) reading
  a missing member THROWS. The throw sat between `ChangeState(Jumping)` and
  `FireServer`, so the jump decorated nothing, the dive never fired, and the
  frame died to the outer loop handler — an EXTREME commit became a CONCEDED.
  v2.58 reads the state as `tostring(GetState())` and matches `.Falling` /
  `.Jumping` / `.Landed` by string inside pcall (a Roblox enum's tostring ends
  in the member name, so a missing member can't be indexed at all), and the
  one DIVE ORDER RULE is now enforced in `fireDive` itself: FireServer FIRST,
  decoration (the jump attempt) after — a hop can never again swallow a
  committed dive. The mock grew `SIM.enumMissing` + `SIM.stateOverride` so the
  test lane can reproduce an honest client (game rejects the forced jump →
  state is Falling); S37 against v2.57 prints the friend's error line verbatim
  — same member, same code path — and shows dives 0. On v2.58: jumped, dived,
  zero loop errors.
- TACKLE, OP-ED (user ask). `TACKLE_RANGE` 9 → 10.5 studs and
  `TACKLE_COOLDOWN` 0.9 → 0.55 s: the keeper now out-reaches a first touch and
  wins second balls. Two fences keep it honest — 11 studs started stealing
  S08's fresh-receiver gathers (a receiver walking onto a pass is not a
  dribbler), so 10.5 is the ceiling the scenario suite allows, and the new
  loose-flick collect clause only arms inside the flick-memory window (ball
  popped ≤ FLICK_MEMORY+0.6 s ago, ≤4 studs off, ball <8 studs/s) and NEVER
  during a juggle or a receiver's path. The rules table carries both rows.
- 🧷 LONG READ GUARD. The friend's screenshot committed `Dir: Left` at 95
  studs on a LATE SPIKE whose lateral offset was a coin flip; the wiki GK
  guide's doctrine is "stay on your line and react to the release, not the
  animation". Past `LONG_GUESS_DIST` (85 studs, new CONFIG row + rules-table
  row), a Left/Right read whose predicted lateral still sits inside the
  center band (×1.8 tolerance) is HELD — `Middle` goes to the game, the
  keeper stays set, and `🧷 LONG READ — holding the middle at N studs` says
  why (3 s dedup, urgent-line: it's a decision). Close-range guesses are
  untouched; a floor ball inside 22 studs still gets its v2.53 plow — the
  guard only replaces SIDE guesses that far out. S38 (chest-height 190-stud/s
  spike from 103 studs) pins it.
- COUNTERS, SHARPENED. Bachira's stance is no longer dribble-only: his
  COUNTER_MODES row reads WILD HANDLER — confirmFrames 2 (his shots BEND
  mid-air: waiting one extra frame reads the curve, not the feint),
  quickSpeed 100 (he releases fast off the trivelox), rangeBoost 4 (the
  scissor barrage arrives flatter than a struck shot). The numbers are OUR
  knobs around in-repo roster data — none of his unreleased move values are
  hardcoded. Isagi's row got the +5 quick release read (105), Rin and Reo
  each +4 range (their kits read as strikes from further than the game's
  numbers imply). Counter choice still follows the BALL-HANDLER live — the
  roster rows only decide HOW each style is read.
- Header now claims 38 scenarios (S37/S38 added); 38/38 pass, lint clean,
  S21 bench 46.8 ms / 798 frames (v2.57: 45.1 — the guard is three compares).

---

## v2.57 — log budget, faster guardian, ECO_LOCK (second lag report) (2026-09-12)

- FIELD REPORT #4 (same friend, same phone): "he's lagging again." Two real
  causes, neither of which the v2.54 guardian could see or touch:
  1. His device lives around 35–40 fps — ABOVE the 33 fps tier-1 trigger, so
     easing never fired at all. A governor that only reacts at 30 fps is a
     rescue siren for the drowning, not an air conditioner.
  2. `VERBOSE = true` ships on: every decision PRINTS, and on a phone with the
     executor console attached a print costs more Lua-frame than the entire
     dive brain. A scramble (handler re-arming on every possession swap, floor
     reads, dive lines, saves/goals) stacks a dozen prints in a second — the
     console itself becomes the lag.
- GOVERNOR v2: tier 1 starts under ~41 fps (ema>0.0245; back to full above
  ~52), tier 2 under ~25; the EMA constant moved 0.06→0.10 so tier flips land
  in ~15 frames, not 40. The thresholds that mattered were the ones between
  the friend's reality and 33.
- LOG BUDGET: all output flows through one sliding gate — 8 lines per 2 s at
  full paint, 3 while easing, 12 for the boot window (the load banner is never
  clipped); overflow COUNTS, and the next allowed line appends
  `(+N lines muted by log budget)` — the mute is visible, never silent.
  Lines that matter under stress BYPASS it (urgent flag): the 🐢 tier flips,
  🔌 remote heals, 📟 PERF. Decision lines stay decision lines — the budget
  eats ink, never saves: S36 asserts every scramble shot is still dived while
  half the commentary is muted.
- 📟 PERF HEARTBEAT: while a device sits under 50 fps, every 20 s:
  `📟 PERF | ~39 fps | paint tier 1` — silent on healthy devices. That gives a
  "it lags" report an actual number next time.
- ECO_LOCK (0/1/2): the A/B answer for "is the script still causing my lag?"
  — set 2 and every decoration is off regardless of fps; if the phone still
  stutters, the culprit is the game or the executor, not this file. Clamped in
  CONFIG_RULES like the rest.
- S36 runs the loop at 0.0255 s/frame and asserts all three: tier 1 engages
  where v2.56 ignored it, the scramble overflows the budget (mute note
  appears), PERF reports after its 20 s, and every shot is still dived.
  Against v2.56 the scenario fails 3 ways. 36/36.
## v2.56 — flick respect: rainbows don't beat gravity (2026-09-12)

- FIELD REPORT #3 (user's friend): "when u play the script and u rainbow flick
  it jumps — auto jumps — because it thinks it's an aerial shot." Correct on
  all three counts. A dribble pop off the feet feeds THREE separate bites:
  (1) the descent reads as a descending loft (vY < -10 near the keeper) →
  LOFT-CATCH lunge; (2) the raw height inflates the dive's jump impact
  (`max(impactY, ballPos.Y)`) → top-bin test satisfied → JUMP + apex hop at a
  ball that was landing at the flicker's feet; (3) a pop is literally "ball
  rose off a player's feet" — the CHARGE juggle tell — so the keeper armed
  🎪 against a shot that was never coming. The mock reproduces all of it:
  S34 against v2.55 logs `☄️ EXTREME — MAX URGENCY | Dir: Forward | @6 studs`
  mid-pop.
- THE SIGNAL NO STRUCK SHOT SHOWS: the ball RISING while still at the nearest
  opponent's own distance (≤ FLICK_CARRY_RADIUS) and under strike speed
  (< DRIBBLE_MAX_SPEED). That frame stamps a memory (`ST.flickT`): for
  FLICK_MEMORY (1.2 s) the loft lunge and the top-bin/apex jump stand down,
  and the pop does NOT count as a charge juggle. No new velocity plumbing —
  the juggle read already had `nearPlayer`/`nearDist`/`vySign` on the frame.
- NOT A SELF-BLIND: the gate rides the ball's CURRENT speed on the dive side,
  so a real shot struck off the flick (75+ studs/s) leaves the window the same
  frame — S34 asserts the follow-up strike is still dived (`Dir:` logged,
  exactly one dive total: zero during the drop, one on the shot). And the drop
  itself stays watched: GK-tackle/step-up paths fire when the attacker collects.
- The jump gate receives the dive's `ballSpeed` (new third arg on tryAutoJump,
  threaded from fireDive) rather than re-sampling — the jump decision belongs to
  the dive it decorates, same speed, same frame.
- Console line when it bites: `🌈 FLICK RESPECT | CHIGIRI popped it up at his
  own feet — no lunge, no leap, let it land` (deduped 1.5 s). Knobs:
  FLICK_CARRY_RADIUS 7, FLICK_MEMORY 1.2 (both clamp-validated).
## v2.55 — self-fitting UI: the HUD learns the size of your screen (2026-09-12)

- FIELD REPORT #2 (user's friend, same weak phone): "no more lag but the UI is
  too annoying." True by construction — createHud() had literally hardcoded the
  desktop layout since v1: a 720-px panel (`UDim2.fromOffset(720, 80)`), text
  sizes 13–15, a 44-pt SAVE!! flash. On a 640-px phone that is a HUD wider than
  the screen minus margins: half the game covered in telemetry.
- THE FITTER: `fitUi` reads `Camera.ViewportSize.X` (real pixels — the only
  honest measure of "how big is this on MY screen"), clamps
  `width / UI_FIT_REF` into `[UI_FIT_MIN, 1]`, and scales every non-game visual
  from that one number: HUD frame size AND position (kept dead-center: the
  offset is `-360*scale`, not the raw 360), corner radius, all three line
  fonts, the flash, the floating studs label, and the font of every style tag.
  Freshly created tags are BORN at the current scale (one shared `uiScaleCur`),
  so a mid-match joiner never shows a desktop-size tag on a phone.
- CADENCE: the governor connection (v2.54) polls the viewport at 1 Hz with a
  two-stage guard (width moved ≥8 px before computing; scale moved ≥0.03
  before writing) — a property read and two comparisons per second is free even
  on the friend's phone, and rotation/resize re-fits within a heartbeat after.
  Boot gets one FORCED fit (`fitUi(true)` right after the builders) so the
  first frame is already sized. The paint guardian and the fitter stay
  orthogonal: UI_AUTO_FIT works with LOW_SPEC_GUARDIAN off and vice versa.
- LEGIBILITY FLOOR: UI_FIT_MIN = 0.55 — a 640-px screen gets a 396-px HUD with
  10-pt minimum text, NOT unreadable ant-size; desktops (≥1280 px) keep the
  original full layout, byte-identical sizes.
- S33 drives the real mock GUI tree at 640 px and 1920 px: frame offset 396 →
  720, line1 floored to 10, studs label 24→13pt, and both 📱 console lines.
  Bench went 46→43 ms across the suite — the 1 Hz viewport poll is noise, and
  change-gating (v2.54) pays for itself on normal screens too.
## v2.54 — low-spec guardian: lag-proof paint, full-rate dives (2026-09-12)

- FIELD REPORT (user's friend, weak phone): "lagging so much… bad device."
  Profiled the script before touching it: the Lua brain is ~0.055 ms/frame
  (bench: 46.3 ms across 798 frames of 12-player chaos + 23 Vector3 allocs) —
  a phone cannot fall over on that. What falls over is PAINT: translucent path
  dots + impact marker (GPU overdraw), billboard style tags (each head = a text
  relayout EVERY frame the anchor moves), HUD text (10 Hz relayout), zone parts.
- THE GUARDIAN: one Heartbeat governor reads the REAL deltaTime (the same
  callback the tag-follow loop runs in — the two loops were merged into one
  connection, one cadence). Frame-time EMA with two hysteresis pairs:
  tier 1 sustained <~33 fps (dots/impact OFF, tag follow 20 Hz, HUD 3.5x
  slower), tier 2 sustained <~22 fps (style BILLBOARDS fully `Enabled=false` —
  zero render cost — zones hidden). Recovery re-upgrades automatically; every
  tier flip logs ONE console line (🐢 … dives untouched) — hysteresis, not a
  timer, is the anti-spam: crossing back needs seconds of sustained frames.
- WHAT NEVER SLOWS: prediction, commit counting, jumps, the apex hop, the
  hitbox cube, and the dive remote. Decision logic runs EVERY frame in every
  tier — a laggy phone keeps saving with fewer sparkles; the keeper never
  blinks because the GPU is drowning. S32 proves it by running the whole script
  at 16 fps (dt=0.06/frame through the mock Heartbeat): 🐢 deep fires, the dive
  still lands (`Dir: Forward` at @3 studs), paint recovers at 60 fps.
- EVERY-DEVICE WIN regardless of tiers: every HUD Text/TextColor3 write is now
  gated on CHANGE (identical string = no relayout) and the tag label writes
  already were — the governor makes the expensive case rare, the guards make
  the common case cheaper.
- `LOW_SPEC_GUARDIAN = false` opts out entirely (the follow loop runs unguarded
  at frame rate, ecoTier stays 0).

## v2.53 — floor-shot plow + awakening watch (2026-09-11)

- FIELD TEST (user, vs friends): low skidding balls tricked the lateral read and
  the keeper DIVE THE WRONG WAY. Cause: a struck floor ball skids, bounces and
  sheds speed — its last-frame SIDE-SPEED is the least stable input we consume,
  and quick-open commits a direction before the skid finishes. The community GK
  guide's own doctrine is the fix: "stay centered as long as possible and react
  to the RELEASE, not the animation"; the shot-guide even describes the ground
  ball "sliding across the ground and awkwardly coming to a dead stop".
- 🧊 FLOOR SHOT READ (CONFIG.FLOOR_SHOT_READ, master switch): while the live ball
  is low over the MEASURED pitch (ballY − ST.groundY ≤ 1.8 — the bounce model's
  own running ground reference, no new sensor), three things change: the center
  band WIDENS ×1.8 (half-committed side dives at maybe-left rollers become "hold,
  gather"); side dives need +1 agreeing confirm frame (the read must survive the
  skid); and a floor ball inside the widened band within plow range is SMOTHERED
  FORWARD — the user's rule verbatim ("if it's a floor shot or going towards you
  or somewhere near you — forwards"). No side can be wrong if you never pick one.
- Sizing lesson from S30: FLOOR_SMOTHER_DIST started at 16 studs and MISSED —
  the dive commit fires ≈0.2 s ahead (≈17 studs at shot speed), so the override
  now LEADS it at 22 (clamped 6–40). The plow log dedupes once per 2 s.
- 👑 AWAKENING WATCH: every fandom-documented G cutscene is a PROMISE —
  "Requires the ball" and the AWAKENED BOMB follows (Big Bang Drive after Demon
  wings-cue, Godspeed Kill Shot, Beinchuss, 5-Stage Volley, King's Return…).
  Registered 15 cutscene rows (theking, thegenius, thesloth, theemperor,
  chameleondefense + wiki "chamaleon" spelling, ironwall, theworld, hungryzombie,
  blindspot(offtheball), gearsecond, thebestgoalkeeper, theredphanter + redpanther
  alias) — all speed=defense + cutscene=true: awareness, NEVER a bomb read,
  NEVER role-forensics evidence (shared names like The Destroyer prove why).
  When one resolves, the NEAREST opponent is credited (shared finder with role
  forensics now — nearestOpponentNear) and while the ball is his, all reads on
  him are FORCED FULL (confirmFrames ≥ 2) for 6.5 s: never quick-open at a man
  mid-animation. Console: 👑 AWAKENING | Name | BarouTheKing — full reads until
  it resolves. One table = one upvalue (budget kept).
- Scenarios S30 (skidding x=6 ball: outside the OLD band, inside the floor band —
  asserts the 🧊 plow line AND dirs{Forward} via the runner's direction mix) and
  S31 (cutscene arms 👑 and by itself dives NOTHING: max = 0). 32/32, lint clean,
  bench flat (23 allocs/frame — the classifier is two comparisons on cached
  values; the plow never allocates).

---

## v2.52 — admin-grade hitbox expander (the Infinite-Yield way) (2026-09-11)

- v2.51 resized the root part. The user said: no — do it like the ADMIN TOOLS.
  Infinite Yield's `expandhitbox` / Nameless Admin's hitbox command welds a big
  INVISIBLE, MASSLESS, non-colliding CUBE onto HumanoidRootPart instead. Better
  on every axis: the server doesn't re-sync welded client attachments the way it
  snaps part sizes, a fat root would clip walls and seating, and part-LIST checks
  (touches, catches, overlaps) accept any attached part as "the character".
  This game runs the ball CLIENT-side (NetworkOwners — the very basis of the
  handler-read), which is precisely where an expansion cube registers: the ball
  touches 14 studs of "keeper" before his body arrives.
- CONFIG (admin-command style): HITBOX_EXPAND = 14 studs default (0 = off,
  24 = wall, 40+ = possession is nine-tenths), clamped by HITBOX_EXPAND_MAX = 60
  (Infinite Yield clamps at 1000; that swallows the goal camera).
- Lifecycle: one cube per character — it is a CHILD of the root, so a respawn
  destroys it automatically and the next tick re-welds; a 4 s watchdog re-welds
  if anything else scrubs it. Weld = legacy Instance.new("Weld") Part0/Part1
  with identity C0/C1 (the classic: centers the cube on the root).
- Our OWN save-detector explicitly SKIPS GKHitbox (name filter): the cube is for
  the GAME's catch math; the internal "did the ball touch the keeper" truth stays
  body-honest, so a fake overlap can never resolve diveWatch early and skip a
  re-react. If the game validates part lists server-side, the cube is just an
  invisible box — harmless.
- S29 re-targeted (asserts the 🧱 HITBOX EXPANDED line — which only prints when
  the weld actually succeeded). 30/30, lint clean, bench flat (23 allocs/frame).

---

## v2.51 — whole-game wiki sync + the reach-boost hitbox (2026-09-11)

- Deep sweep: EVERY character page, the controls/mechanics sources and the GK
  guide were reconciled against the model line by line (fandom wiki + the two
  community wikis). Most of it CONFIRMED existing work (Reo's Copy = "his kick
  is anyone's kick" — exactly why WILDCARD HANDLER never jumps on frame one;
  Gagamaru's whole kit already registered; Sae's curve "always the left foot"
  already driving primeSide; the Dio timestop model — shot AFTER the freeze —
  matches the page verbatim). The gaps that were real:
- Registered now (fandom-documented, previously missing): Nagi FAKE SHOT (the
  "feint → you slide → ankle-breaker → +1 of 5 fake volleys" bait; its real
  strike is the 5-Stage Volley) and TRAP SHOT; Kaiser BEINCHUSS (awakening
  chilean volley — cutscene wind-up THEN strike); Reo CHAMELEON JUMP (super-jump
  forward; the wiki's "Chamaleon" misspelling kept as an alias); Dio STAND USER
  (he steps aside, the GOLDEN COMPANION kicks — the body is the decoy) and the
  ZAWARUDO shout itself (arms the timestop window); DFU JET variants (Jet Kick /
  Jet Lighting Trap "jumps more higher" / Jet Lighting Dribble) + GIANT SABLES
  (tornado knockback, not a shot); Luffy INSTANT CONQUEROR'S HAKI — its counter
  existed in COUNTER_MODES but had NO classification ROW: it was dead code, now
  wired live (a lint-worthy find).
- Ronaldo's awakening, NEAR THE GK, is a whole OTHER thing (the wiki documents a
  second variant): "the GK launches at the user, the user dodges and grabs him...
  whoever TAPS or CLICKS MORE gets the goal." So diving/leaping AT awakened
  Ronaldo IS the trigger. Enforced: ohcristiano/siuuuuuu now carry
  suppressJump=true + armed=8, and tryAutoJump refuses to hop while
  ST.noLeap is live — the keeper holds his ground and makes Ronaldo play it.
- Gomu-Gomu Balloon: "catches the ball in their stomach... AFTER TWO SECONDS it
  shoots out" — FLOAT CAPTURE becomes BALLOON — 2s IN THE BELLY with armed=4 +
  forced 2-frame read (stay set through the belly hold; the release is late BY
  DESIGN, it is not a fake).
- Chigiri's High-Speed Shot fixed: "dash to the right THEN JUMP UP and perform a
  powerful shot" — the row was aerial=false; it is an aerial finish now.
- Aiku confirmed (jumping header can finish — aerial=true already), Barou's
  double-tap chop stays covered by the POWER HANDLER note, Dio barrage timing
  unchanged. The Destroyer CUTSCENE is shared by RIN and SHIDOU — the row is
  flagged cutscene=true, which excludes it from ROLE FORENSICS evidence
  (a shared name attributes nobody) and it stays awareness-only.
- 🧱 REACH BOOST (the requested "small hitbox"): the game decides catches by
  HITBOX OVERLAP, and character parts are client-owned — sizes set from a
  LocalScript replicate to the server. The keeper's HumanoidRootPart now grows
  HITBOX_REACH = 1.5 studs on every axis once per CHARACTER, re-asserted every
  4 s if the game resets it. The save-detector (which measures the live part
  sizes) follows automatically, so our own catch math and the GAME's agree.
  0 disables. Sized modest on purpose; if the game locks sizes it no-ops.
- Scenario S29 (boost applied + dive unaffected). 30/30, lint clean, bench flat
  (43.8 ms / 23 allocs per frame — the boost tick costs nothing).

---

## v2.50 — Shidou's double jump modeled + the keeper's apex hop (2026-09-11)

- Research (fandom Shidou page, retrieved 2026-09-11): the kit's "double jump" is
  DEMON RUSH — "medium-length fast dash, short window to press the key again; if
  pressed the player jumps far in the air (Mario Jump SFX)". Also: Big Bang Drive
  begins with an airborne hit into a bicycle kick ("propelled incredibly fast");
  Demon Wings jumps "incredibly high (~1.5x Nagi's Trap Shot)" then FLIES —
  uncancellable, extended absence; the G cutscene (The Destroyer) is a
  possession grab ("my ball"), not a shot. Cooldowns: TBA on the wiki — no
  published numbers, so none were invented.
- Counters updated to match: COUNTER_MODES.demonrush gains confirmFrames=2 +
  heightBonus=10 (the dash has a second act from above the flat-dive plane —
  read through the rush, capture higher on the jump finish); demonswings gets the
  entry-vs-cruise note (danger is the jump IN; wings cruising is absence);
  CLASSIFICATION adds thedestroyer (speed=defense: arms awareness, never a bomb
  read); STYLE_COUNTERS.shidou comment now states the second-press mechanic.
- NEW KEEPER TOOL — AUTO_DOUBLE_JUMP apex hop: since the game permits mid-air
  hops, after a top-bin jump whose predicted impact clips the crossbar even
  jumped (>= DOUBLE_JUMP_HEIGHT_FRACTION of the MEASURED net), one follow-up hop
  is armed and fires at the apex from the always-on section of mainStep
  (airborne-only, never from the ground, no-op if the game owns the humanoid —
  the v2.44 block-warning covers that). CONFIG: AUTO_DOUBLE_JUMP /
  _DELAY 0.26s / _HEIGHT_FRACTION 0.95, all clamped in CONFIG_RULES.
- Scenario S28: crossbar-clipper must log the TOP-BIN JUMP and then the
  "DOUBLE JUMP — apex hop" line. 29/29 pass, lint clean, dives unaffected on
  every existing scenario.

---

## v2.49 — self-healing dive handle: match resets can't kill it (2026-09-11)

- THE real "it just doesn't work anymore after a new match": OUR bug, and it was
  the same disease as the game's once-checked roles. `DiveEvent` was resolved
  ONCE at boot. Roblox match frameworks destroy and rebuild match-scoped objects
  between matches; a client firing into the destroyed instance gets an error
  inside fireDive's silent pcall — every gate still decided, every line still
  logged, the keeper just never dove again. For the rest of the session.
- The handle now self-heals: ensureDiveRemote() validates `DiveEvent.Parent` at
  every use; on death it re-searches IMMEDIATELY (a vanished handle is a legit
  trigger, never gated by the poll timer) and otherwise retries at most every
  4 s; findDiveRemote(instant) makes the in-game search non-blocking (no 3 s
  WaitForChild freeze between shots); a failed FireServer also drops the handle
  so the next decision re-acquires; and games that park the remote under
  workspace get instant re-grab via the DescendantAdded head of the line.
  Console now SHOWS the healing: 🔌 vanished (match reset?) — re-searching /
  🔌 dive remote acquired: Events.GKDive.
- The boot warn path (no remote found → dives log as NO-DIVE, gates stay live)
  is unchanged — it simply ends as soon as the remote appears, whenever that is.
- Scenario S27: dive once, DESTROY the remote (match reset), parent a fresh one,
  dive again — the second dive can only count through the healed handle. 28/28.

---

## v2.48 — role forensics: labels that follow the truth (2026-09-11)

- THE user-reported screenshot bug: the game checks each player's role/style ONCE
  (join / match start) and never re-checks, so after "another match happens" its
  own red role labels go stale — ghost text ("STAND USER") floating over EMPTY
  GRASS while the players moved on, style names that no longer match anyone.
- The server's labels can't be rewritten from a client — but its EFFECTS cannot
  lie. Every resolved `<Char><Move>` effect tag now credits the nearest
  opponent within 14 studs of its spawn point (roleForensics); TWO same-style
  castings that contradict a claimed role OVERRIDE the classification — the style
  tag, the handler read and every STYLE_COUNTER/COUNTER_MODE decision follow the
  casts, not the stale claim. Keeper-kit effects (gagamaru) are excluded (thrown
  clears happen near everyone). Log line: 🕵️ ROLE FORENSICS | <name> | ...
- Self-heal: the override releases the moment the game's own raw Values string
  changes again (log: "Values changed — trusting the game again"). Forensics
  state is cleaned on PlayerRemoving like every other per-player store.
- No ghost tags of OURS: a style tag is only kept while its player has a live
  character with a root (players in intermission/respawn get their tag torn down
  by the alive sweep instead of drifting over midfield), and the per-frame anchor
  loop re-binds on CHARACTER identity change, not just part death — recycled
  match models can no longer strand a label.
- Scenario S26: a player whose Values claim "Dio" but who casts two Shidou moves
  at his feet must be re-labelled SHIDOU — the whole forensics contract, tested.
  27/27 pass; lint clean; no bench movement.

---

## v2.47 — full-roster counters + the role read never stops (2026-09-11)

- **THE staleness fix (the user-reported "it checks the player roles once"):**
  the roster pass / possession / handler read sat BELOW the two interest gates
  (`speed < MIN_INTEREST_SPEED → markIdle + return`), so the armed counter only
  updated on frames where the ball was faster than 10 studs/s. A slow dribble, a
  walk-in at a dead ball, or a mid-match role swap at rest left the previous
  counter standing — indistinguishable from "checked once". The whole READ
  (myKey, shooter-key re-resolve, goal scan, one roster pass, poss, handler
  read) is now hoisted above the gates: it runs every frame, markIdle included.
  The gates still skip the expensive PREDICTION for quiet balls. Regression
  proof: scenario S25 (Role-attribute-only classification, flipped mid-match at
  dribble speed → the flip log). 26/26 pass; no behavior change at shot speeds.
- **STYLE_COUNTERS now covers the entire classification roster** (was 8 of 24):
  shidou, dio, luffy, ichigo, bachira, chigiri, ronaldo, donlorenzo, kurona,
  gagamaru, yukimiya, otoya, aiku, igaguri, kunigami, hiori + naoya. Every stance
  is derived from that style's OWN rows (tricky/dribble families → forced
  2-frame read; straight 'extreme' rows → quickSpeed 95 + faster re-arm;
  carrier/throw-in styles → rangeBoost), using only fields the activeMode
  pipeline already consumes. NO invented game numbers — the fandom publishes
  none (docs/GAME_RESEARCH.md); these are read-timing choices, not claims.
- **Naoya registered** — the September "naoya" code (50k) follows the
  KURONA/SHIDOU pattern of codes named after styles, but no fandom style page
  exists yet, so: CHAR_NAMES alias + CHAR_PROFILES placeholder + MOVE_PREFIXES
  "naoya" (a "Naoya<Move>" effect tag resolves through the existing cross
  product) + STYLE_COUNTERS.naoya = PERFECT IMPACT WATCH (forced 2-frame read —
  the universal stance for an unread handler). Unknown effect names still
  self-report in the console for a dedicated counter later.
- **readPlayerStyle now reads Role/Position attributes** from the player's
  Values folder (previously only Character/Style/CharacterName/StyleName) — a
  player whose style is stored in a Role field used to be invisible to the
  classifier entirely.
- **Research (docs/GAME_RESEARCH.md addendum):** the game's own GK guide
  (bluelockskibidi.wiki) recorded verbatim — Q to dive, follow the BALL not the
  players, "react to the ball's release rather than the opening animation",
  leave the goal only to beat the attacker to a loose ball — every pillar
  matches this script's gates (release gate, fake hold, carrier read, sweeper
  logic): the strongest outside confirmation the model has had. Dio: Secret
  tier, Timestop-based (fandom styles page + bluelockskibidi.com) — consistent
  with the existing timestop/timestopbarrage COUNTER_MODEs (shot lands after
  time resumes → 6 s armed window).
- Harness: roblox_mock implements Get/SetAttribute for real (both were no-op
  stubs, so attribute-shaped game data was untestable).

---

---

## v2.46 — the counter follows the ball (handler style read + Kurona One-Two)

Prompted by the fandom research (`docs/GAME_RESEARCH.md`): the keeper should
read WHO has the ball, not only what move tag fired. v2.45 already profiled the
attacker; this makes possession select the full stance.

- 🎭 **STYLE_COUNTERS — per-style HANDLER stances.** While an opponent controls
  the ball and no move tag is alive, his style arms a stance through the same
  `activeMode` pipeline the move counters use: Rin/Sae → CURVE HANDLER (forced
  2-frame read — any touch can become the left-breaker); Reo → WILDCARD HANDLER
  (his kick is anyone's kick); DFU → BALLOON WATCH; Kaiser → IMPACT HANDLER
  (0.75× re-arm); Isagi → VOLLEY HANDLER; Nagi → CARRIER HANDLER (+6 range for
  the Skull-Rush carrier); Barou → POWER HANDLER (quick read opens at 95/s).
  Deliberately NO dive-side prime at a *dribbling* player — that is the exact
  bait the official GK guide warns about; tags still prime (v2.32 rule).
- 🔀 **Switch the frame the ball changes hands.** `attackerPlayer` now prefers
  `NetworkOwner` over the distance-carrier heuristic (a fast dribble run drops
  the heuristic but not server ownership), and the handler flip is logged:
  `🎭 HANDLER | KURONA → KAISER | counter re-armed`. The read deliberately
  survives a short ball-rest (the one-two pauses at the receiver's feet — the
  flip must stick), and clears on a live frame once the ball is loose or an own
  touch takes it. The stance name rides the dive log (🎮 tag) and the HUD.
- 🦈 **Kurona One-Two / Bait Dribble registered.** The sister-game wiki
  explicitly recommends the one-two as goalkeeper bait ("One, Two, Volley!" —
  the receiver fires on the first touch). `onetwo` classified as a pass with a
  HOTLINE TRICK — HOLD counter (stay set through the exchange; the receiver
  becomes the handler and his style re-arms the counter on the catch);
  `baitdribble` classified as a dribble (carry gate already handles it).
- 👀 `Naoya` (Sep 2026 code) still has no character data anywhere — watchlist
  only, in `docs/GAME_RESEARCH.md`. The AI prints unclassifiable move tags, so
  when the update lands, its real move names come to you.

## v2.45 — roster audit vs fandom research (`docs/GAME_RESEARCH.md`)

Cross-checked every move in the script against a full research pass of the Blue
Lock: Skibidi fandom (all styles, the GK guide, chemical reactions, dive rules)
and the September 2026 update's code names (`Naoya`, `Mugetsu`, `KURONA`).

- 🩸 **Nagi — SKULL RUSH counter was dead code.** The roster key was spelled
  `skulrush` (single L); the in-game effect tag is `NagiSkullRush`, so the
  quickSpeed/rangeBoost entry could never fire on the carrier. Primary key fixed
  to `skullrush`; the single-L spelling kept as a harmless alias (in-game tag
  spellings have varied before — the dribble move already carries both).
- ➕ **Isagi — MOVE IT registered** (`speed = "steal"` → STEAL ALERT): throws a
  player into the air and takes the ball. Until now the steal alerts covered
  Devour / Half Baked / Yo Michael / I'll Beat You Up / Dough Donut / Monster
  Attack but not Isagi's.
- ➕ **Devil Fruit User — LIGHTNING TRAP alt spelling.** Fandom text mixes
  "Lightning" and "lighting"; the script already registers both spellings for
  Lightning Dribble but only `lightingtrap` for the Trap. Added `lightningtrap`.
- 👀 **Watchlist (deliberately NOT in the script):** `Naoya`, `Mugetsu`,
  `hidoi na` are September 2026 cash codes with no fandom pages yet; Mugetsu is
  presumably Ichigo's Bankai finisher (the `BANKAI` code and `bankai` roster
  entry already exist). The AI prints any move-style tag it sees but cannot
  classify, so the real names will announce themselves in the console before
  anyone can hardcode them.
- 📚 Verified against `CONFIG`: the research doc's v2.32-era design numbers all
  match (BASE_DIVE_TIME 0.32, COMMIT_SPEED_FACTOR 0.16, QUICK_READ_FRAMES 1,
  COOLDOWN_TIME 0.5, SHOT_RELEASE_SPEED 75, timestop armed 6 s);
  CURVE_COMMIT_LEAD is 0.30 (v2.34 improved it from the 0.20 the doc quotes).
- 📚 `docs/GAME_RESEARCH.md` added — the research dump + a 2026-09-11 addendum,
  so future sessions get the fandom context without re-researching.

## v2.44 — correctness pass, hot-loop rewrite, real test rig

First release with a test harness: `tools/` runs the script against a mock Roblox
runtime (24 scenarios — shots, fakes, passes, carries, juggles, lofts, top bins,
ball respawn, a missing dive remote, a pause hotkey) plus `tools/lint.py`. Every
change below was verified by diffing the dive decisions of all 24 scenarios
before/after; only the two bug fixes change behaviour.

**Fixed (each one reproduced in the sim first)**

- 🏟️ **Own-team shots were dived.** `refreshTeams()`, `scanCharacters()`,
  `updateStyleTags()` and `scanGoal()` all sat BELOW the loop's "ball is idle /
  far away" early returns, so while the ball rested (every kickoff and restart)
  nothing refreshed at all. On the frame the ball left a teammate's foot the team
  cache could still be empty, the shot was credited to `opp`, and the keeper dove
  away from our own goal kick with the middle of the net empty. Housekeeping now
  runs first, `myKey` is read after it, and the shooter's team is re-resolved from
  the player every frame instead of trusting a strike-frame snapshot (which is
  nil whenever the cache lags by one frame).
- 🎈 **Lunges at balls that cannot score.** The loft-catch branch never consulted
  the honest wide/over ruling, so a chip sailing over the bar — or a ball already
  past the line — earned a full Forward lunge that burned the dive cooldown and
  abandoned the rebound. It now respects `definitelyMiss`.
- 🦘 **The top-bin jump silently did nothing.** The `Jump()` fallback was gated on
  `ChangeState` *erroring*, and `ChangeState` never errors — games that own the
  humanoid state machine just ignore it. The state is now checked, `Jump()` runs
  when it did not move, and if both are blocked the script says so once instead of
  leaving the top bin quietly unsavable.
- 🎥 **One nil camera blinded the keeper permanently.** `Camera.CFrame` was indexed
  in ~6 places; when `workspace.CurrentCamera` is nil (a tick after a respawn, or
  a script that booted before the camera existed) the loop threw on the same line
  every frame while the pcall guard throttled it to one message per 5 s — a dead
  AI that looked alive. The camera basis is resolved once per frame, with the
  keeper's own facing as the fallback.
- 📥 **Receiver gate counted teammates.** It is documented as "a non-shooter
  *opponent* in the lane" but matched any player, so our own defender standing in
  the corridor suppressed honest dives — and defenders routinely let a ball through.
- 📡 **A missing dive remote hung the script.** The boot
  `WaitForChild("Events"):WaitForChild("GKDive")` yields forever on a game that
  names it differently: no HUD, no prediction, no error. The remote is now searched
  with bounded waits over the usual names; if it is still absent every gate keeps
  running (so you can watch it decide) and the boot banner plus the first dive say
  `NO DIVE REMOTE`.
- ⏱ **Two clocks.** `mainStep` stamped time with the deprecated epoch `tick()`
  (~0.015 s steps, and it jumps when the client clock is corrected) while every
  other timestamp used `os.clock()`. The controlled-ball gate divides a gap delta
  by a `tick()`-derived dt, so that coarse step went straight into the
  released/controlled decision. One monotonic clock, read once per frame.
- 🎈 **The loft catch solved a different world.** Its quadratic hard-coded
  `-196.2` while the trajectory simulator respects `workspace.Gravity` — with
  non-standard gravity the catch moment was simply wrong. Both use the resolved
  value now.
- 🧹 **Dead config.** `USE_SWEEPER_SMOOTHER` and `SHOW_STUDS_HUD` were declared and
  never read, and the "GK move prediction" block pointed at a function nothing
  called. The switch is now `USE_SLOW_FORWARD_SAVE` and is wired; the dead key and
  the dead predictor are gone — measured A/B in the sim, the reach-refine helper
  flipped 6 of 8 test dives to `Middle`, so it was dead *and* wrong.
- 🧵 `PlayerRemoving` cleared 4 of the 7 per-player stores, so `teamCache`,
  `lbSideByName` and `styleTags` grew for the whole session in lobby hopping.

**Faster (per frame; the 12-player live-shot bench in the sim)**

- 🧮 The trajectory integrator runs in scalars. It used to allocate 1-4 Vector3s
  *per step* for up to ~440 steps a frame: **475 → 23 Vector3 allocations per
  frame** and ~4× less Lua CPU. Goal vectors are unpacked once a frame instead of
  two dot products per step, and the path array reuses its rows.
- 👁 Six loops over the roster (nearest player, carrier, carry correlation,
  controlled gap, `anyRootNear` ×2, `minRootDist`, "player under the ball")
  collapsed into one pass; `oppRoots` is no longer rebuilt every frame.
- 🧱 The goal is found once and re-measured from the cached post parts; the full
  `GetDescendants()` walk runs only when a part disappears or the world changes,
  and is capped by `GOAL_SCAN_CAP` so one scan cannot stall a frame.
- 🎯 One `DescendantAdded` watcher with cheap rejects (length, then an exact-name
  hash precomputed from `MOVE_INFO` × `MOVE_PREFIXES`) instead of
  lower+gsub+33 prefix strips for every particle, decal and attachment the game
  spawns; ball names get a plain substring reject first.
- 🗂 The four sample histories reuse pre-allocated rows instead of ~240 tables a
  second of garbage (a GC step inside a dive window is exactly the hiccup the loop
  guards against); the ground level is recomputed 4×/s instead of a 300-entry scan
  every frame; `Stats.Network` ping is cached for 0.5 s.

**Added**

- ⏸ `PAUSE_KEY` (default `F6`): disarm / re-arm live — no dives, visuals and
  scouting tags go away, the HUD reads PAUSED. The binding is pcall-guarded, so a
  game that owns the key (or `PAUSE_KEY = nil`) is never an error.
- 📝 `VERBOSE`: one gate for the whole console narrative.
- ⚙️ `validateConfig()`: structural numbers are clamped at boot with one line per
  fix, so a bad edit becomes a message instead of a silently blind keeper
  (`SIM_STEP_MIN = 0` used to mean a divide-by-zero in `MAX_STEPS`).
- 🥅 `WIDE_POST_MARGIN` / `BAR_OVER_MARGIN` replace the magic 3.5 / 4 studs in the
  honest wide ruling; `GOAL_SCAN_CAP` bounds the goal lookup.
- 🏷 Style-tag following no longer runs a `FindFirstChild` per player per frame.

---

## v2.43 (the two in-game misses, fixed)
•  🎭 FAKE KILLER (Barou's fake still got you) — the v2.32 bleed-hold
  only covered pops peaking 40-69; an in-game chop that pops at 75-95
  sailed past the window and got a frame-zero dive. Now two layers cover
  the whole pop range:
   (1) FRESH-POP CONFIRM — the first 0.10s of a sub-110 pop is unproven
  (a real strike sustains, a fake dies): no full dive in that window. A
  110+ pop is real shot speed and dives on frame one. Known curve moves
  (Rin/Sae) are exempt — they're researched real shots, not fakes.
   (2) BLEED HOLD (widened 40-69 → 30-110, drop 15→12, window→1.0s) +
  a TRAVEL test: the ball must still be within 14 studs of the kick spot
  to be held — a fake DIED at the feet, a real shot (even a bouncing one)
  is already 14+ studs out and escapes the hold. Self-releasing.
•  🎯 WEAK-CENTER CATCH (the slow shot that got you: "it dove left or
  right, not forward") — a weak shot (under 85) within 7 studs of center
  is now a FORWARD catch, not a committed side dive. A side dive on a
  central weak ball leaves the middle open — exactly how it went in.
  Off-center weak balls (beyond 7 studs) keep their side dive; fast balls
  (85+) commit as before.
•  ✅ 26-scenario simulation passes with zero loop errors (new S25:
  fast fake = no dive; S26: weak central shot = forward catch).

## v2.42 (pass vs. shot — the last "dives when they don't shoot" case)
•  📥 RECEIVER GATE — a ball heading straight at an opponent who ISN'T
  the one who kicked it is a PASS to a receiver, not a shot — the
  receiver collects it before the line. Previously a pass at shot speed
  that the simulator predicted crossing the goal mouth read "on target"
  and got a full dive. Now: a non-shooter opponent within RECEIVER_RADIUS
  (5 studs) of the ball's PREDICTED PATH (next 1.2s) who stands AHEAD of
  the ball (the ball is heading to them — the kicker stands BEHIND it and
  is excluded by that direction test, no launch-window gap) = "RECEIVER
  IN PATH — WATCH" (no shot dive). Path proximity is self-correcting:
  once the ball has passed the receiver, they're behind the ball and the
  gate releases, so a ball that reaches your feet is always met live.
  If the receiver taps it in, that tap is a FRESH shot (new shooter
  credit) and
  the keeper dives at the tap. A real shot's path has no opponent on it,
  so honest saves are untouched. Gates the main dive, the slow-save, and
  the loft catch. NOT applied to the GK tackle (an intentional steal of a
  carrier at your feet) or the punch-out (a contested dead ball at your
  toes).
•  ✅ 24-scenario simulation passes with zero loop errors (new S24:
  hard pass to a receiver = no shot dive, receiver picks it up and
  carries in, tap-in = dive).

## v2.41 (four in-game fixes)
•  🐛 ROLLING-BALL PREDICTION BUG (the REAL root cause of the false
  dives) — the trajectory simulator "bounced" a ball resting on the
  ground EVERY step (gravity makes vy negative each step while the ball
  sits exactly at ground level), so BOUNCE_FRICTION (x0.75) hit vx/vz
  EVERY STEP — the predicted ball stopped dead a few studs away. Rolling
  balls (slow shots, deflections, wide passes) then never produced a
  line crossing, the honest wide ruling was blind to them, and the
  keeper dove at balls going wide. A bounce now only fires on a real
  FALL (vy below one step of gravity); resting balls roll with vy=0 and
  per-second friction only. Also: a ball that has ALREADY crossed the
  goal line is now ruled a miss — the keeper no longer chases a ball
  50 studs behind the goal.
•  🦘 JUMP NOW JUDGES THE LINE HEIGHT — the auto-jump test used
  max(crossing, impact, BALL'S CURRENT HEIGHT). A stand user's shot
  (Dio timestop) is launched FROZEN HIGH in the air, then released
  low — the frozen height made the keeper jump for a LOW ball. Now the
  jump is judged at the PREDICTED LINE CROSSING (where the ball
  actually hits the net): arcing-over-then-dropping-low = no jump;
  true top-bin = jump. Fallback (no goal detected) = impact/ball height.
•   HONEST WIDE RULING (dives when they don't shoot, fast version) —
  SAVE_EVERYTHING used to override the can't-score ruling with a huge
  margin: a ball crossing 12 studs WIDE of the post still read "on
  target" → the keeper dove at wide passes. Now a crossing > 3.5 studs
  outside the post or > 4 studs over the bar = guaranteed miss = stay
  on feet. Saves on true corner balls are untouched.
•  📏 HONEST FORWARD REACH (forward saves from far away) — the slow-
  shot / slow-forward step-save reaches were 30-34 studs (a hopeless
  lunge that wasted the cooldown), the loft lunge 30, and the aerial
  bias had no range cap. Now: step-saves 14 studs, loft lunge 20,
  aerial bias ≤ 35. The "SLOW SHOT INCOMING — MOVE!" warning still
  fires at ANY range (position early, commit close).
•  ✅ 23-scenario simulation passes with zero loop errors (rebuilt
  S10 to a saveable far-post shot, new S23: wide fast pass = no dive).

## v2.40 (GK tackle, false-dive killer, Ichigo detection)
•  🤾 GK TACKLE — researched mechanic (fan wiki GK guide + the game's
  hitbox saves): a keeper's FORWARD save on the ball CARRIER steals
  the ball — "as GK you can tackle your enemy by forward-saving them."
  Now: an opponent CONTROLLING the ball (carry / dribble-in) within
  TACKLE_RANGE (9 studs) of the keeper is met with a Forward (tackle),
  cooldown-gated (0.9s, no spam). It only fires while the ball is
  CONTROLLED — a live shot always takes the normal dive path.
•  🚫 FALSE-DIVE KILLER ("it dives when they don't shoot"): an
  opponent WALKING IN with the ball (hand-carry / slow dribble) used to
  read as a "SLOW SHOT" and trigger Forward dives. New CONTROLLED-BALL
  GATE (separation test, no velocity needed): a RELEASED shot moves
  AWAY from its shooter — the ball-to-nearest-opponent gap grows at
  shot speed (block clears in ~3 frames). A CARRIED ball keeps a
  ~constant gap = CONTROLLED — the slow-shot detector, slow forward
  save, and punch-out all refuse to fire on it. A >80 studs/s gap jump
  (save/re-carry/respawn) restarts the baseline conservatively. Plus:
  a slow "shot" must now head AT the goal line (dot ≥ 0.35) — slow
  flank passes near the keeper no longer read as shots.
•  🥅 ICHIGO DETECTION — he's the new "Shidou & Ichigo Update"
  crossover (Bankai-themed kit, high mobility) and the fandom still
  publishes no in-game move names. Added: bankai kit aliases (Final
  Getenka / Getenka / Shunpo) + a GENERIC CATCH-ALL: ANY effect named
  "Ichigo<Move>" arms the ICHIGO WALL counter (frame-zero) and prints
  the raw name — send me the exact console name and it becomes a
  dedicated counter in one line.
•  ✅ 22-scenario simulation passes with zero loop errors (new S20
  tackle, S21 no-false-dive, S22 Ichigo detection).

## v2.39 (net measured from YOUR in-game screenshot)
•  📸 NET MEASURED — the fandom wiki still publishes no dimensions,
  but your in-game screenshot gave the real net: measured pixel-for-
  pixel against the 2-stud ball (perspective-corrected), the goal is
  ≈ 8 studs tall × ≈ 16 studs wide — a clean 8×16 Roblox goal.
  Those exact values are now hardcoded as the FALLBACK net
  (NET_CROSSBAR_STUDS / NET_WIDTH_STUDS): when the live post scan
  misses, the top-bin test uses 0.7 × (8 - 3) = 3.5 studs above your
  root instead of the old blind 4-stud guess. When the live scan
  DOES find the posts, the real measured net always wins.
•  🦘 JUMP REACH ANSWER: a Roblox jump lifts your root ~7 studs
  (hands then reach ~12 studs off the ground), so jump + dive
  comfortably covers the full 8-stud net — the top bin (above
  ~5.6 studs) is well inside jump reach.
•  ⚖️ TOP_BIN_JUMP_HEIGHT removed: the screenshot net replaced the
  blind fallback (see tryAutoJump).

## v2.38 (top-bin jump now driven by the REAL measured goal)
•  📏 MEASURED-NET TOP-BIN JUMP — searched the Blue Lock Skibidi
  fandom thoroughly for goal/net dimensions and GK jump-reach numbers:
  it PUBLISHES NEITHER. Searched the wiki for "goal net size", "studs
  size dimensions net goal height", "goalkeeper dive jump height reach"
  — no dimension results; the wiki only describes moves in words (e.g.
  Gagamaru's Leap/Perfect Save as "dives to catch the ball"), no studs.
  So the script MEASURES the real in-game goal at runtime instead (it
  already reads the actual goalposts' width + crossbar height in
  scanGoal). The top-bin jump is now data-driven off that REAL measured
  net: jump when the predicted impact reaches TOP_BIN_JUMP_FRACTION
  (0.7) of the measured goal height — the top 30% of the real net (the
  top bin, where a flat dive can't reach). Falls back to the fixed
  TOP_BIN_JUMP_HEIGHT (4 studs) if the goal isn't detected. Tune
  TOP_BIN_JUMP_FRACTION: 0.8 = top corner only, 0.5 = jump more often.
•  🎯 This is the concrete answer to "how big is the net": the AI
  reads the actual in-game net and jumps for balls heading to the top
  of that actual net, instead of a hardcoded stud guess.

## v2.37 (top bins: jump + dive reach)
•  🎯 TOP-BIN JUGGLE FIX — top-bin shots RISE during their initial
  flight (you must kick up to aim at the top corner), and the old
  "any rise > 2 studs/s = juggle" rule misread them as juggles, so the
  keeper stood still ("JUGGLE — SAFE") and the ball went into the top
  bin. A real juggle is a controlled ball and never reaches shot speed,
  so a rising ball at shot speed (≥ MIN_DIVE_SPEED) is now a SHOT.
•  🦘 TOP-BIN AUTO-JUMP — researched mechanic (community observation;
  the fandom GK guides publish no reach numbers, this is how keepers
  save top corners in-game): a keeper who JUMPS and then DIVES reaches
  HIGHER than a flat dive. The AI now fires a local jump RIGHT BEFORE
  the dive whenever the predicted impact is ≥ TOP_BIN_JUMP_HEIGHT
  (4 studs) above the keeper's root. Works at all four dive sites
  (loft catch, punch out, slow save, main dive) with one shared rule.
•  Safety: both local jump methods (ChangeState(Jumping) = the
  standard LocalScript trick, Jump() = server API many games allow
  from clients) are pcall-wrapped — if the game restricts both, it's
  a clean no-op and the dive fires exactly as before. 0.6s cooldown
  so it never jump-spams; low balls never jump.
•  Config: AUTO_JUMP_TOP_BIN (master switch — turn off if the game's
  dive animation already hops), TOP_BIN_JUMP_HEIGHT, AUTO_JUMP_COOLDOWN.
•  Console prints "🦘 TOP-BIN JUMP (impact N studs up)" when it fires.

v2.36 "Full Roster Intel"

## v2.36 (every in-game style researched + verified detected)
•  📋 FULL ROSTER VERIFIED — all 18 in-game styles (Isagi, Gagamaru,
  Reo, Chigiri, Bachira, Nagi, Sae, Aiku, Barou, Yukimiya, Rin, Don
  Lorenzo, Kaiser, Shidou, Luffy, Ronaldo, Dio, Ichigo) now have a
  CHAR_PROFILE (how they threaten: aerial flag, bomb threshold, height
  bonus, signature) + detectable moves + counters. Simulation S17
  spawns one move per character and verifies ALL 18 are detected.
•  🔎 RESEARCH UPDATES (Blue Lock Skibidi fandom + fan wikis):
  - BACHIRA is IN GAME now (10%) — profile updated from "UPCOMING";
    Schizophrenic Shot BENDS MID-AIR (forced read), Flour Ginga
    ignores hitboxes, Little Bee = 10s speed boost.
  - YUKIMIYA's Gyro Shot is a HIGH shot with a violent late curve —
    profile now aerial + 6 studs height bonus.
  - CHIGIRI's 44° Red Panther Sniper is a TOP-CORNER placement shot
    (low power + curve, 19m left flank) — snipe counters now reach 6
    studs higher.
  - RIN = "highest accuracy in-game, timing-charged" (Puppeteer =
    forced read, already armed); NAGI Black Hole Trap = instant
    control from any pass; DIO Time Stop = 3s (shot comes after);
    LUFFY quest-unlock kit (Roc Gun / Red Hawk autogoal); GAGAMARU
    Spring Jump; ISAGI Meta-Vision + Perfect Impact timing.
•  ⚠️ HONEST LIMIT: the fandom does not publish Ichigo's in-game move
  names (new character, no wiki page). His "bankai" entry stays; if a
  move effect you see in the console is never detected, send the exact
  effect name and it's a one-line add.

v2.35 "Sae / Chigiri / Bachira Detection"

## v2.35 (Sae + Chigiri + Bachira detection widened)
•  🔍 NAME ALIAS NET — the detector matches on the in-game effect
  name, and those names can vary by spelling. Every plausible variant
  for the three styles now resolves to the same counter:
  - SAE: Curve / SignatureCurve / Perfection / YoullNeverSurpassMe /
    Elastico / Heel / Celestial / PerfectPass / Turn
  - CHIGIRI: PhantomSnipe / Phantom / 44Snipe / FortyFourSnipe /
    HighSpeed / SpeedShot / Accel / SpeedBoost / Panther
  - BACHIRA: Ginga / Schizophrenic / ScissorKick (singular!) /
    Scissors / BeeShot / LittleBeeShot / Monster / Bee
  - "44Snipe" and friends survive the digit-prefixed name too.
•  🎯 COUNTERS for the last meaningful reads: SAE magicturn/turn
  (MAGIC TURN FEINT — he's changing angle, don't trust the turn frame),
  CHIGIRI speedster (WING RUSH READ — flank threat, faster tier) and
  pantherrevenge/panther (PANTHER PICKUP — the ball's path is NOT a
  normal pass), BACHIRA monsterdribble (MONSTER DRIBBLE READ — his
  dribble ignores hitboxes, don't over-commit to the early angle).
•  ✅ 16-scenario simulation passes with zero loop errors, including
  a new S16 that spawns SaeCurveShot / ChigiriPhantomSnipe /
  BachiraFlourGinga and asserts each arms its counter.

v2.34 "Ownership / Full Roster / Curve Hold"

## v2.34 (network ownership + full-roster detection + Rin curve hold)
•  📡 NETWORK OWNERSHIP POSSESSION — the authoritative signal: when
  the server gives a player CONTROL of the ball, that player's root
  becomes the ball's NetworkOwner (replicated, readable). Teammate
  owns it => NEVER dive (no more diving while our guy has it);
  opponent owns it => full threat even if a teammate is standing next
  to the ball (the old nearest-player heuristic used to flip on that).
  If the game leaves NetworkOwner nil, the distance heuristics take
  over exactly as before. Also used for shooter credit (who kicked).
•  🌀 RIN CURVE HOLD (why it STILL slipped in): the old abandon rule
  dropped the curve prime after just 3 frames (50ms) on the other
  side — but a curve shot's FEINT spends 0.15-0.3s on the wrong side
  BEFORE it bends, so the prime died mid-feint, the read re-formed
  post-break, and the dive arrived late. The prime now lasts the whole
  move alert and is abandoned only when the ball PROVES straight:
  20+ frames (≈0.33s) clearly ≥20 studs on the other side at shot
  speed. CURVE_COMMIT_LEAD 0.20→0.30 (the dive animation needs more
  lead on a late break).
•  📋 FULL-ROSTER SHOT COUNTERS — every style's shots now have a
  counter: Isagi directshot, Sae celestialdestruction/offbalance,
  Yukimiya gyro alias, Luffy rockets (wild-path read), Gagamaru
  scorpion, Chigiri highspeedshot (was undetectable — it had a counter
  but no detection entry!). All 25 styles keep their CHAR_PROFILES.
•  ✅ FULL SCRIPT CHECK — static audit: 0 forward references, 0
  duplicate declarations, 0 missing CONFIG keys, all shot moves have
  counters; 15-scenario simulation passes with zero loop errors.

v2.33 "Yukimiya Gyro Detection"

## v2.33 (Yukimiya shots)
•  🌀 GYRO SHOT DETECTION — "YukimiyaGyroShot" / "GyroShot" now arms
  "GYRO LATE BREAK": researched signature = a HIGH shot with incredible
  spin that "at first looks like a miss-kick but curves at a VERY SUDDEN
  moment", bend side depends on which side of the field he's on.
  Counter: forced 2-frame read (never trust the opening direction) +
  commit 6 studs earlier (the late break needs the dive already moving)
  + extra height (it's a high shot that bends).
•  ⚔️ SWORD SCREW — "YukimiyaSwordScrew": vertical rotation — the ball
  DROPS hard then rockets into the top corner. "DIP-RISE WALL": forced
  read + reach 10 studs higher + bomb threshold 125 for the launch.
•  SAVE_EVERYTHING was ALREADY true in this file — if your Roblox copy
  shows it false (and dives/trajectory feel dead), you're running an
  OLDER paste: re-paste this file.

v2.32 "Curve Commit / Fake Hold / Fast Hands":
•  📐 CURVE COMMIT — a primed curve shot (Rin Killer / Sae Curve)
  commits the keeper to the prime side 0.2s BEFORE the normal window
  (the dive takes ~0.4s; the break lands at 0.5-1.0s of flight — a late
  commit to the true side always arrived after the ball). Abandoned
  only if the ball persistently goes the other way (3 frames ≥ 18 studs
  opposite), then the normal read resumes.
•  🎭 FAKE HOLD — a fake is a tap whose pop stays under 70 and then
  bleeds >15 studs/s; a real strike always peaks at release speed even
  when it bounces. "FAKE — HOLD" = no dive while the bleed is live;
  real shots cost zero reaction time.
•  🖐️ FASTER HANDS — BASE_DIVE_TIME 0.40→0.32, COMMIT_SPEED_FACTOR
  0.12→0.16, QUICK_READ_FRAMES 2→1, COOLDOWN_TIME 0.7→0.5.

## v2.31 (Rin's Killer Shot slipping in + every style now detected)
•  🧵 RIN KILLER SHOT FIXED — the move the game actually spawns
  ("RinKillerShot") was NOT in the detection table (only old community
  names crashshot/kill were), so it got NO counter: no left prime, no
  forced read — a generic read against a STRONG curve, and it bent
  past the keeper sometimes. Now: "RIN CURVE WALL" = prime LEFT (it is
  Sae's curve but STRONGER — same left bias, harder break) + forced
  2-frame read + height bonus + lower bomb threshold.
•  📋 EVERY SKIBIDI STYLE'S MOVES DETECTED (from the Skibidi wiki kits):
  Rin full kit (Killer Shot, Inhumane Off The Ball, Godspeed Kill Shot,
  Quiet Down), Chigiri (44° Phanter Snipe, High-Speed Shot), Nagi (5
  Stage Volley, Jumping Turn, Skull Rush), Sae (Never Surpass Me, Half
  Baked), Barou (Shadow Dribbling, Black Flash, King's Return), Kaiser
  (Get On Your Knees, Pass Me, Dash), Don Lorenzo (Yo Michael,
  Unmatched Agility...), Aiku (all 5 — none existed before), Devil
  Fruit User (Jet Kick, Lighting Trap; Gomu-Gomu family re-attributed
  from Luffy — his kit is Gear 5), Luffy (Roc Gun, Red Hawk...),
  Ronaldo (CR7 Kick, autogoal = UNSAVEABLE-HOLD), Reo (Copy =
  WILDCARD READ). Each has its own counter: curve primes, forced reads,
  jump walls, steal alerts, stun-holds, unsaveable-holds.
•  🐛 PREMATURE-FORWARD FIX (the other half of the Rin miss): the
  SLOW-BALL branch judged speed by the smoothed EMA, which lags ~4-6
  frames after a release — a FAST point-blank shot (Rin's range!)
  read as "slow" for its first frames, fired a premature Forward
  dive, and its 0.7s cooldown blinded the keeper to the real side
  dive. The SLOW branch now requires the RAW speed to be slow too.
•  The HUD already shows who it's reading (⚔️ style) and which counter
  is armed (⚙️ counter name); the console logs each detection.

## v2.30 (team tag colors + dive improvement)

## v2.30 (team tag colors + dive improvement)
•  🎨 TEAM TAG COLORS RESTORED (green = your team, red = enemy,
  gray = unknown side) — the team-tracker section had been pasted
  TWICE; the name-tag code read the FIRST copy's table while the live
  refreshTeams updated the SECOND copy's table, so tags could never
  see a team and stayed gray. The duplicate section is gone; every-
  thing now reads/writes the ONE live table. No other logic touched.
•  📏 NEAR-POST DIVE BIAS (researched GK guide: "Move toward the
  near post when the attacker approaches from a wide position"): a
  wide striker shoots ACROSS to the near post far more often than at
  the far corner. While the threat is ≥ WIDE_STRIKER_LAT (18 studs)
  wide, the FAR side of the read costs ONE extra confirm frame. It is
  a timing nudge only — the read can still flip either way, so a true
  far-post shot is met one frame later (≈17ms), never blocked.
•  Config: WIDE_STRIKER_LAT.

## v2.29 (slow shots going in unchallenged)

## v2.29 (slow shots going in unchallenged)
•  🐌 SLOW SHOT DETECTOR — a released shot slower than the full
  side-dive tier (20-59 studs/s) is now DETECTED the frame it's read:
  on target + coming at us + not carried/dribbled/juggled/own-team.
  - Early HUD warning: "SLOW SHOT INCOMING — MOVE!" while it's still
    out of range, so the keeper steps up instead of watching.
  - Forward save from a WIDER window (34 studs / 18 lateral / 20 height
    vs the old 30/14/15) — a slow ball gives time to move, so the
    tolerances are bigger.
  - Fires the existing Forward dive (FireServer "Forward") with the
    normal cooldown; un-arms itself if the ball speeds up into
    full-dive territory or stops being a threat.
•  Config: SLOW_SHOT_REACH / SLOW_SHOT_LATERAL / SLOW_SHOT_HEIGHT.
•  🐛 GRAVITY SIGN FIX (the REAL reason slow shots went in): the
  trajectory simulator read workspace.Gravity RAW. Roblox's value is a
  POSITIVE magnitude (196.2) that the engine applies downward — the
  simulator integrates it straight into +Y-up velocity, so long flights
  were predicted FLYING UP. Fast shots crossed the line before the fake
  climb got high (saved fine); slow shots flew 100-400 studs "above the
  bar" in the prediction and were ruled WIDE — the keeper stood still
  and the slow shot rolled in. Now: gravity = -math.abs(g).
•  🐛 MYTEAMLABEL FUNCTION SHADOW FIXED: a pasted
  `local function myTeamLabel()` accessor shadowed the real string
  variable and returned the function itself, so stateInfo.team held a
  FUNCTION and updateHud's string.format("%s", ...) crashed with
  "bad argument #2 to 'format' (string expected, got function)" every
  frame while tracking. The accessor is deleted; the name resolves back
  to the live string.
•  🐛 PLAYER-LEAVE CRASH FIXED: the PlayerRemoving handler referenced
  playerVelStore / playerShotStats before their `local` declarations
  (nil globals) — the first disconnect crashed the cleanup. Both
  declarations moved above the handler (no logic change).

## v2.27 (Shidou backheel + Dio/Stand research)
•  BACKHEEL COUNTER — a backheel shot is a FEINT: the animation faces
  one way, the ball pops out the other with a LATE curve. Fixes for
  "misses backheel shots":
  - Late-break curve tail: Magnus force holds full strength for the
    first 0.5s, then decays SLOWLY (0.22/s) so the late break at
    1-1.5s stays in the prediction (old 0.45/s decay killed it).
  - CURVE_CAP 220 -> 260 for late backheel breaks.
  - Backheel counter = forced 2-frame read: wait for the release, then
    commit to the ball's TRUE direction (never the animation direction).
•  STAND USER (DIO) RESEARCH — Timestop lasts 3s and the shot comes
  AFTER it ends: timestop/barrage counters now arm the AI for 6s (not
  4s), and the late-spike detector catches the frozen->released speed
  explosion when time resumes. Stand Shot / Remote Volley armed 6s.
• Shidou style data: explosive close-range striker — Backheel Shot
  (feint), Demon Rush, I'LL BEAT YOU UP (steal), Big Bang Drive
  (awakening bicycle kick), Demon's Wings (awakening double jump).

v2.26: RELEASE GATE — wait for the ball's release, not the opening
      animation (the official GK guide's core rule; kills feint dives)

v2.25 (SKIBIDI-specific data — v2.24 had accidentally used Blue Lock
Rivals research; re-tuned to the actual Skibidi wikis):
• Speed classes re-tuned to Skibidi's real roster data: Ronaldo 115
  (S-tier), Kaiser 125 (World Class PRECISION/quick-release), Rin 125
  (S+ meta, timing-charged precision), Isagi 135 (Common starter,
  Perfect Impact timing), Shidou 130 (close-range pressure, not the
  long-range sniper), Barou 125, Ichigo 128.
• Skibidi-specific moves added: Isagi Directed Back Heel + Luck Shot
  (signature power shot → LUCK WALL snap), Rin Puppeteer Control
  (chargeable → forced read), Bachira Flour Ginga ("ignores all
  hitboxes") + Little Bee (10s speed boost → wing anticipation).

## v2.24 (trajectory rebuild + speed research)
• 📐 TRAJECTORY SYSTEM REBUILT:
  - ADAPTIVE TIMESTEP — the physics step shrinks as the ball speeds up
    (200 studs/s bombs integrate ~3x finer than slow passes), so goal-line
    crossing and impact interpolation are much sharper on fast shots.
  - MAGNUS CURVE MODEL — a real curve holds full sideways force for the
    first second of flight, then decays (physically how Magnus force
    works) instead of fading from the start.
  - ROLLING FRICTION — a ball on the pitch decelerates after bounces, so
    post-deflection predictions stop "skating forever".
  - PATH DOTS now extend 0.5s PAST the impact so you can see where the
    ball is going after it gets past you.
• 📊 SPEED RESEARCH — every style's bomb threshold re-tuned from the
  community speed data: Kaiser Impact = fastest shot in the game
  (keeper left "completely stunned"; best momentum retention) → 118 +
  SNAP; Final Shot / Direct Shot top speed tier → SNAP; longest-range
  tier (Big Bang Drive, Joker, aerial I am Nagi, Final Shot) lowered;
  Shidou 125 (Demon Wings flow increases shot speed), Dio 115 (time
  stop), Luffy 125, Chigiri 128, Kurona 125, Ichigo 122, Kunigami 122,
  Bachira 130, Isagi 128, Nagi 125, Otoya 135.

## v2.23 (style sync fix)
• 🐛 NAME TAGS NOW LIVE — the tag renderer runs from the main loop
  (self-throttled to 0.5s). New players get their style tag on join,
  and style changes (yours or anyone's) update within ~1.5s. Previously
  tags were drawn only once at boot, so new joiners had no tag and style
  changes kept showing the OLD style.
• 🧹 PlayerRemoving cleanup — leaving players clear their style,
  velocity, and shot-power data.

## v2.22 (full line-by-line audit + deep GK-guide research)
• 🐛 FAKE GOAL FIX — a "concede" now requires a CREDITED SHOT within the
  last 2.5s AND the ball crossing at speed. Post-save rebounds, wide
  balls crossing outside the posts, and carried balls no longer count
  as goals/our goals.
• 🐛 DIVES BEFORE THE SHOT FIX — new CARRY CORRELATION: when the ball is
  close to a player AND moving WITH them (any speed), it's carried/
  dribbled, not shot — no dive. This also kills shot FEINTS (animation
  without a release: the ball stays glued to the fake's feet).
• 🐛 SILENT BUG — refreshTeams referenced an undefined "character"
  (TeamColor source was dead); fixed.
• 🎈 AERIAL BIAS (researched GK guide: "if shoots comes from air just
  jump... don't do left or right dive, try front dive") — a high,
  descending ball arriving near center is now met with a Forward save.
• 📚 MORE RESEARCHED COUNTERS — Sae Curve Shot ("always goes left" → the
  read is PRIMED left before release), Nagi Heavy (chargeable: forced
  read), Barou Long Shot/Devour, Rin Crash Shot/Kill (close = high: jump
  wall), Bachira Bon.

v2.21: CRITICAL FIX — tNow forward-reference crash (the LOOP ERROR spam)
v2.20: hitbox-aware saves, GK move prediction (aim at where you'll be)
v2.19: striker move prediction  •  v2.18: charge read (juggle tell)
v2.17: true trajectory physics (gravity + bounce), LOFT CATCH
v2.16: Stand OP, extreme speed, 84-move detection, full roster
v2.13: punch out  •  v2.12: juggle/rainbow detection
v2.10: BOMB/QUICK urgency tiers  •  v2.9: in-hand saves, shoot forecast
v2.8: team/possession  •  HOTFIX 2.16.2: the commitBonus nil-add crash

