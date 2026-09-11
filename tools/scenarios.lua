--[[
	Scenario harness for ../auto.

	World: goal line at z = 0, mouth x in [-8, 8], crossbar y = 8, field on +z.
	Geometry mirrors the script's own fallback net (16 x 8 studs) and the ball
	is a 2-stud part resting at y = 1.

	Shots are integrated with REAL gravity so the AI's trajectory simulator and
	the simulated ball agree — otherwise a scenario "fails" for physics reasons
	instead of logic reasons.

	Each scenario records:
	  dives   -> every DiveEvent:FireServer(dir)
	  prints  -> everything the AI logged
	  errors  -> LOOP ERROR lines (the loop is pcall-guarded by the script)

	`expect` (checked by tools/run_sim.py):
	  dives = N | {min=N, max=N}
	  dirs  = { Forward = 1, ... }   required direction counts
	  any   = { "SUBSTRING", ... }   must appear in the prints
	  none  = { "SUBSTRING", ... }   must NOT appear
	  errors = N                     default 0
]]

local SIM = _G.SIM

local KEEPER_POS = { 0, 3, 4 }
local BALL_REST_Y = 1

local function makeWorld(opts)
	opts = opts or {}
	SIM.resetWorld()
	local ws = SIM.workspace

	local keeper = SIM.localPlayer
	SIM.newCharacter(keeper, opts.keeperPos or KEEPER_POS)

	if not opts.noGoal then
		SIM.newGoal(ws)
	end

	local ball = SIM.newPart("Ball", opts.ballPos or { 0, BALL_REST_Y, 400 }, { 2, 2, 2 }, ws)

	local world = {
		ball = ball,
		keeper = keeper,
		kChar = keeper.Character,
		kRoot = keeper.Character and keeper.Character:FindFirstChild("HumanoidRootPart"),
		kHum = keeper.Character and keeper.Character:FindFirstChildOfClass("Humanoid"),
		ws = ws,
	}

	-- an out-field player with a character; the name doubles as their style
	-- (the AI scans the player name for a roster match)
	world.addPlayer = function(name, pos, opts2)
		opts2 = opts2 or {}
		local plr = SIM.newPlayer(name, false)
		local char, root, hum = SIM.newCharacter(plr, pos)
		if opts2.team then
			local team = SIM.instanceNew("Folder")
			team.Name = opts2.team
			plr.Team = team
		end
		if opts2.style then
			local values = SIM.instanceNew("Folder")
			values.Name = "Values"
			values.Parent = plr
			local sv = SIM.instanceNew("StringValue")
			sv.Name = "Character"
			sv.Value = opts2.style
			sv.Parent = values
		end
		return plr, char, root, hum
	end

	return world
end

local function v3(p) return SIM.newV3(p[1], p[2], p[3]) end

--[[
	fly(world, o) — incremental ball flight, integrated with the same gravity
	the AI uses, so a scenario only fails when the LOGIC is wrong.
	  o.from, o.to       start / through-the-line point {x,y,z}
	  o.speed            horizontal speed at release (studs/s)
	  o.time             flight time to `to` (defaults to dist/speed)
	  o.settle           seconds resting at `from` first (default SETTLE)
	  o.tail             extra seconds after the nominal flight (default 0.4)
	  o.total            hard cap on the loop duration
	  o.linear           ignore gravity (dead straight line)
	  o.bleedAfter       s into the flight after which speed decays (a fake)
	  o.bleedRate        1/s multiplicative decay once bleeding
	  o.holdAfter        s into the flight after which the ball stops dead
	  o.dt               frame length (default 1/60)
]]
local SETTLE = 1.3 -- the goal scan is throttled to 1s; let the world settle past it

