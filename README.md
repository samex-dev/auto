# auto — Zero-Latency Goalkeeper AI

One file: [`auto`](auto). A client-side (Luau / Roblox) goalkeeper co-pilot for
Blue Lock: Skibidi. It does **not** read shot animations — it reads the **ball**:
position history → velocity + curve → a real trajectory integrator (gravity, pitch
bounce, roll friction, Magnus decay) predicts where the ball crosses the goal
line, and a stack of honesty gates decides whether diving is actually worth it.

Everything is tuned from one `CONFIG` table near the top of the file; version
notes for each threshold live in [`CHANGELOG.md`](CHANGELOG.md). The move
roster and its per-style counters are grounded in the fandom research preserved
in [`docs/GAME_RESEARCH.md`](docs/GAME_RESEARCH.md) (every style, the GK guide,
chemical reactions, and a dated addendum of what to watch for in new updates).

**The boot curtain** (v2.64, tuned v2.65): before anything loads, eight seconds of neon purple, dead center —
credits to **Joe** (who helped make the auto dive) and **itslapeace** (field testing and
the advice, the streets' metas) — rises in, counts the load down live, and backtracks out
the bottom exactly as the keeper goes online. Fully guarded and step-counted: it decorates
the boot and is structurally unable to block it.

**v2.65, the wider net**: bait detection is no longer one shape — chasing shooter, a LOOSE
soft roller in the box (the two-man one-two nobody is attached to), and a 4-second bait
memory, so a shooter who has fooled you once is held on sight. Teammate discipline got its
proactive half: a ball FLYING to our own man at collectible speed is a giveaway, not a
threat — refused at both commit gates — and every own→opp flip re-arms the read fresh. And
style detection meets every name like it belongs: tuned row where the book has one,
announced universal 2-frame stance where it doesn't (Santa Claus edition).

**v2.66, the false-dive killers**: the friend's field test was literal — "when he
dribbled it false dived" — and the net learned the physics of it: a poked ball that is
still riding with its owner (10 studs, half a second, under 95/s) is a TOUCH no matter
how loud the speed spike is; a read that disagrees with itself by one strike is a TAP and
buys exactly one beat of patience; and a man who baits twice gets flagged — his soft-shot
bar raised for twenty seconds, because a bait farmer should pay a tax, not win the
rematch. The keeper also stopped hiding its maths: the handler's AIM is projected onto
the goal line as a reticle while he dribbles, fast balls get their magenta streak across
the pitch, and line 1 of the HUD carries the predicted crossing delta, the live curve and
the aim — the same numbers the decision runs on, painted on the field. (v2.67
postscript: the FIELD PAINT did not earn its keep on phone screens — the reticle, the
streak and the HUD maths strip were stripped out. The wider net and the tax stayed.
What replaced the paint is stronger than paint: every refusal — held OR betrayed — now
feeds one counter.)

**v2.67, the bait engine goes pro**: bait detection stopped being a list of shapes and
became a ledger. A dive whose ball QUITS before anyone touches it — the 60/s "shot" that
bleeds to a stop at the edge of the box — now counts against its shooter exactly like a
held ball (DEAD-BALL REGRET, armed before the keeper's own walk can "save" the evidence
and before the idle sleep closes the case). A flagged baiter pays THE TAX: his window for
buying an early leap shrinks by 20%, so his taps arrive at a set keeper while a real
strike still gets met — the tax delays, never denies. The fake-shot system's holds no
longer double-charge the ledger, a memory can never feed itself, and the touch tier keeps
its orbit rule (pokes ride with the foot; strikes separate). Thirteen moves that used to
meet the generic read got dedicated walls — the trap-shot loft, the flip that IS the
second act, every feint dribble, the giveaway passes — while the alias spellings were
proven to route to their primary's wall by design. And the suite went to 100 scenarios:
a full BAIT DETECTION GAUNTLET — every soft speed, every dart length, every shape that
must STILL be dived on, so "more bait detection" never means less goalkeeping.

**v2.68, the fandom-taught smells**: the research pass came back with the game's OWN words for
the friend's complaints — fake-kick pops that "serve as a good fake shot, trick goalkeepers", a
juggling kit with "feints to fool the goalkeeper", a two-man reaction whose shot "completes AS the
pass reaches" the striker. The keeper learned both noses: every fake kick that dies short now
enters the baiter's ledger (one episode per attempt — bait that ALMOST worked costs the same as
bait that did), and the one-two into a first-touch volley is no longer eaten by the bait net: the
watched receiver gets exactly ONE reaction strike, met frame-one, promise consumed forever after —
farm it with a fake and the net is back on the next touch. The reworked snake defender got his
knuckle chased LIVE and his "100% block" territory answered the only honest way a keeper can: the
tackle fence holds the charge OUT of the zone built to eat it. 106 scenarios, all green — and the
count is the TRUE one, audited against the runner, not the other way round.

