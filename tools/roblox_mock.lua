--[[
	Mock Roblox runtime for running ../auto (the Zero-Latency GK AI) off-engine.

	Only the surface the script actually touches is implemented: Instance trees,
	Vector3/CFrame math, signals, Players/RunService/ReplicatedStorage/Stats,
	and the handful of Roblox-only stdlib extras (math.clamp, table.create,
	table.find, tick()).

	Everything is driven by a SIMULATED clock: os.clock() -> SIM.clock, so runs
	are deterministic. tick() deliberately returns a DIFFERENT time base (epoch),
	so any code that mixes tick() with os.clock() shows up as broken behaviour.

	Loaded by tools/run_sim.py. Test-facing API hangs off the global `SIM`.
]]

local sqrt = math.sqrt

-- ---------- Roblox stdlib extensions ----------
math.clamp = math.clamp or function(v, lo, hi)
	if v < lo then return lo elseif v > hi then return hi end
	return v
end
table.create = table.create or function(n, v)
	local t = {}
	if v ~= nil then for i = 1, n do t[i] = v end end
	return t
end
table.find = table.find or function(t, value)
	for i = 1, #t do if t[i] == value then return i end end
	return nil
end

-- ---------- signals ----------
local Signal = {}
Signal.__index = Signal
function Signal.new() return setmetatable({ _handlers = {} }, Signal) end
function Signal:Connect(fn)
	local handlers = self._handlers
	handlers[#handlers + 1] = fn
	local conn = { Connected = fn }
	conn.Disconnect = function()
		for i, h in ipairs(handlers) do
			if h == fn then table.remove(handlers, i) return end
		end
	end
	return conn
end
function Signal:Fire(...)
	local snapshot = {}
	for i, h in ipairs(self._handlers) do snapshot[i] = h end
	for i = 1, #snapshot do snapshot[i](...) end
end

-- ---------- Vector3 ----------
local V3mt
local V3ALLOC = 0
local function newV3(x, y, z)
	V3ALLOC = V3ALLOC + 1
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt)
end
V3mt = {
	__index = function(t, k)
		if k == "Magnitude" then return sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
		if k == "Unit" then
			local m = sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
			if m == 0 then return newV3(0, 0, 0) end
			return newV3(t.X / m, t.Y / m, t.Z / m)
		end
		return V3mt[k]
	end,
	__add = function(a, b) return newV3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end,
	__sub = function(a, b) return newV3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end,
	__mul = function(a, b)
		if type(b) == "number" then return newV3(a.X * b, a.Y * b, a.Z * b) end
		if type(a) == "number" then return newV3(b.X * a, b.Y * a, b.Z * a) end
		return newV3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
	end,
	__div = function(a, b)
		if type(b) == "number" then return newV3(a.X / b, a.Y / b, a.Z / b) end
		return newV3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
	end,
	__unm = function(a) return newV3(-a.X, -a.Y, -a.Z) end,
	__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end,
	__tostring = function(a) return string.format("(%.2f, %.2f, %.2f)", a.X, a.Y, a.Z) end,
	new = function(x, y, z)
		if type(x) == "table" and x.X then return newV3(x.X, x.Y, x.Z) end
		return newV3(x, y, z)
	end,
	Dot = function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end,
	Cross = function(a, b)
		return newV3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
	end,
	Lerp = function(a, b, al) return a + (b - a) * al end,
}
V3mt.zero = newV3(0, 0, 0)
-- Roblox exposes both Vector3.x/y/z and Vector3.xAxis/yAxis/zAxis as unit axes
V3mt.x, V3mt.y, V3mt.z = newV3(1, 0, 0), newV3(0, 1, 0), newV3(0, 0, 1)
V3mt.xAxis, V3mt.yAxis, V3mt.zAxis = V3mt.x, V3mt.y, V3mt.z
local Vector3 = setmetatable({}, { __index = V3mt, __newindex = function(_, k, v) V3mt[k] = v end })