local function fly(world, o)
	local a, b = v3(o.from), v3(o.to)
	local dt = o.dt or (1 / 60)
	local g = (SIM.workspace.Gravity or 196.2)

	local hdist = math.max(math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2), 0.001)
	local hspeed = o.speed or (hdist / (o.time or 0.4))
	local unit = SIM.newV3((b.X - a.X) / hdist, 0, (b.Z - a.Z) / hdist)
	local flight = o.time or (hdist / math.max(hspeed, 0.001))
	local vy0 = (b.Y - a.Y) / flight + 0.5 * g * flight
	if o.linear then vy0 = (b.Y - a.Y) / flight end

	world.ball.Position = a
	SIM.advance(o.settle or SETTLE, dt)

	local pos = SIM.newV3(a.X, a.Y, a.Z)
	local vx, vy, vz = unit.X * hspeed, vy0, unit.Z * hspeed
	local t = 0
	local total = o.total or (flight + (o.tail or 0.4))
	while t < total do
		if o.bleedAfter and t >= o.bleedAfter then
			local k = math.max(0, 1 - (o.bleedRate or 4) * dt)
			vx, vy, vz = vx * k, vy * k, vz * k
		end
		if (o.holdAfter and t >= o.holdAfter) or (o.holdAtEnd and t >= flight) then
			vx, vy, vz = 0, 0, 0
		end
		if not o.linear then vy = vy - g * dt end
		pos = pos + SIM.newV3(vx * dt, vy * dt, vz * dt)
		if pos.Y < BALL_REST_Y then
			pos = SIM.newV3(pos.X, BALL_REST_Y, pos.Z)
			if vy < 0 then vy = -vy * 0.35 end
		end
		world.ball.Position = pos
		SIM.step(dt)
		t = t + dt
	end
end

local function scripted(world, seconds, fn, dt)
	dt = dt or (1 / 60)
	local t = 0
	while t < seconds do
		local p = fn(t, dt)
		if p then world.ball.Position = v3(p) end
		SIM.step(dt)
		t = t + dt
	end
end

-- ------------------------------------------------------------- assertions ----
local function collect(scenarioName)
	local fires = SIM.fireLog()
	local dives, dirs = 0, {}
	for i = 1, #fires do
		local arg = fires[i].args[1]
		if type(arg) == "string" then
			dives = dives + 1
			dirs[arg] = (dirs[arg] or 0) + 1
		end
	end
	local prints = SIM.prints
	local errors = {}
	for i = 1, #prints do
		if prints[i]:find("LOOP ERROR", 1, true) or prints[i]:find("attempt to", 1, true) then
			errors[#errors + 1] = prints[i]
		end
	end
	return {
		name = scenarioName,
		dives = dives,
		dirs = dirs,
		prints = prints,
		errors = errors,
	}
end

-- ------------------------------------------------------------- scenarios ----
local scenarios = {}
local function S(name, expect, run, pre)
	scenarios[#scenarios + 1] = { name = name, expect = expect or {}, run = run, pre = pre }
end

S("S00 boot: no ball, no goal, nothing to do", { dives = 0 }, function()
	local w = makeWorld({ noGoal = true })
	SIM.advance(0.6)
end)

S("S01 fast shot straight at goal -> dive", { dives = { min = 1 } }, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 40 })
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110 })
end)

S("S02 fast shot into the near corner -> dive to that side", { dives = { min = 1 }, dirs = { Right = 1 } }, function()
	local w = makeWorld()
	w.addPlayer("Rin", { -10, 3, 38 })
	fly(w, { from = { -10, BALL_REST_Y, 38 }, to = { -7, 2, 0 }, speed = 105 })
end)

S("S03 shot clearly wide of the post -> stay on feet", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Isagi", { 14, 3, 40 })
	fly(w, { from = { 14, BALL_REST_Y, 40 }, to = { 17.5, 1.5, 0 }, speed = 100, linear = true })
end)

S("S04 shot over the bar -> stay on feet", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Yukimiya", { 0, 3, 40 })
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 16, 0 }, speed = 90 })
end)

S("S05 ball behind the goal line -> never chase it", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Nagi", { 0, 3, 40 })
	fly(w, { from = { 0, BALL_REST_Y, -6 }, to = { 0, BALL_REST_Y, -40 }, speed = 60, linear = true, settle = 0.6 })
end)

S("S06 fake chop: pops then bleeds out at the feet -> no dive", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 24 })
	-- a 90 studs/s chop that dies within ~3 studs of the kick spot
	fly(w, {
		from = { 0, BALL_REST_Y, 24 }, to = { 0, 1.2, 21 }, speed = 90,
		bleedAfter = 0.05, bleedRate = 22, total = 0.9, linear = true,
	})
end)

S("S07 weak central shot -> forward catch", { dives = { min = 1 }, dirs = { Forward = 1 } }, function()
	local w = makeWorld()
	w.addPlayer("Chigiri", { 0, 3, 26 })
	fly(w, { from = { 0, BALL_REST_Y, 26 }, to = { 0, 2, 0 }, speed = 52 })
end)