**v2.69, the newcomer protocol**: Naoya came, Naoya got nerfed — nine days from launch code to apology
code, and not one wiki has his Skibidi moveset. The keeper doesn't guess at ghosts: every "Naoya<Move>"
the game spawns self-reports to the console and arms the NAOYA WALL — quick read OPEN (his release is
instant), first frame NEVER trusted (his kit is afterimages, and frame one of an afterimage man is a
lie). Awakening got the same discipline-from-proof: an unknown part that calls itself a cutscene wakes
the watch for ANYONE, and while a handler's promise is live his next 140+ rocket reads BOMB — awakened
shots are the strengthened version of the move the cutscene just announced, and the keeper commits a
full beat early on nothing more than that promise. And the ledger got teeth for regulars: get flagged
twice inside a minute and the grudge stacks — a +4 bar that never fully forgets. 110 scenarios, bench
faster than v2.66's, and one research rule carved in stone: Blue Lock Rivals and Blue Lock Skibidi are
different games — shared souls, separate numbers, and only THIS game's console lines key the rows.

**v2.70, how fast the ball WENT**: a dive decision that only reads the ball's
speed TODAY can be fooled the way every striker in the game already fools it —
wind up huge, let the ball bleed across the pitch, arrive soft. The engine now
carries a launch meter: the hardest raw speed since THIS exact strike, ceiling
guarded (a 300+/s teleport snap-back is physics noise, never a "rocket"),
reset on every new credit. A ball that LEFT the boot at 110+ is a shot forever,
no matter how cool it reads at the keeper — every soft bait tier stands aside,
and the number itself prints on the dive line (`⚡Launch: 130`) so the friend
can finally see what the keeper saw. Barou's documented feint — "you can feint
Predator Shot by looking down... fool the goalkeeper into diving", his chop is
"a feint into a chop dribble" — became a catchable shape of its own: a SNAP
promise that rides out 1.2s with no strike credited behind it is a FAKE WIND-UP,
logged on the spot and charged as one bait episode to the caster's tab. Two
air-swings and his next 62/s roller meets a 67 bar instead of 55 — the farmer
bankrupts himself, while his REAL chop still gets met frame-one. 115 scenarios,
bench unchanged, and the meter's ceiling keeps the fixtures' own reset spikes
from ever being read as launches.

**v2.71, read the KICK, not the flight**: faster reactions, bought where the
evidence is already in hand. A strike credit — the ball going still→motion AT
the shooter's feet at or above the launch-exempt bar, on target, inside 70
studs — IS proof the boot connected, so the keeper commits on the RELEASE
FRAME instead of waiting for the flight to enter the commit window: a 130/s
rocket is now read @57 studs out, eleven studs earlier, at zero added risk
(every ball that hot has already escaped the bait net — same meter, same
number). Sub-bar pops answer to the pop-confirm exactly as before. Two more
bait shapes close in: **RECLAIM** — spike, sprint, kill it dead at his own
feet, the friend's original "get it back" tell as a complete shape with no
clock to beat (one episode, once per strike, and the stall holds regardless
of what the speed read says); and the **FEINT PAIR** — two credited taps from
the same man inside 1.1s that gained less than ten studs of ground is not two
shots, it's one wobble, charged before the third tap even exists. Travel, not
speed, sees it: no single-frame gate can. 119 scenarios, bench unchanged, and
the friend's paste check just got a new tell — dives on proven launches now
carry `| ⚡ LEAD` in the log.