-- ---------- CFrame (position + yaw only; that is all the script reads) ----------
local CFmt
local function newCF(x, y, z, yaw)
	return setmetatable({ _x = x or 0, _y = y or 0, _z = z or 0, _yaw = yaw or 0 }, CFmt)
end
CFmt = {
	__index = function(t, k)
		if k == "Position" then return newV3(t._x, t._y, t._z) end
		local yaw = t._yaw or 0
		-- Roblox convention (verified against the identity CFrame:
		-- look=(0,0,-1), right=(1,0,0)); right = look x up.
		if k == "LookVector" then return newV3(-math.sin(yaw), 0, -math.cos(yaw)) end
		if k == "RightVector" then return newV3(math.cos(yaw), 0, -math.sin(yaw)) end
		if k == "UpVector" then return newV3(0, 1, 0) end
		if k == "X" then return t._x end
		if k == "Y" then return t._y end
		if k == "Z" then return t._z end
		return CFmt[k]
	end,
	__mul = function(a, b)
		if b._x ~= nil then return newCF(a._x + b._x, a._y + b._y, a._z + b._z, a._yaw + (b._yaw or 0)) end
		if b.X ~= nil then return newV3(a._x + b.X, a._y + b.Y, a._z + b.Z) end
		return a
	end,
}
CFmt.new = function(a, b, c)
	if type(a) == "table" and a.X then return newCF(a.X, a.Y, a.Z) end
	return newCF(a, b, c)
end
CFmt.identity = newCF(0, 0, 0)
CFmt.lookAt = function(from, to)
	-- yaw such that LookVector points from -> to (yaw-only)
	local d = to - from
	local yaw = math.atan2(-d.X, d.Z)
	return newCF(from.X, from.Y, from.Z, yaw)
end
local function cfAngles(x, y, z) return newCF(0, 0, 0, y or 0) end
CFmt.Angles, CFmt.fromEulerAnglesYXZ = cfAngles, cfAngles
local CFrame = setmetatable({}, { __index = CFmt, __newindex = function(_, k, v) CFmt[k] = v end })

-- ---------- Color3 / UDim / UDim2 ----------
local Color3 = { new = function(r, g, b) return { R = r or 0, G = g or 0, B = b or 0 } end }
Color3.fromRGB = function(r, g, b) return { R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 } end
Color3.fromHSV = Color3.fromRGB
local UDim = { new = function(s, o) return { Scale = s, Offset = o } end }
local UDim2 = {
	new = function(sx, ox, sy, oy) return { X = { Scale = sx, Offset = ox }, Y = { Scale = sy, Offset = oy } } end,
	fromOffset = function(ox, oy) return { X = { Scale = 0, Offset = ox }, Y = { Scale = 0, Offset = oy } } end,
	fromScale = function(sx, sy) return { X = { Scale = sx, Offset = 0 }, Y = { Scale = sy, Offset = 0 } } end,
}

-- ---------- class ancestry (for IsA) ----------
local PARENTS = {
	BasePart = "PVInstance", PVInstance = "Instance", Model = "PVInstance",
	Part = "BasePart", MeshPart = "BasePart", SpawnLocation = "BasePart",
	Folder = "Instance", GuiBase2d = "LayerCollector", LayerCollector = "GuiBase",
	ScreenGui = "GuiBase2d", BillboardGui = "GuiBase2d", Frame = "GuiBase2d",
	TextLabel = "GuiBase2d", GuiBase = "Instance", GuiObject = "GuiBase",
	UICorner = "UIComponent", UIComponent = "Instance",
	StringValue = "ValueBase", NumberValue = "ValueBase", IntValue = "ValueBase",
	ValueBase = "Instance", RemoteEvent = "Instance", Humanoid = "Instance",
	Player = "Instance", Camera = "LayerCollector",
}
local function classIsA(cls, want)
	local c = cls
	while c do
		if c == want then return true end
		c = PARENTS[c]
	end
	return want == "Instance"