S("S08 hard pass collected by a receiver in the lane -> no shot dive", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Sae", { 18, 3, 26 })
	w.addPlayer("Reo", { 2, 3, 15 }) -- receiver sitting on the passing lane
	fly(w, { from = { 18, BALL_REST_Y, 26 }, to = { 2, 1.6, 15 }, speed = 80, linear = true,
		holdAtEnd = true, total = 1.0 })
end)

S("S09 carry in at the keeper -> tackle, never a dive", { dives = { max = 2 }, any = { "GK TACKLE" } }, function()
	local w = makeWorld()
	local carrier, _, cRoot = w.addPlayer("Shidou", { 0, 3, 26 })
	SIM.advance(0.4)
	local z = 26
	while z > 9 do
		z = z - 0.25
		cRoot.Position = SIM.newV3(0, 3, z)
		w.ball.Position = SIM.newV3(0, 1.2, z - 1.2)
		SIM.step(1 / 60)
	end
	SIM.advance(0.25)
end)

S("S10 descending loft into the keeper -> loft catch or dive", { dives = { min = 1 } }, function()
	local w = makeWorld()
	w.addPlayer("Kaiser", { 0, 3, 30 })
	fly(w, { from = { 0, 15, 26 }, to = { 0, 2.5, 3 }, speed = 22, tail = 0.6 })
end)

S("S11 teammate shot -> own-team ball, never dive", { dives = 0 }, function()
	local w = makeWorld()
	local home = SIM.instanceNew("Folder")
	home.Name = "Home"
	SIM.localPlayer.Team = home
	local mate = w.addPlayer("Isagi", { 0, 3, 40 })
	mate.Team = home
	-- a second team exists, so the Team source is trusted (not a free-for-all)
	local away = SIM.instanceNew("Folder")
	away.Name = "Away"
	local foe = w.addPlayer("Barou", { 12, 3, 30 })
	foe.Team = away
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110 })
end)

S("S12 juggle overhead -> never a shot", { dives = 0 }, function()
	local w = makeWorld()
	local p, _, root = w.addPlayer("Bachira", { 0, 3, 14 })
	SIM.advance(0.3)
	scripted(w, 1.6, function(t)
		local y = 4 + 5 * math.abs(math.sin(t * 5))
		return { root.Position.X, y, root.Position.Z - 1 }
	end)
end)

S("S13 top-bin shot -> jump then dive", { dives = { min = 1 }, any = { "TOP-BIN JUMP" } }, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 36 })
	fly(w, { from = { 0, BALL_REST_Y, 36 }, to = { -6, 8.6, 0 }, speed = 95, tail = 0.1 })
end)

S("S14 no goal geometry -> still reacts, no crash", { dives = { min = 1 } }, function()
	local w = makeWorld({ noGoal = true })
	w.addPlayer("Ronaldo", { 0, 3, 34 })
	fly(w, { from = { 0, BALL_REST_Y, 34 }, to = { 0, 2, 0 }, speed = 100 })
end)

S("S15 foreign gravity -> no crash", {}, function()
	SIM.workspace.Gravity = 60
	local w = makeWorld()
	w.addPlayer("Dio", { 0, 3, 34 })
	fly(w, { from = { 0, BALL_REST_Y, 34 }, to = { 0, 4, 0 }, speed = 85 })
	SIM.workspace.Gravity = 196.2
end)

S("S16 soak: 6.7s of shot noise + instance spam", {}, function()
	local w = makeWorld()
	local p, _, root = w.addPlayer("Rin", { 0, 3, 34 })
	local spam = SIM.newModel("Effects", w.ws)
	local a, b = v3({ 0, BALL_REST_Y, 34 }), v3({ 0, 2, 0 })
	local unit = (b - a).Unit
	local dist = (b - a).Magnitude
	local t = 0
	while t < 6.7 do
		t = t + 1 / 60
		local cycle = t % 1.2
		local pos
		if cycle < 0.5 then
			pos = a + unit * ((cycle / 0.5) * dist)
		else
			pos = a
		end
		w.ball.Position = pos
		root.Position = SIM.newV3(0, 3, 34 + math.sin(t) * 2)
		if math.floor(t * 60) % 3 == 0 then
			local junk = SIM.instanceNew("Part")
			junk.Name = "Particle" .. math.floor(t * 100)
			junk.Parent = spam
		end
		SIM.step(1 / 60)
	end
end)

