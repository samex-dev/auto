#!/usr/bin/env python3
"""Run the Zero-Latency GK AI script (../auto) against the mock Roblox runtime.

    python3 tools/run_sim.py                # all scenarios
    python3 tools/run_sim.py S07            # substring filter
    python3 tools/run_sim.py --print S07    # dump the AI's console output
    python3 tools/run_sim.py --bench        # per-frame cost of the soak scenario
    python3 tools/run_sim.py --script /tmp/before.lua   # test another copy

Each scenario boots the script in its own Lua runtime (isolated globals), so a
syntax error, a boot-time yield, or a nil reference anywhere in the loop shows
up as a hard failure instead of a shrug.

Requires `lupa` (pip install lupa).
"""
from __future__ import annotations

import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"

DRIVER = """
local SIM, SCEN = _G.SIM, _G.SCEN
local sc = SCEN.scenarios[{index}]
if not sc then return "NOSCENARIO" end
local fails, lines = 0, {{}}
local function fail(msg) fails = fails + 1; lines[#lines+1] = "  !! " .. msg end

local ok, err = pcall(sc.run)
if not ok then fail("scenario crashed: " .. tostring(err)) end
local res = SCEN.collect(sc.name)
if SIM.tagSeen then
  local tagTable = SIM.tagSeen
  if not tagTable.BAROU then fail("no BAROU style tag above the head") end
  if not tagTable.CHIGIRI then fail("no CHIGIRI style tag above the head") end
end
if SIM.pausedDives then
  if SIM.pausedDives > 0 then fail("paused, but " .. SIM.pausedDives .. " dive(s) still fired") end
  if res.dives < 1 then fail("re-armed, but the keeper never dove again") end
end

local expect = sc.expect or {{}}
if #res.errors > 0 then
  for i = 1, math.min(3, #res.errors) do fail("loop error: " .. res.errors[i]) end
  fail("total loop errors: " .. #res.errors)
end

-- dives
local want = expect.dives
if want then
  local lo, hi
  if type(want) == "number" then lo, hi = want, want else lo, hi = want.min or 0, want.max or 1e9 end
  if res.dives < lo then fail(("expected >= %d dive(s), got %d"):format(lo, res.dives)) end
  if res.dives > hi then fail(("expected <= %d dive(s), got %d"):format(hi, res.dives)) end
end

-- direction mix
if expect.dirs then
  for dir, n in pairs(expect.dirs) do
    if (res.dirs[dir] or 0) < n then
      fail(("expected >= %d '%s' dive(s), got %d"):format(n, dir, res.dirs[dir] or 0))
    end
  end
end

local joined = table.concat(res.prints, "\\n")
if expect.any then
  for _, s in ipairs(expect.any) do
    if not joined:find(s, 1, true) then fail("missing log line: " .. s) end
  end
end
if expect.none then
  for _, s in ipairs(expect.none) do
    if joined:find(s, 1, true) then fail("unexpected log line: " .. s) end
  end
end

local dirStr = {{}}
for d, n in pairs(res.dirs) do dirStr[#dirStr+1] = d .. "x" .. n end
table.sort(dirStr)
local lastLine = res.prints[#res.prints] or "-"
SIM.out(string.format("%s %s | dives=%d [%s] | last: %s",
  (fails == 0 and "  ok  " or "  FAIL"), sc.name, res.dives, table.concat(dirStr, " "), lastLine))

if {verbose} then
  for i = 1, #res.prints do SIM.out("      | " .. res.prints[i]) end
end
return fails .. "|" .. res.dives .. "|" .. table.concat(lines, "\\n")
"""

BENCH = """
local SIM = _G.SIM
local sc = _G.SCEN.scenarios[{index}]
SIM.v3reset()
local frames = 0
local realStep = SIM.step
SIM.step = function(dt) frames = frames + 1 return realStep(dt) end
local realAdvance = SIM.advance
SIM.advance = function(sec, dt, onStep)
  local before = frames
  local r = realAdvance(sec, dt, onStep)
  frames = frames + (r or 0)
  return r
end
local t0 = SIM.realTime()
sc.run()
local ms = (SIM.realTime() - t0) * 1000
return string.format("%.1f|%d|%d", ms, frames, SIM.v3count())
"""