end

-- ---------- SIM (test-facing state; declared early: instance methods use it) ----------
local SIM = {
	clock = 0,
	prints = {},
	pingMs = 45,
	v3count = function() return V3ALLOC end,
	v3reset = function() V3ALLOC = 0 end,
}
_G.SIM = SIM

-- ---------- Instance ----------
local methods = {}

local function addChild(parent, child)
	local children = rawget(parent, "_children") or {}
	rawset(parent, "_children", children)
	children[#children + 1] = child
end
local function removeChild(parent, child)
	local children = rawget(parent, "_children")
	if not children then return end
	for i, c in ipairs(children) do
		if c == child then table.remove(children, i) return end
	end
end

local InstanceMt = {
	__index = function(t, k)
		local m = rawget(methods, k)
		if m then return m end
		if k == "Position" then
			local p = rawget(t, "_pos")
			if p then return p end
			local cf = rawget(t, "_cf")
			if cf then return cf.Position end
			return nil
		elseif k == "CFrame" then
			local cf = rawget(t, "_cf")
			if cf then return cf end
			local p = rawget(t, "_pos")
			if p then return newCF(p.X, p.Y, p.Z, rawget(t, "_yaw") or 0) end
			return nil
		elseif k == "Parent" then
			return rawget(t, "_parent")
		end
		return nil
	end,
	__newindex = function(t, k, v)
		-- Position / CFrame / Parent are stored under shadow keys and never
		-- rawset under their own names, so every write keeps hitting
		-- __newindex (Lua only calls it for absent keys) and the tree stays
		-- consistent.
		if k == "Parent" then
			local old = rawget(t, "_parent")
			if old then removeChild(old, t) end
			rawset(t, "_parent", v)
			if v then
				addChild(v, t)
				local ws = rawget(SIM, "workspace")
				if ws then
					ws.DescendantAdded:Fire(t)
					for _, d in ipairs(t:GetDescendants()) do
						ws.DescendantAdded:Fire(d)
					end
				end
			end
			return
		end
		if k == "Position" then rawset(t, "_pos", v) return end
		if k == "CFrame" then
			rawset(t, "_cf", v)
			rawset(t, "_pos", v.Position)
			rawset(t, "_yaw", v._yaw or 0)
			return
		end
		rawset(t, k, v)
	end,
}
methods.IsA = function(self, cls) return classIsA(rawget(self, "_class") or "Instance", cls) end
methods.GetName = function(self) return rawget(self, "Name") end
methods.Destroy = function(self)
	self.Parent = nil
	rawset(self, "_destroyed", true)
end
methods.Remove = methods.Destroy
methods.GetChildren = function(self) return rawget(self, "_children") or {} end
methods.GetDescendants = function(self)
	local out = {}
	local function walk(node)
		for _, c in ipairs(rawget(node, "_children") or {}) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(self)
	return out
end
methods.FindFirstChild = function(self, name)
	for _, c in ipairs(rawget(self, "_children") or {}) do
		if rawget(c, "Name") == name then return c end
	end
	return nil
end
methods.FindFirstChildOfClass = function(self, cls)
	for _, c in ipairs(rawget(self, "_children") or {}) do
		if c:IsA(cls) then return c end
	end
	return nil
end
methods.WaitForChild = function(self, name) return self:FindFirstChild(name) end
methods.GetAttribute = function() return nil end
methods.SetAttribute = function() end
methods.GetFullName = function(self) return self.Name end
methods.GetPropertyChangedSignal = function() return Signal.new() end
methods.GetBoundingBox = function(self)
	local minX, minY, minZ, maxX, maxY, maxZ = math.huge, math.huge, math.huge, -math.huge, -math.huge, -math.huge
	local function acc(pos, size)
		if not pos then return end
		local s = size or newV3(0, 0, 0)
		minX = math.min(minX, pos.X - s.X / 2); maxX = math.max(maxX, pos.X + s.X / 2)
		minY = math.min(minY, pos.Y - s.Y / 2); maxY = math.max(maxY, pos.Y + s.Y / 2)
		minZ = math.min(minZ, pos.Z - s.Z / 2); maxZ = math.max(maxZ, pos.Z + s.Z / 2)
	end
	local pri = rawget(self, "PrimaryPart")
	if pri then acc(pri.Position, pri.Size) end
	for _, d in ipairs(self:GetDescendants()) do
		if d:IsA("BasePart") then acc(d.Position, d.Size) end
	end
	if minX == math.huge then return newV3(0, 0, 0), newV3(0, 0, 0) end
	return newV3(minX, minY, minZ), newV3(maxX, maxY, maxZ)
end
methods.GetPrimaryPartCFrame = function(self)
	local p = rawget(self, "PrimaryPart")
	return p and p.CFrame or newCF(0, 0, 0)
end
methods.PivotTo = function(self, cf)
	local p = rawget(self, "PrimaryPart")
	if p then p.CFrame = cf end
end
methods.Clone = function(self)
	return setmetatable({ _class = rawget(self, "_class"), Name = rawget(self, "Name"), _children = {} }, InstanceMt)
end
methods.ChangeState = function(self, st)
	rawset(self, "_state", st)
	rawset(self, "_stateChanges", (rawget(self, "_stateChanges") or 0) + 1)
	return true
end
methods.GetState = function(self)
	local st = rawget(self, "_state")
	if st then return st end
	local root = rawget(self, "_root")
	if root and rawget(SIM, "grounded") ~= false then return "Landed" end
	return "Freefall"
end
methods.Jump = function(self)
	rawset(self, "_jumped", (rawget(self, "_jumped") or 0) + 1)
end
methods.FireServer = function(self, ...)
	local log = rawget(self, "_fireLog")
	if not log then log = {} rawset(self, "_fireLog", log) end
	log[#log + 1] = { t = SIM.clock, args = { ... } }
end

local function newInstance(className)
	local t = setmetatable({ _class = className, Name = className, _children = {} }, InstanceMt)
	if className == "Part" or className == "BasePart" or className == "MeshPart" then
		t.Size = newV3(1, 1, 1)
		rawset(t, "_pos", newV3(0, 0, 0))
		t.Transparency = 0
		t.Anchored = false
		t.AssemblyLinearVelocity = newV3(0, 0, 0)
	elseif className == "Model" then
		t.PrimaryPart = nil
	elseif className == "Humanoid" then
		t.Health = 100
		t.MaxHealth = 100
	end
	return t
end

-- ---------- services / data model ----------
local workspace = newInstance("Folder")
workspace.Name = "Workspace"
workspace.Gravity = 196.2
workspace.DescendantAdded = Signal.new()
workspace.DescendantRemoving = Signal.new()

local Players = setmetatable({
	MaxPlayers = 30,
	PlayerAdded = Signal.new(),
	PlayerRemoving = Signal.new(),
}, {
	__index = function(t, k)
		if k == "LocalPlayer" then return SIM.localPlayer end
		if k == "GetPlayers" then
			return function() return SIM.playerList end
		end
		return rawget(methods, k)
	end,
})

local ReplicatedStorage = newInstance("Folder")
ReplicatedStorage.Name = "ReplicatedStorage"
local ReplicatedFirst = newInstance("Folder")
ReplicatedFirst.Name = "ReplicatedFirst"

local diveEvent = newInstance("RemoteEvent")
diveEvent.Name = "GKDive"
diveEvent._fireLog = {}
local eventsFolder = newInstance("Folder")
eventsFolder.Name = "Events"
diveEvent.Parent = eventsFolder
eventsFolder.Parent = ReplicatedStorage

local Stats = {
	Network = {
		ServerStatsItem = setmetatable({}, {
			__index = function()
				return { GetValue = function() return SIM.pingMs or 45 end }
			end,
		}),
	},
}

local RunService = { Heartbeat = Signal.new(), RenderStepped = Signal.new() }

local playerGui = newInstance("Folder")
playerGui.Name = "PlayerGui"

local Camera = newInstance("Camera")
Camera.Name = "Camera"
Camera.CFrame = newCF(0, 8, -22, math.pi)
workspace.Camera = Camera
workspace.CurrentCamera = Camera
SIM.setCameraPos = function(pos, yaw)
	Camera.CFrame = newCF(pos[1], pos[2], pos[3], yaw or 0)
end

local userInput = {
	InputBegan = Signal.new(),
	InputEnded = Signal.new(),
	TouchEnabled = false,
}
SIM.userInput = userInput

local game = {
	GetService = function(self, name)
		if name == "Players" then return Players
		elseif name == "RunService" then return RunService
		elseif name == "ReplicatedStorage" then return ReplicatedStorage
		elseif name == "ReplicatedFirst" then return ReplicatedFirst
		elseif name == "Stats" then return Stats
		elseif name == "Workspace" then return workspace
		elseif name == "UserInputService" then return SIM.userInput
		elseif name == "SoundService" then return newInstance("Folder")
		elseif name == "ContextActionService" then
			return { BindAction = function() end, UnbindAction = function() end }
		end
		return newInstance("Folder")
	end,
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	Workspace = workspace,
	Sim = SIM,
}

-- ---------- enums ----------
local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(t, k)
		local e = enumCache[k]
		if not e then
			e = setmetatable({}, {
				__index = function(_, k2)
					local key = k .. "." .. k2
					if enumCache[key] == nil then enumCache[key] = key end
					return enumCache[key]
				end,
			})
			enumCache[k] = e
		end
		return e
	end,
})