S("S17 repeat shots respect the dive cooldown", { dives = { max = 6 } }, function()
	local w = makeWorld()
	w.addPlayer("Kaiser", { 0, 3, 30 })
	for i = 1, 4 do
		fly(w, {
			from = { 0, BALL_REST_Y, 30 },
			to = { (i % 2 == 0) and 6 or -6, 2, 0 },
			speed = 105, settle = 0.35, tail = 0.2,
		})
	end
end)

-- boot robustness: the game has no ReplicatedStorage.Events.GKDive
S("S18 boot without the GKDive remote -> warn, never hang", { dives = 0 }, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 40 })
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110 })
end, function()
	-- pre: runs BEFORE the script chunk boots
	local events = SIM.ReplicatedStorage:FindFirstChild("Events")
	if events then
		for _, c in ipairs(events:GetChildren()) do c.Parent = nil end
	end
end)

-- a move effect appearing in workspace must arm its counter
S("S19 move effect arms a counter", { any = { "detected", "counter" } }, function()
	local w = makeWorld()
	local shooter = w.addPlayer("Shidou", { 0, 3, 36 })
	local fx = SIM.instanceNew("Part")
	fx.Name = "ShidouDoubleJumpShot"
	fx.Parent = w.ws
	fly(w, { from = { 0, BALL_REST_Y, 36 }, to = { 0, 2, 0 }, speed = 120 })
end)

-- the ball vanishes mid-match (server reset) -> no crash, re-finds it
S("S20 ball destroyed then respawned", { dives = { min = 0 } }, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 40 })
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110, tail = 0.1 })
	w.ball.Parent = nil
	SIM.advance(0.8)
	local ball2 = SIM.newPart("GK_Ball", { 0, BALL_REST_Y, 50 }, { 2, 2, 2 }, w.ws)
	SIM.advance(0.8)
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110, tail = 0.2 })
end)

-- bench: full pipeline, 12 players, instance spam, continuous live shots
S("S21 bench: 12 players + live shots + effect spam", {}, function()
	local w = makeWorld()
	for i = 1, 11 do
		w.addPlayer("Player" .. i, { (i % 2 == 0) and 10 or -10, 3, 18 + i * 2 })
	end
	local spam = SIM.newModel("Effects", w.ws)
	local frame = 0
	for cycle = 1, 6 do
		fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110, settle = 0.6, tail = 0.15 })
		for i = 1, 30 do
			frame = frame + 1
			local junk = SIM.instanceNew("Part")
			junk.Name = "Particle" .. frame
			junk.Parent = spam
			SIM.step(1 / 60)
		end
	end
end)

-- pause hotkey: the loop must go quiet, then re-arm cleanly
S("S22 pause key arms and disarms the keeper", {}, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 40 })
	-- press the pause key, shoot: nothing may happen
	SIM.pressKey("F6")
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110 })
	local pausedDives = #SIM.fireLog()
	-- press again, shoot: the keeper is live
	SIM.pressKey("F6")
	fly(w, { from = { 0, BALL_REST_Y, 40 }, to = { 0, 2, 0 }, speed = 110, settle = 0.4 })
	SIM.pausedDives = pausedDives
end)

-- scouting layer: style tags above heads + the HUD must actually get built
S("S23 style tags and HUD are created", {}, function()
	local w = makeWorld()
	w.addPlayer("Barou", { 0, 3, 30 })
	w.addPlayer("Chigiri", { 6, 3, 30 })
	SIM.advance(1.4)
	local folder = w.ws:FindFirstChild("AutoDiveStyleTags")
	local seen = {}
	if folder then
		for _, anchor in ipairs(folder:GetChildren()) do
			local bb = anchor:FindFirstChild("StyleTag")
			local label = bb and bb:FindFirstChildOfClass("TextLabel")
			if label then seen[label.Text] = (seen[label.Text] or 0) + 1 end
		end
	end
	SIM.tagSeen = seen
end)

local H = { scenarios = scenarios, collect = collect, makeWorld = makeWorld, fly = fly, scripted = scripted }
_G.SCEN = H
return H