def run_one(lua_src: str, mock: str, scen: str, index: int, verbose: bool) -> tuple[str, str]:
    import lupa

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    try:
        lua.execute(mock, name="mock")
        lua.execute(scen, name="scenarios")
        # pre-boot hooks (e.g. remove the dive remote so boot robustness is tested)
        if lua.execute(f"return _G.SCEN.scenarios[{index}].pre ~= nil"):
            lua.execute(f"_G.SCEN.scenarios[{index}].pre()", name="pre")
        lua.execute(lua_src, name="auto")
        # capture stdout lines emitted through SIM.out
        import io
        import contextlib

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            res = lua.execute(DRIVER.format(index=index, verbose=str(verbose).lower()), name="driver")
        status = str(res) if res is not None else ""
        label = buf.getvalue().strip()
        return label, status
    except Exception as exc:  # lupa.LuaError or syntax/runtime blowup
        return "", f"EXC|0|{type(exc).__name__}: {exc}"


def main() -> int:
    args = [a for a in sys.argv[1:]]
    verbose = "--print" in args
    bench = "--bench" in args
    script = ROOT / "auto"
    if "--script" in args:
        i = args.index("--script")
        script = pathlib.Path(args[i + 1])
        del args[i:i + 2]
    args = [a for a in args if a not in ("--print", "--bench")]
    if not script.is_absolute():
        script = (pathlib.Path.cwd() / script).resolve()
    filt = args[0] if args else None

    lua_src = script.read_text()
    mock = (TOOLS / "roblox_mock.lua").read_text()
    scen = (TOOLS / "scenarios.lua").read_text()

    import lupa

    probe = lupa.LuaRuntime()
    probe.execute(mock, name="mock")
    probe.execute(scen, name="scenarios")
    names = str(probe.execute(
        "local t = {} for i = 1, #_G.SCEN.scenarios do t[i] = _G.SCEN.scenarios[i].name end "
        "return table.concat(t, '\\n')"
    )).split("\n")
    n = len(names)

    total_fails = 0
    print(f"== sim: {script.name} ({len(lua_src.splitlines())} lines, {n} scenarios) ==")
    for i in range(1, n + 1):
        if filt and filt.lower() not in names[i - 1].lower():
            continue
        label, status = run_one(lua_src, mock, scen, i, verbose)
        if bench and ("bench" in names[i - 1].lower() or "soak" in names[i - 1].lower()):
            ms = bench_one(lua_src, mock, scen, i)
            if ms:
                label = f"{label}   [{ms} ms of lua CPU]"
        if label:
            print(label)
        if "|" in status:
            fails = int(status.split("|", 1)[0]) if status.split("|", 1)[0].isdigit() else 1
            total_fails += fails
            detail = status.split("|", 2)
            if len(detail) > 2 and detail[2].strip():
                print(detail[2])
        else:
            total_fails += 1
            print("  !! scenario produced no result")
    print("== " + ("ALL SCENARIOS PASS" if total_fails == 0 else f"{total_fails} FAILURE(S)") + " ==")
    return 0 if total_fails == 0 else 1


def bench_one(lua_src: str, mock: str, scen: str, index: int) -> str:
    import lupa

    lua = lupa.LuaRuntime()
    try:
        lua.execute(mock, name="mock")
        lua.execute(lua_src, name="auto")
        lua.execute(scen, name="scenarios")
        import io
        import contextlib

        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            ms = lua.execute(BENCH.format(index=index))
        ms_val, frames, v3 = str(ms).split("|")
        frames, v3 = int(frames), int(v3)
        per_frame_v3 = (v3 / frames) if frames else 0
        return f"{float(ms_val):.1f} ms / {frames} frames / {per_frame_v3:.0f} Vector3 allocs per frame"
    except Exception as exc:
        if "-v" in " ".join(sys.argv):
            print("bench error:", repr(exc))
        return ""


if __name__ == "__main__":
    sys.exit(main())