-- ---------- print capture ----------
local realPrint = print or print
SIM.out = function(s) if realPrint then realPrint(tostring(s)) end end
local function capture(prefix, ...)
	local n = select("#", ...)
	local parts = {}
	for i = 1, n do parts[i] = tostring(select(i, ...)) end
	SIM.prints[#SIM.prints + 1] = prefix .. table.concat(parts, "\t")
end

-- ---------- global environment ----------
_G.print = function(...) capture("", ...) end
_G.warn = function(...) capture("WARN: ", ...) end
_G.Vector3 = Vector3
_G.CFrame = CFrame
_G.Color3 = Color3
_G.UDim = UDim
_G.UDim2 = UDim2
_G.Instance = { new = newInstance }
_G.Enum = Enum
_G.game = game
_G.workspace = workspace
_G.script = setmetatable({ Name = "auto" }, { __index = function() return nil end })
-- tick(): deliberately a DIFFERENT clock base from os.clock() (as in Roblox, where
-- tick() is the deprecated epoch clock). Mixing the two then breaks visibly.
_G.tick = function() return 1000000000 + SIM.clock end
local realOS = os
_G.os = setmetatable({ clock = function() return SIM.clock end, time = function() return math.floor(SIM.clock) end }, {
	__index = function(_, k) return realOS[k] end,
})
_G.task = {
	wait = function() end,
	spawn = function(fn, ...) if fn then fn(...) end end,
	defer = function(fn, ...) if fn then fn(...) end end,
}
_G.delay = function(_, fn) if fn then fn() end end

-- ---------- world building / stepping ----------
SIM.pressKey = function(name)
	userInput.InputBegan:Fire({ KeyCode = Enum.KeyCode[name], PlayerInput = nil }, false)
end
SIM.workspace = workspace
SIM.game = game
SIM.Players = Players
SIM.RunService = RunService
SIM.ReplicatedStorage = ReplicatedStorage
SIM.Camera = Camera
SIM.playerGui = playerGui
SIM.diveEvent = diveEvent
SIM.playerList = {}
SIM.newV3 = newV3
SIM.newCF = newCF
SIM.newV = newV3
SIM.instanceNew = newInstance
SIM.Signal = Signal
SIM.setGravity = function(g) workspace.Gravity = g end
SIM.resetWorld = function()
	for _, c in ipairs(workspace:GetChildren()) do c.Parent = nil end
	-- the local player persists across resets (in a real LocalScript
	-- Players.LocalPlayer is never nil once the chunk runs)
	for i = #SIM.playerList, 1, -1 do
		if SIM.playerList[i] ~= SIM.localPlayer then table.remove(SIM.playerList, i) end
	end
	if SIM.localPlayer then
		SIM.localPlayer.Character = nil
		SIM.localPlayer.Team = nil
		for _, c in ipairs({ SIM.localPlayer:GetChildren() }) do
			if c.Name ~= "PlayerGui" then c.Parent = nil end
		end
	end
	SIM.prints = {}
	SIM.clock = 0
	local log = diveEvent._fireLog
	for i = #log, 1, -1 do log[i] = nil end
end
SIM.newPart = function(name, pos, size, parent)
	local p = newInstance("Part")
	p.Name = name
	p.Size = newV3(size[1], size[2], size[3])
	p.Position = newV3(pos[1], pos[2], pos[3])
	p.Anchored = true
	if parent then p.Parent = parent end
	return p
end
SIM.newPlayer = function(name, isLocal)
	local plr = newInstance("Player")
	plr.Name = name
	plr.Character = nil
	plr.Team = nil
	SIM.playerList[#SIM.playerList + 1] = plr
	if isLocal then
		SIM.localPlayer = plr
		playerGui.Parent = plr
	end
	return plr
end
SIM.newCharacter = function(plr, pos)
	local char = newInstance("Model")
	char.Name = (plr and plr.Name or "Char") .. "Char"
	local root = SIM.newPart("HumanoidRootPart", pos, { 2, 2, 1 }, char)
	local hum = newInstance("Humanoid")
	hum.Health = 100
	hum.Parent = char
	char.PrimaryPart = root
	plr.Character = char
	root.Parent = char
	return char, root, hum
end
-- Goal frame: 16 wide, 8 tall, line at z = 0, field on +z
SIM.newGoal = function(parent)
	local goal = SIM.newModel("Goal", parent or workspace)
	SIM.newPart("LeftPost", { -8, 4, 0 }, { 1, 8, 1 }, goal)
	SIM.newPart("RightPost", { 8, 4, 0 }, { 1, 8, 1 }, goal)
	SIM.newPart("Crossbar", { 0, 8.5, 0 }, { 17, 1, 1 }, goal)
	return goal
end
SIM.newModel = function(name, parent)
	local m = newInstance("Model")
	m.Name = name
	if parent then m.Parent = parent end
	return m
end
SIM.setCameraYaw = function(rad)
	Camera.CFrame = newCF(0, 8, -22, rad)
end
-- one frame: advance the simulated clock, then run the Heartbeat listeners
SIM.step = function(dt)
	SIM.clock = SIM.clock + (dt or 1 / 60)
	RunService.Heartbeat:Fire(dt or 1 / 60)
end
SIM.advance = function(seconds, dt, onStep)
	dt = dt or 1 / 60
	local target = SIM.clock + seconds
	local guard = 0
	while SIM.clock < target - 1e-9 and guard < 100000 do
		guard = guard + 1
		local d = math.min(dt, target - SIM.clock)
		if onStep then onStep(d, SIM.clock + d) end
		SIM.step(d)
	end
	return guard
end
SIM.fireLog = function() return diveEvent._fireLog end
SIM.realTime = function() return realOS and realOS.clock() or 0 end
SIM.lastPrints = function(n)
	local out = {}
	local start = math.max(1, #SIM.prints - (n or 10) + 1)
	for i = start, #SIM.prints do out[#out + 1] = SIM.prints[i] end
	return out
end

-- the local player exists before the chunk under test boots
SIM.newPlayer("LocalPlayer", true)

return SIM
