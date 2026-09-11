#!/usr/bin/env python3
"""Static checks for the auto script (no Roblox needed).

1) mainStep upvalue budget — Lua 5.1 executors (which most of these run inside)
   fail to COMPILE a function with more than 60 upvalues. That is why the script
   bundles per-frame state into ST / CHARGE / MOVE / GK. This check counts the
   file-scope names mainStep actually references, so a future "just add one
   local" cannot silently break the load.
2) Block balance + a crude `end` sanity check.
3) Roster integrity: every CHAR_NAMES key has a CHAR_PROFILES entry, every
   MOVE_INFO entry names a known character, every COUNTER_MODES alias a move
   resolves to a counter (the script's own data tables promise this; a typo in
   a one-line add would otherwise crash the loop).

Usage: python3 tools/lint.py [path/to/script]
"""
from __future__ import annotations

import re
import sys
import pathlib

LUA_51_UPVALUE_LIMIT = 60


def strip_noise(src: str) -> str:
    """Remove comments and string literals (so identifier scans stay honest)."""
    src = re.sub(r"--\[(=*)\[.*?\]\1\]", lambda m: "\n" * m.group(0).count("\n"), src, flags=re.S)
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "-" and src.startswith("--", i):
            j = src.find("\n", i)
            i = n if j < 0 else j  # leave the newline to the next iteration
            continue
        if c in "\"'":
            q = c
            j = i + 1
            while j < n and src[j] != q:
                j += 2 if src[j] == "\\" else 1
            i = min(j + 1, n)
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return "".join(out)


def file_scope_locals(clean: str):
    """Names declared at chunk level: `local x =` / `local function x`."""
    names = []
    for m in re.finditer(
        r"^(?:local\s+function\s+([A-Za-z_]\w*)|local\s+((?:[A-Za-z_]\w*\s*,\s*)*[A-Za-z_]\w*)\s*(?:=|$))",
        clean,
        re.M,
    ):
        for part in re.split(r"[,\s]+", m.group(1) or m.group(2) or ""):
            if part and part not in names:
                names.append(part)
    return names


def function_span(clean: str, header: str):
    start = clean.index(header)
    line_start = clean.rfind("\n", 0, start) + 1
    # the function ends at the first line that is exactly "end" at column 0
    tail = clean[start:]
    m = re.search(r"^end$", tail, re.M)
    if not m:
        raise SystemExit(f"lint: could not find the end of {header!r}")
    end = start + m.end()
    line_no = clean[:line_start].count("\n") + 1
    return line_no, clean[:end].count("\n") + 1, clean[line_start:end]


def check_upvalues(clean: str, raw: str):
    decls_before = []
    # names in declaration order, so we can attribute only those visible to mainStep
    header = "local function mainStep(deltaTime)"
    ln_a, ln_b, body = function_span(clean, header)
    before = "\n".join(clean.split("\n")[: ln_a - 1])
    decls_before = file_scope_locals(before)
    used = sorted({n for n in decls_before if re.search(r"(?<![\w.])" + re.escape(n) + r"\b", body)})
    return ln_a, ln_b, used


def check_blocks(raw: str):
    problems = []
    depth_kw = 0
    clean = strip_noise(raw)
    # `do` only opens a block on its own (`for/while ... do` is already counted by
    # its loop keyword), so bare `do ... end` scopes are what we add here.
    for m in re.finditer(r"\b(function|if|for|while|end|repeat|until|do)\b", clean):
        w = m.group(1)
        if w == "do":
            line_start = clean.rfind("\n", 0, m.start()) + 1
            prefix = clean[line_start:m.start()]
            if re.search(r"\b(for|while)\b", prefix):
                continue
        if w in ("function", "if", "for", "while", "repeat", "do"):
            depth_kw += 1
        elif w in ("end", "until"):
            depth_kw -= 1
        if depth_kw < 0:
            problems.append("block closed before it opened near offset %d" % m.start())
            break
    if depth_kw != 0:
        problems.append(f"unbalanced blocks: depth {depth_kw:+d} at EOF")
    return problems


TABLE_SPAN_CACHE = {}


def lua_table_keys(clean: str, decl: str):
    """Top-level keys of `local NAME = { ... }` (string/ident keys)."""
    i = clean.index(decl)
    j = clean.index("{", i)
    depth, k = 0, j
    while True:
        c = clean[k]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                break
        k += 1
    body = clean[j + 1:k]
    keys = set(re.findall(r"^\s*([A-Za-z_]\w*)\s*=", body, re.M))
    keys |= set(re.findall(r'^\s*\["([^"]+)"\]\s*=', body, re.M))
    return keys, body


def check_roster(clean: str):
    problems = []
    profiles, _ = lua_table_keys(clean, "local CHAR_PROFILES = {")
    names, names_body = lua_table_keys(clean, "local CHAR_NAMES = {")
    moves, moves_body = lua_table_keys(clean, "local MOVE_INFO = {")
    counters, counters_body = lua_table_keys(clean, "local COUNTER_MODES = {")

    for key in names:
        if key not in profiles:
            problems.append(f"CHAR_NAMES.{key} has no CHAR_PROFILES entry (nil index in scanCharacters)")
    for m in re.finditer(r'char\s*=\s*"([A-Za-z0-9_]+)"', moves_body):
        if m.group(1) not in profiles:
            problems.append(f"MOVE_INFO references unknown character '{m.group(1)}'")
    for m in re.finditer(r'counterKey\s*=\s*"([A-Za-z0-9_]+)"', moves_body):
        if m.group(1) not in counters:
            problems.append(f"MOVE_INFO alias points at missing counter '{m.group(1)}'")
    return problems


def main() -> int:
    path = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "auto")
    if not path.is_absolute():
        path = pathlib.Path.cwd() / path
    raw = path.read_text()
    clean = strip_noise(raw)
    fails = 0

    ln_a, ln_b, used = check_upvalues(clean, raw)
    limit = LUA_51_UPVALUE_LIMIT
    flag = "ok" if len(used) <= limit else "OVER"
    print(f"  {flag:5s} mainStep upvalue budget: {len(used)}/{limit} (lines {ln_a}-{ln_b})")
    if len(used) > limit:
        fails += 1
        print(f"        Lua 5.1 executors refuse to compile this. Bundle into ST/CHARGE/GK/MOVE instead.")

    problems = check_blocks(raw)
    for p in problems:
        fails += 1
        print(f"  FAIL  blocks: {p}")
    if not problems:
        print("  ok    block structure balanced (function/if/for/while vs end)")

    roster = check_roster(clean)
    for p in roster:
        fails += 1
        print(f"  FAIL  data: {p}")
    if not roster:
        print("  ok    roster/move/counter cross-references resolve")

    print("lint: " + ("clean" if fails == 0 else f"{fails} problem(s)"))
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