**v2.72, trust the kick — verify the side**: the friend tested and reported
both wins and the one new flaw: "keeps diving sideways." The release lead had
been buying an early SIDE as well as an early dive — but at lead range the
crossing number is a half-second PROJECTION of jitter (Roblox balls inherit
their shooter's lateral motion for a frame or two), and a keeper guessing
corners from a guess is how you let in shots you read. Now a lead commit may
only pick a side once the crossing sits past the LONG READ band AND the same
side held a full confirming frame; inside the band the lead dives MIDDLE —
same early beat, goal-heart protected, make the striker place it. A true
corner still gets its early left/right dive (S122 guards the canary in both
directions). The lag answer is a TRAJECTORY CACHE: the integrator no longer
re-simulates 3.5 seconds of flight every frame — steady straight flight reuses
its path (new credit, ±8/s speed, or a live curve accel re-integrates), which
is exactly the frames the "still lags" devices were paying ~210 steps a frame
for nothing. Decisions stay every-frame; only the redundant projection is
skipped, and `SIM_CACHE_MAX = 0` puts the old cadence back if a future tuning
ever needs it. 121 scenarios.

**v2.73, the shooter's playbook**: the friend asked for shot-by-shot knowledge
in the words he'd use in a Discord — "know each shot and where to dive to —
like if it's a cr7 kick dive forward" — and the game handed it over: the
effect literally spawns as `cr7kick`. Per-move DIVE SHAPE now rides the move
table (`shape = "forward"` rows for the CR7 kick, Oh-Cristiano, and the Jet
Kick — straight seam cannons all three) and lands in the decision *through the
alert itself*: no new per-frame lookup, no upvalue tax. When the named move is
live and the crossing reads seam (inside PLAY_FWD_BAND × the center tolerance,
under PLAY_FWD_MAX studs), the keeper POUNCES — forward, both arms, goal-heart
protected — instead of gambling a side on a projection; the dive line carries
`| 📖 FORWARD`. Ronaldo's autogoal G keeps its unsaved-anyway HOLD policy —
the playbook refuses to dive at it, by design. And the band-hold that killed
the lead's sideways dives is no longer lead-only: the coin-flip fence moved
from 85 studs IN to `SIDE_GUESS_DIST = 38` — mid-range side guesses inside
the center band are holds everywhere now, with live curve chases and
side-primed counters exempt (they carry their own lateral proof). The
trajectory cache keeps compounding: bench **30 ms**, down from 45. 124
scenarios, three of them written from the friend's own sentences.

**v2.74, the reach ring**: "It still dives sideways — also improve the diving
too," the friend said, and the last honest source was the NEAR zone itself: a
78/s ball drifting 5–7 studs inside forty gets a side dive by v2.73's rules,
and that dive is the goal you nearly gift — hands from the feet had it. The
fence is now a continuous trust curve: past SIDE_GUESS_DIST the band is
centerTol×1.8 (centerTol×2.6 while a trick-shot alert is live — backheels and
balloons lie about their lateral); inside it, any ball at or below
NEAR_SMOTHER_SPEED whose crossing stays within centerTol+SIDE_NO_DIVE gets
`🪹 IN REACH` and a step, never a dive. Above that pace the ring stands down —
S02's fast near corner keeps its dive to the letter, and the suite enforced
that philosophy the day it was written (first cut ate S02; the test was right,
the feature was wrong). 126 scenarios; S126 fails the v2.73 build in exactly
the way the friend described — sideways, at a ball that was already parked in
front of the keeper.

**v2.75, the roster keeps growing**: "check if Naoya is there now" — he is.
The code trail dates him exactly: `naoya` 50k launch code Sep 5, `hidoi na`
Sep 7, then `NaoyaNerf` + `PATCH` Sep 12; the script had carried his wall
since v2.69 on a hedged guess, and this week's evidence retires it — the
launch-week code pattern (same week as `Mugetsu`, an Ichigo FORM, echoing
`BANKAI`/`DEMON`) marks him as the game's next crossover striker, a kit whose
whole identity is selling frames that lie. So v2.75 wires him into the
TRICKY_BAND machinery built for exactly this: his alerts — even the unnamed
effects caught by the `Naoya<Move>` catch-all — widen the far trust band from
centerTol×1.8 to ×2.6, logged `🃏 TRICKY READ — his kit is built to sell it`,
with the engine's freshness convention (2.5s) gating it. The hold is patience,
not panic: S128 shows the keeper waiting nine more studs, then diving the
CONFIRMED corner anyway. `mugetsu` joins MOVE_INFO pre-keyed off the code
trail (effect names still self-report in console). And the scale audit the
ask implied — net, posts, stadium: the fandom publishes ZERO dimensions for
any of them (checked again; the wiki is codes and tiers), which is precisely
why the script never hardcodes the goal: it measures the real posts, crossbar
and mouth from Workspace every 2 seconds, sanity-bounded and self-healing.
128 scenarios; S128–S129 fail the v2.74 build.

**v2.76, "it needs to see the bait"**: the user's own gameplay clip got read at
the pixel level (screenshot-API + OCR, no video tools anywhere near it), and the
chat typing inside it — *make the bait detection better* — became the feature.
The `.place-and-shoot` farmer dances around a DEAD ball before tapping it: no
speed tier can convict that, because the kick honestly starts from zero. So the
keeper now watches the BODY: while the ball rests, the nearest field man inside
seven studs gets his time-and-distance tallied, and a dance that ends in a
credited kick is charged as a bait episode on the spot. A stander banks seconds
but zero studs of travel — the distance floor is the part nobody can fake.
130 scenarios; S130–S131 fail the v2.75 build.

**v2.83, "the keeper who knows the moment"**: the curtain gets a **LOAD NOW**
button — one press and the eight seconds are gone (S154). BAIT 3.0 adds eight
shapes on top of Bait 2.0, each with its own gate signature so a quiet ball only
pays for the reads it earned: power pull (a credited bomb that drags backward),
double pull, carry stall, walkaway, bleeding cross (judged on geometry, not
trajectory), circle, class soft, and handoff (a credited "shot" a second man
picks up — ownership is re-attributed so the chaser tier and the ledger follow
the ball). COUNTER 2.0 lets move counters carry **research**: `sideBias`
commits a side in flight (Sae's and Rin's documented left habit, Shidou's
back-aimed `formless`), `trust` gives a named move exactly the window it
deserves, and every row's `note` prints why. TRAJECTORY 3.0 fixes five geometry
lies: the reset guard (a one-frame teleport is not a 1300/s strike), apex settle
(a climbing ball has no crossing height yet), frame graze (a hair outside the
woodwork is one deflection from on target), time-scaled reach (reach is travel,
and travel is time), and sticky side (one jitter frame can no longer flip the
commit). Plus MATCH SENSE — 17 match-level reads (tilt meter, back pass, shade
line, set piece, one-on-one, second ball, crowd, form) — and the CONCESSION
BANK, which counts where a man BEATS us rather than where he aims. 161/161
scenarios.

**v2.82, "the keeper who adapts"**: the keeper breathes with the device. One
scale (×0.75–×1.5) sampled per frame from live ping, the measured alert→motion
gap, and frame rate — applied to every time window, so the fake confirm widens
on a 120 ms link and tightens at 60 fps. BAIT 2.0 adds the two fakes the v2.81
net let through, both read off the ball's own motion history: the sprint that
quits (APPROACH STALL — dead ball 11–26, man at it, inside 0.8 s of the stop)
and the 180° turn over a dead ball (WHIP FEINT — two clean heading samples
reversing inside 0.45–1.2 s). The ledger learns the man's CORNER: three aimed
crossings in one house is a habit the stance consults on a coin flip (PATTERN
LEAD). 152/152 scenarios.

It also keeps its **own console** (🖥️ LOG button, or **F2**): every line the
script prints, captured at the source before the log budget can mute it,
time-stamped and colour-graded, with **📋 COPY ALL** so a bug can be pasted
straight out instead of recorded on video and scrubbed through. The button
turns red and counts the errors itself. Off by default — it paints nothing
until you open it.

**v2.81, "read the swing"**: the keeper reads the ANIMATION. A shot-shaped skill
announcement over a ball that never moved = SWING FAKE — episode banked, ledger
counts a swing, tax upgrades by itself (the alert stays ready for the follow-up;
snap-class swings are billed once by the v2.70 watchdog). A NAMED tricky strike
(backheel family) is TRUSTED for 1.1s against the soft nets — "never saves
backheel" ends. A flick by an aerial-kit man (gaga mains) holds the DIVE until
the pop is struck — the scorpion hits a standing keeper, not a spent one. And a
low hard drive commits to its own crossing (FLAT STANCE) — no more middle-stand
while it crosses nine wide of the chest. 146/146 scenarios.
**v2.80, "know thy man"**: the keeper keeps a per-name ledger (ST.prof) of every
shot, dribble, pass, save and goal each opponent has traded with him, all match,
slowly decaying — and names the pattern in the console (FINISHER, SNIPER,
DRIBBLER, FULLBACK). A known shooter is read a step earlier (×1.03-1.06 commit
reach); a dribbler's long launches must sustain a beat before buying the leap —
his own match says the pull-back is coming soon; a fullback's rare strike waits
like a baiter's. One line per man per class change, throttled, telemetry-only —
no HUD paint, ever. 141/141 scenarios pin it.
**v2.79, "the habit, priced"**: bait detection got its two prices — a GRADUATED commit tax by episode count (14% / 20% / 28% later, replacing the flat 20%) and a SPIKE-SUSTAIN gate: three bait episodes in the window and the man's one-frame launch no longer buys an instant leap from beyond 60 studs (their console's `DEAD BALL REGRET @125` x2 was this exact theft). A full re-sweep for Naoya found… no Naoya: the wiki's 24 pages carry zero hits and the Sep 11-12 rework published no moveset, so the dated catch-all stands; press-kit overviews measured the whole pitch island (goals at the void edge, ~1.5:1 — v2.77's model confirmed, fallback 16×8 kept). 138/138 scenarios green.

