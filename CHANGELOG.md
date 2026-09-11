# Changelog — `auto` (Zero-Latency Goalkeeper AI)

Every release note the script used to carry in its own header comment, newest
first. The header now holds only the current release + the essentials; this file
is the history. Entries were written against the in-game misses each version
fixed, so they double as the design rationale for the thresholds in `CONFIG`.

---


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

