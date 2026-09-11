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

## What it does, in order

| Step | What happens |
| --- | --- |
| Track | Finds the ball once (event-driven `DescendantAdded` + throttled fallback scan), samples its position history. |
| Sense | Two-window velocity/acceleration estimator (fast warmup, curve deadzone + cap), ping-compensated. |
| Predict | Scalar trajectory integrator: where the ball crosses the line, closest approach to where the **keeper will be**, time-to-impact. |
| Decide | Possession (network `NetworkOwner`, else carrier/carry/last-shooter), controlled-ball gate (carried ≠ shot), carry correlation, fake/bleed detector, receiver gate (a pass is not a shot), honest wide/over ruling, urgency tiers, a handler stance for EVERY style in the roster (v2.47) plus per-move counters — and a live **handler read** that runs on EVERY frame (v2.47: no longer starved by the ball-speed gates, so slow dribbles and at-rest role swaps keep the counter fresh): whoever holds the ball arms his style's stance, flipping the frame a pass or steal changes hands. |
| Act | One of `Left` / `Right` / `Forward` / `Middle` fired on the game's dive remote the frame the ball becomes saveable and reachable — plus GK tackle on a carrier at your feet, loft catch, punch-out, slow-ball step-up, and a top-bin jump before high dives. |
| Learn | Per-player shot-power history (commit distance adapts), save/concede stats from what the ball actually did. |

## Running it

Drop it in as a `LocalScript` ( StarterPlayerScripts ) or execute it — it is
defensive about missing pieces:

* the dive remote is *searched* (`Events.GKDive`, `Dive`, `KeeperDive`, …) and a
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