**v2.78, "the half-second, reclaimed"**: the user opened the dev console mid-match and photographed the script's own log — it confessed two faults (OWN→OPP wiping the read 4× in 2.5 s at a loose ball; the paint guardian flapping every second on their 48 fps phone), and both are fixed: a 0.35 s flicker guard, a 3 s recovery dwell, plus `BASE_DIVE_TIME 0.32→0.26` and `COMMIT_BASE_DIST 25→27` so every shot is met earlier. "More counters for Rin": the game prints its cast names to the console, so his `RinRun` sprint is now keyed — stance gains `quickSpeed 108`, and a new SPRINT READ steps 6 studs up his run-lane with the forced 2-frame read on the finisher. 136/136 scenarios green.

**v2.77, "the goal, out loud"**: asked to check how big the stadium and the
posts are, the clip's limits met reality — OCR reads text, not geometry — so
the game's own match screenshots got pixel-audited instead (crop, upscale,
luminance-variance bands). Verdict: a flat pitch island in open sky, goal at
the void edge, mouth ≈2:1 at ~16×9 studs — the 16×8 fallback survives,
validated. And the keeper now says what it measures: one console line per goal
state, measured or fallback, so the next video carries the numbers itself.
132 scenarios; S132–S133 fail the v2.76 build.

## What it does, in order

| Step | What happens |
| --- | --- |
| Track | Finds the ball once (event-driven `DescendantAdded` + throttled fallback scan), samples its position history. |
| Sense | Two-window velocity/acceleration estimator (fast warmup, curve deadzone + cap), ping-compensated. |
| Predict | Scalar trajectory integrator: where the ball crosses the line, closest approach to where the **keeper will be**, time-to-impact. |
| Decide | Possession (network `NetworkOwner`, else carrier/carry/last-shooter), controlled-ball gate (carried ≠ shot), carry correlation, fake/bleed detector, receiver gate (a pass is not a shot), honest wide/over ruling, urgency tiers, a handler stance for EVERY style in the roster (v2.47) plus per-move counters — and a live **handler read** that runs on EVERY frame (v2.47: no longer starved by the ball-speed gates, so slow dribbles and at-rest role swaps keep the counter fresh): whoever holds the ball arms his style's stance, flipping the frame a pass or steal changes hands. **Role forensics** (v2.48) overrules the game's once-checked, between-matches-stale role labels using what players actually CAST. **Bait hold** (v2.61): a sub-threat roller with its own shooter chasing it is a one-two played with legs — no ability, invisible to the move-driven HOLD — so the keeper stays home (no dive, no step-up, no plow) until smother range and lets the collect rules take the second touch. **Curve chase** (v2.61): for the CURVE family rows (Rin/Sae/Yukimiya-Gyro), two stable frames of live sideways accel ≥ 35 studs/s² prime the v2.32 commit machinery mid-flight — the keeper dives where the bend ARRIVES, named move or not — and v2.62's second tier chases ANY handler's ball bending past 55 studs/s²: a gyro that inhumane gets chased whoever fired it — and v2.63 SAVES it: while a live inhuman chase is proving itself the catch window stretches (+5 lateral, +3 ceiling), because a gyro keeps breaking AFTER the commit. The second half of the combo is timed too: a dive that fails to secure arms the 🏃 SECOND-SHOT WATCH — 1.6 s of fast re-arm (0.3 s floor) and a +6-stud-early commit on the rebound, because Rin's off-ball run is aimed at the keeper's reset, not his hands. **Floor-shot plow** (v2.53): a low, fast ball skids, so its side-speed is the least trusted input — the center band widens ×1.8, side dives need +1 confirm frame, and a near-center floor ball inside 22 studs gets the straight-on smother the user ordered ("FORWARDS") instead of a guessed side. **Awakening watch** (v2.53): a documented cutscene effect credits the nearest opponent and forces full reads for 6.5 s — awareness, never a dive (shared move names like *The Destroyer* attribute nobody). **Slide respect** (v2.62): during a flagged ankle-break window (Nagi's fake-volley bait documents itself), the keeper refuses the LUNGE — no tackle into a slide, the contact the move exists to punish; the chaser's legs close on air. **Flick respect** (v2.56): a ball RISING at an opponent's own distance at dribble speed is a rainbow flick, not an aerial shot — no loft lunge, no top-bin leap, and it never counts as a 🎪 charge juggle; a real strike off the flick (≥ 75 studs/s) dives the same frame. **Long-read guard** (v2.58): past `LONG_GUESS_DIST` studs a barely-off-center read is a coin flip, not a save — the keeper holds the middle (🧷 logged) instead of diving sideways at a guess, and close-range reads are untouched. **OP GK tackle** (v2.58): 10.5-stud reach, 0.55 s reset, and it collects a loose flick-drop the keeper just won — but never mid-juggle, never into a receiver's path. **Volley pressure** (v2.61): against a tacklePressure handler (Kurona's rapid touches raise no flick event), the juggle fence lifts and the collect window widens (6 studs, 12 studs/s) — the keeper tackles INTO the churn; every other juggler stays untouchable and passes stay passes. Handlers are read as players, not moves — Bachira gets a WILD HANDLER stance (mid-air curve gets a confirm frame, quick release, +4 range) the same way a dribbler does. |
| Act | One of `Left` / `Right` / `Forward` / `Middle` fired on the game's dive remote the frame the ball becomes saveable and reachable — plus GK tackle on a carrier at your feet, loft catch, punch-out, slow-ball step-up, a top-bin jump before high dives, answered in kind by an **apex double-jump hop** for crossbar clippers (v2.50 — the game's own Shidou kit proves mid-air second jumps exist). And an **admin-grade hitbox expander** (v2.52, in the spirit of Infinite Yield's `expandhitbox`): an invisible massless 14-stud cube welded to the root — catches are decided against a character's part list, and this game's ball is client-authoritative, so the box counts as keeper. `HITBOX_EXPAND` = your admin command; 0 disables. |
| Learn | Per-player shot-power history (commit distance adapts), save/concede stats from what the ball actually did. |
| Fit | The UI **measures your screen** (v2.55): the HUD panel, save flash, studs label and every style tag scale from `Camera.ViewportSize` — full size on a desktop (≥1280 px), down to a legibility floor (0.55×) on a phone, re-fitting within a second of a rotation. One `uiScaleCur` number drives everything, so new tags are born the right size mid-match. |
| Perform | The **low-spec guardian** (v2.54, retuned v2.57): frame time is measured every frame; a struggling device (sustained <~41 fps → tier 1, <~25 → tier 2) sheds PAINT only — path dots/impact marker off, tag follow 20 Hz, HUD eased and change-gated, billboards fully disabled at the deep tier — with automatic recovery. Prediction, dives, jumps and the hitbox cube never slow down, so a weak phone keeps saving with fewer sparkles (`LOW_SPEC_GUARDIAN = false` opts out. v2.57 adds a **log budget** (prints ARE frames on console-attached executors: 8 lines/2s, 3 while easing, muted lines counted not lost — urgent lines bypass), a `📟 PERF` health line under 50 fps, and `ECO_LOCK` to force tiers for the A-B test: with 2 set and sparkles off, lingering stutter means game or executor, not this script. Reliability: a dive FIRES before any jump decoration and HumanoidStateType is matched by name inside pcall — a client whose enum lacks `.Falling` (old/mobile executors; proven on a friend's console) used to throw between the two and eat the dive, and now can't. **Walk diet** (v2.59): the thing a Lua bench cannot see is the ENGINE's bill for `GetDescendants()` marathons — the lost-ball re-find and the leaderboard hunt now discover-once, cache, cap at 5000 visits and back off geometrically while missing (rediscovery stays instant via the DescendantAdded hooks); idle-frame paint is change-gated, zone/billboard run at 15 Hz; the `📟 PERF` line prints measured `lua ms/frame`, so “the script lags” becomes a falsifiable claim (v2.59's bench: 34.7 ms / 798 frames). **v2.60 unblinding**: scan caps may trim lag, never decide existence — the ball finder is tiered (O(1) remembered parent → uncapped direct children → capped walk on short steps, UNCAPPED on boot and long retries), so a deep ball costs at most 7 s of blindness (with a mute-proof `⚠️ BALL HUNT` line, and HUD 'tracking ball' as the glance-check) instead of the whole match. |

## Running it

Drop it in as a `LocalScript` ( StarterPlayerScripts ) or execute it — it is
defensive about missing pieces:

* the dive remote is *searched* (`Events.GKDive`, `Dive`, `KeeperDive`, …), **and re-searched for life** (v2.49: the handle is validated at every use and re-acquired the moment the game's match framework rebuilds it — a new match can no longer kill the AI) and a
  missing one degrades to "predict + log", never a hang;
* a missing goal falls back to the measured net (`NET_CROSSBAR_STUDS` /
  `NET_WIDTH_STUDS`);
* a game that owns the humanoid state machine is detected and reported once;
* `PAUSE_KEY` (default `F6`) disarms and re-arms the whole thing live;
* `VERBOSE = false` silences the console narrative.

## Tuning quick reference

| I want to… | Change |
| --- | --- |
| Commit to every scorable ball vs. patient keeper | `SAVE_EVERYTHING` |
| Dive earlier / later | `COMMIT_BASE_DIST`, `COMMIT_SPEED_FACTOR`, `COMMIT_MAX_DIST`, `BASE_DIVE_TIME` |
| Stop diving at feints | `FAKE_*` (fresh-pop confirm + bleed hold + travel test) |
| Stop diving at passes | `USE_RECEIVER_GATE`, `RECEIVER_RADIUS`, `AWAY_THRESHOLD`, `WIDE_POST_MARGIN` |
| Save weak central balls with the body | `WEAK_SHOT_SPEED`, `WEAK_CENTER_MAX` |
| Be braver / safer on the line | `REACH_*`, `SLOW_FORWARD_*`, `LOFT_MAX_DIST`, `TACKLE_RANGE` |
| Jump for top bins | `AUTO_JUMP_TOP_BIN`, `TOP_BIN_JUMP_FRACTION`, `AUTO_JUMP_COOLDOWN` |
| Match my game's names | `BALL_NAMES`, `GOAL_*_NAMES`, `DIVE_EVENT_NAMES` |

## Tooling

The script is runnable **off-engine**, which is how every change here is
verified. Requires Python 3 and [`lupa`](https://pypi.org/project/lupa/)
(`pip install lupa`) — it embeds a real Lua VM.

```bash
python3 tools/run_sim.py              # 24 scenarios against a mock Roblox runtime
python3 tools/run_sim.py --print S07  # + dump the AI's console output
python3 tools/run_sim.py S04 --script /tmp/experiment.lua   # test a copy
python3 tools/run_sim.py --bench S21  # per-frame cost + Vector3 allocs for the hot loop
python3 tools/lint.py                 # upvalue budget, block balance, roster data
```

* `tools/roblox_mock.lua` — the mock: `Instance` trees, `Vector3`/`CFrame`,
  signals, `Players`/`RunService`/`ReplicatedStorage`/`Stats`, and a simulated
  clock so runs are deterministic. `tick()` deliberately returns a *different*
  clock base, so any code that mixes the two fails loudly instead of drifting.
* `tools/scenarios.lua` — the scenarios: fast shots, corners, wide/over balls,
  a fake that bleeds out at the kicker's feet, a pass collected by a receiver, a
  carry-in that should end in a tackle, lofts, juggles, a top-bin ball that must
  trigger the jump, own-team kicks that must NOT be dived, ball destroyed and
  respawned, a missing dive remote, the pause hotkey, and a 12-player soak with
  particle spam. Ball flights are integrated with the same gravity the AI uses,
  so a scenario fails for *logic* reasons only.
* `tools/lint.py` — guards the constraint that shapes the whole file: Lua 5.1
  executors refuse to compile a function with more than 60 upvalues, so
  `mainStep` must not gain new file-scope locals. It also checks block balance and
  that every roster / move / counter cross-reference resolves.

Bench numbers for the current script on the 12-player bench scenario:
**23 Vector3 allocations per frame** (was 475) and ~4× less Lua CPU per frame.

## Known limits (honest ones)

* This is a client-side prediction aid. It cannot see the server's hitbox
  decisions, and a dive still needs the game to accept the remote call.
* The move counters are name matches against effects the game spawns
  (`ShidouDoubleJumpShot`, …). A renamed or unpublished move is invisible until
  its name is added to `MOVE_EXACT_INFO` — the AI prints any `Ichigo<Move>`-style
  name it saw but could not classify.
* The sim is a *behaviour* harness, not a Roblox emulator: it proves the script
  boots, decides, fires and survives abuse. It cannot prove that a dive looks
  right on screen or that the game accepts it.
