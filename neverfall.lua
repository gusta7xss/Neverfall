-- // === Library ===
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
	Title = "NeverFall",
	Footer = "version: BETA",
	Icon = 17501536225,
	NotifySide = "Right",
	ShowCustomCursor = false,
})

local Tabs = {
	Main = Window:AddTab("Main", "user"),
	["UI Settings"] = Window:AddTab("UI Settings", "settings"),
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- // === Helper: personagem ocupado com skill/dash (não mexer em stun/velocidade nesse estado) ===
local function charBusy(char)
	if not char then return false end
	return char:GetAttribute("isUsingSkill") == true
		or char:GetAttribute("UsingSkill") == true
		or char:GetAttribute("Busy") == true
end

-- // === Super Jump (hold, controlado pelo keypicker) ===
local SJ_DEFAULT_JUMP = 50
local SJ = { held = false, lastJump = 0 }

local function sjHum()
	local c = LocalPlayer.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function sjSetPower(v)
	local hum = sjHum()
	if not hum then return end
	hum.UseJumpPower = true
	hum.JumpPower = v
end

local SuperJumpBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "Super Jump",
	IconName = "arrow-up",
})

SuperJumpBox:AddLabel("Super Jump Key"):AddKeyPicker("SJ_Key", {
	Default = "None",
	Mode = "Hold",
	Text = "Super Jump",
})

SuperJumpBox:AddSlider("SJ_Power", {
	Text = "Jump Power",
	Default = 400, Min = 400, Max = 720, Rounding = 0,
	Callback = function(v)
		if SJ.held then sjSetPower(v) end
	end,
})

RunService.Heartbeat:Connect(function()
	local holding = Options.SJ_Key:GetState()

	if holding and not SJ.held then
		SJ.held = true
		sjSetPower(Options.SJ_Power.Value)
	elseif not holding and SJ.held then
		SJ.held = false
		sjSetPower(SJ_DEFAULT_JUMP)
	end

	if not SJ.held then return end

	local hum = sjHum()
	if not hum or hum.Health <= 0 then return end

	local st = hum:GetState()
	local grounded = st ~= Enum.HumanoidStateType.Freefall
		and st ~= Enum.HumanoidStateType.Jumping
		and st ~= Enum.HumanoidStateType.Flying

	if grounded and tick() - SJ.lastJump >= 0.25 then
		SJ.lastJump = tick()
		hum.Jump = true
	end
end)

local AIR_JUMP_COOLDOWN = 0.35
local lastAirJump = 0

UIS.JumpRequest:Connect(function()
	if not SJ.held then return end

	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = sjHum()
	if not hrp or not hum or hum.Health <= 0 then return end

	local st = hum:GetState()
	if st ~= Enum.HumanoidStateType.Freefall and st ~= Enum.HumanoidStateType.Jumping then return end
	if tick() - lastAirJump < AIR_JUMP_COOLDOWN then return end
	lastAirJump = tick()

	local v = hrp.AssemblyLinearVelocity
	hrp.AssemblyLinearVelocity = Vector3.new(v.X, Options.SJ_Power.Value, v.Z)
end)

local IDJ_Box = Tabs.Main:AddGroupbox({ Side = 2, Name = "Infinite Double Jump", IconName = "arrow-up" })
IDJ_Box:AddToggle("IDJ_On", { Text = "Infinite Double Jump", Default = false })

local UIS = game:GetService("UserInputService")
local RS = game:GetService("ReplicatedStorage")
local LP = game.Players.LocalPlayer

local function idjJump()
    if not Toggles.IDJ_On.Value then return end
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 or hum.Sit then return end
    if hum.FloorMaterial ~= Enum.Material.Air then return end
    if char.Busy.Value and not char:GetAttribute("NoTransform") then return end
    if char.Stun.Value > 0 then return end
    local g = require(RS.Global)
    if g.Swimming or g.Dodging then return end

    RS.Remotes.CommE:FireServer("DoubleJump", false)
    RS.PlayerDoubleJumped:Fire()
    hrp.Velocity = Vector3.new(hrp.Velocity.X, hum.JumpPower * 1.4, hrp.Velocity.Z)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
        idjJump()
    end
end)

-- // === Speed Boost (segura a keybind, soma velocidade extra ao andar normal) ===
local SB = { bv = nil, base = 16, announced = false }
local SB_NAME = "Spooky_SpeedBoost" -- prefixo Spooky_ faz o anti stun ignorar esse BodyVelocity

local SpeedBoostBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "Speed Boost",
	IconName = "zap",
})

SpeedBoostBox:AddToggle("SB_Enabled", {
	Text = "Speed Boost",
	Default = false,
})

SpeedBoostBox:AddSlider("SB_Speed", {
	Text = "Speed",
	Default = 250, Min = 250, Max = 750, Rounding = 0,
})

local function sbClear()
	if SB.bv then
		SB.bv:Destroy()
		SB.bv = nil
	end
end

RunService.Heartbeat:Connect(function()
	if not Toggles.SB_Enabled.Value then
		sbClear()
		return
	end

	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if not hrp or not hum or hum.Health <= 0 then
		sbClear()
		return
	end

	-- guarda a base de walkspeed só fora de skill, pra skill não zerar o cálculo do extra
	if not charBusy(c) and hum.WalkSpeed > 0 then
		SB.base = hum.WalkSpeed
	end

	local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	if not SB.bv or SB.bv.Parent ~= hrp then
		sbClear()
		SB.bv = Instance.new("BodyVelocity")
		SB.bv.Name = SB_NAME
		SB.bv.MaxForce = Vector3.new(1e5, 0, 1e5)
		SB.bv.P = 1e4
		SB.bv.Velocity = Vector3.zero
		SB.bv.Parent = hrp
	end

	if md.Magnitude < 0.1 then
		SB.bv.Velocity = Vector3.zero
		return
	end

	local extra = math.max(0, Options.SB_Speed.Value - SB.base)
	SB.bv.Velocity = md.Unit * extra

	if not SB.announced then
		SB.announced = true
		print("[speed boost] ativo, extra", extra)
	end
end)

-- // === Helpers de personagem e alvo ===
local function aliveHrp(p)
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then return hrp end
	return nil
end

local function behindCF(thrp)
	return CFrame.new(thrp.Position - thrp.CFrame.LookVector * 5, thrp.Position)
end

-- // === Safe zone filter (sempre ligado) ===
-- coordenadas não verificadas no mapa, ajusta se precisar
local SAFE_ZONES = {
	{ center = Vector3.new(0, 0, 0), radius = 400 },
	{ center = Vector3.new(-1500, 0, -1000), radius = 350 },
	{ center = Vector3.new(-500, 0, 500), radius = 300 },
	{ center = Vector3.new(1000, 0, -800), radius = 350 },
	{ center = Vector3.new(-300, 0, 200), radius = 250 },
	{ center = Vector3.new(500, 0, -500), radius = 400 },
	{ center = Vector3.new(-800, 0, 800), radius = 500 },
	{ center = Vector3.new(1200, 0, -600), radius = 400 },
}

local function flatXZ(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function inSafeZone(pos)
	local p = flatXZ(pos)
	for _, z in ipairs(SAFE_ZONES) do
		if (p - flatXZ(z.center)).Magnitude <= z.radius then
			return true
		end
	end
	return false
end

local function isInSafeZonePlayer(p)
	local c = p.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and inSafeZone(hrp.Position)
end

local function nearestEnemy()
	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	local best, bestD = nil, math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local thrp = aliveHrp(p)
			if thrp and not isInSafeZonePlayer(p) then
				local d = (thrp.Position - hrp.Position).Magnitude
				if d < bestD then best, bestD = p, d end
			end
		end
	end
	return best
end




-- // === Hook central do mouse (Aimbot Soru) ===
local AIM_WINDOW = 0.45
local AimWin = { soruUntil = 0 }

local function aimTarget()
	local t = nearestEnemy()
	local thrp = t and aliveHrp(t)
	if not thrp then return nil end
	return thrp.Position, thrp
end

local rawMouse = LocalPlayer:GetMouse()
pcall(function()
	local mt = getrawmetatable(rawMouse)
	local oldIndex = mt.__index
	local wrap = newcclosure or function(f) return f end
	setreadonly(mt, false)
	mt.__index = wrap(function(self, key)
		if self == rawMouse and (key == "Hit" or key == "Target") and not checkcaller() then
			if Toggles.AimbotSoru.Value and os.clock() <= AimWin.soruUntil then
				local pos, part = aimTarget()
				if pos then
					if key == "Hit" then return CFrame.new(pos) end
					return part
				end
			end
		end
		if type(oldIndex) == "function" then return oldIndex(self, key) end
		return oldIndex[key]
	end)
	setreadonly(mt, true)
end)

-- // === Soru Assist (R dispara o Soru no alvo) ===
local SA_RANGE = 200

local SoruAssistBox = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Soru Assist",
	IconName = "move-right",
})

SoruAssistBox:AddToggle("InfinitySoru", {
	Text = "Infinity Soru",
	Default = false,
})

local function canSoru(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false, "morto" end
	if not char:HasTag("Soru") then return false, "sem tag Soru" end
	local stun = char:FindFirstChild("Stun")
	local busy = char:FindFirstChild("Busy")
	local energy = char:FindFirstChild("Energy")
	if stun and stun.Value > 0 then return false, "stun" end
	if busy and busy.Value then return false, "busy" end
	if energy and energy.Value < 10 then return false, "energy " .. tostring(energy.Value) end
	return true
end

local function fireSoru(thrp)
	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local commE = remotes and remotes:FindFirstChild("CommE")
	if not hrp then print("[soru assist] sem HumanoidRootPart") return end
	if not commE then print("[soru assist] sem Remotes.CommE") return end

	local behind = behindCF(thrp).Position
	local dest = Vector3.new(behind.X, hrp.Position.Y, behind.Z)

	local toDest = dest - hrp.Position
	if toDest.Magnitude > SA_RANGE then
		dest = hrp.Position + toDest.Unit * SA_RANGE
		toDest = dest - hrp.Position
	end

	local flat = Vector3.new(toDest.X, 0, toDest.Z)
	if flat.Magnitude < 0.1 then flat = hrp.CFrame.LookVector end
	local rot = CFrame.lookAt(Vector3.zero, flat)
	hrp.CFrame = CFrame.new(hrp.Position) * rot

	local destCF = rot + dest

	commE:FireServer(
		"Soru",
		hrp.CFrame,
		destCF,
		workspace:GetServerTimeNow(),
		math.random(1, 999999999)
	)
	print("[soru assist] disparou em", thrp.Parent.Name, "dist", math.floor(toDest.Magnitude))
end

UIS.InputBegan:Connect(function(input, gp)
	if gp or Library.Unloaded or input.KeyCode ~= Enum.KeyCode.R then return end
	if Toggles.AimbotSoru.Value then
		AimWin.soruUntil = os.clock() + AIM_WINDOW
	end
	if not Toggles.SA_Soru.Value then return end

	local char = LocalPlayer.Character
	if not char then return end

	local ok, why = canSoru(char)
	if not ok then
		print("[soru assist] bloqueado:", why)
		return
	end

	local target = nearestEnemy()
	if not target then
		print("[soru assist] sem alvo")
		return
	end

	local thrp = aliveHrp(target)
	if thrp then fireSoru(thrp) end
end)

-- // === Fast Attack (M1 rápido nos inimigos perto, fora de safe zone) ===
local FA = { lastHit = 0, rA = nil, rH = nil }

local FastAttackBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "Fast Attack",
	IconName = "sword",
})

FastAttackBox:AddToggle("FastAttack", {
	Text = "Fast Attack",
	Default = false,
})

FastAttackBox:AddSlider("FA_Delay", {
	Text = "Delay",
	Default = 0.15, Min = 0.12, Max = 1, Rounding = 2,
	Suffix = "s",
})

local FA_IGNORE = { "quest", "dealer", "shop", "citizen", "trainer", "agent", "scientist", "manager", "set home", "pirate starter" }

local function faIgnored(name)
	name = string.lower(name)
	for _, w in ipairs(FA_IGNORE) do
		if string.find(name, w, 1, true) then return true end
	end
	return false
end

local function resolveFARemotes()
	if FA.rA and FA.rH then return true end
	pcall(function()
		local net = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 2):WaitForChild("Net", 2)
		FA.rH = net:FindFirstChild("RE/RegisterHit")
		FA.rA = net:FindFirstChild("RE/RegisterAttack")
	end)
	return FA.rA ~= nil and FA.rH ~= nil
end

local function faStep()
	local char = LocalPlayer.Character
	local myHRP = char and char:FindFirstChild("HumanoidRootPart")
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not myHRP or not tool or tool.ToolTip == "Gun" then return end
	if charBusy(char) then return end

	local myPos = myHRP.Position
	local hits = {}

	local function add(model)
		if faIgnored(model.Name) then return end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model:FindFirstChild("HumanoidRootPart")
		local head = model:FindFirstChild("Head") or root
		if hum and hum.Health > 0 and root and head and (root.Position - myPos).Magnitude <= 120 then
			table.insert(hits, { model, head })
		end
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, npc in ipairs(enemies:GetChildren()) do add(npc) end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and not isInSafeZonePlayer(p) then
			add(p.Character)
		end
	end

	if #hits == 0 then return end
	while #hits > 3 do table.remove(hits) end

	local primary = hits[1][2]
	local diff = primary.Position - myPos
	local dir = diff.Magnitude > 0.05 and diff.Unit or Vector3.new(0, 0, -1)

	if tool:FindFirstChild("LeftClickRemote") then
		tool.LeftClickRemote:FireServer(dir, 1)
	elseif resolveFARemotes() then
		FA.rA:FireServer(0)
		FA.rH:FireServer(primary, hits)
	end
end

RunService.Heartbeat:Connect(function()
	if Library.Unloaded or not Toggles.FastAttack.Value then return end
	local now = tick()
	if now - FA.lastHit < math.max(Options.FA_Delay.Value, 0.12) then return end
	FA.lastHit = now
	pcall(faStep)
end)

-- // === M1 Extender (100 studs: M1 atinge o inimigo mais perto no alcance, sem mirar) ===
-- // === M1 Extender (alcance configurável, mira em qualquer lado) ===
local M1E = { lastFire = 0 }

local M1ExtenderBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "M1 Extender",
	IconName = "mouse-pointer",
})

M1ExtenderBox:AddToggle("M1Extender", {
	Text = "M1 Extender",
	Default = false,
})

M1ExtenderBox:AddToggle("M1E_Face", {
	Text = "Virar pro alvo (360)",
	Default = true,
})

M1ExtenderBox:AddSlider("M1E_Range", {
	Text = "Range",
	Default = 100, Min = 10, Max = 1000, Rounding = 0,
	Suffix = "studs",
})

local function m1eGetTarget(myPos)
	local best, bestD = nil, Options.M1E_Range.Value
	local myChar = LocalPlayer.Character

	local function consider(model, root, hum)
		if root and hum and hum.Health > 0 then
			local d = (root.Position - myPos).Magnitude
			if d < bestD then best, bestD = model, d end
		end
	end

	local enemies = workspace:FindFirstChild("Enemies")
	if enemies then
		for _, npc in ipairs(enemies:GetChildren()) do
			if not faIgnored(npc.Name) then
				consider(npc, npc:FindFirstChild("HumanoidRootPart"), npc:FindFirstChildOfClass("Humanoid"))
			end
		end
	end

	local chars = workspace:FindFirstChild("Characters")
	if chars then
		for _, v in ipairs(chars:GetChildren()) do
			if v ~= myChar and not Players:GetPlayerFromCharacter(v) and not faIgnored(v.Name) then
				consider(v, v:FindFirstChild("HumanoidRootPart"), v:FindFirstChildOfClass("Humanoid"))
			end
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character and p.Character ~= myChar and not isInSafeZonePlayer(p) then
			consider(p.Character, p.Character:FindFirstChild("HumanoidRootPart"), p.Character:FindFirstChildOfClass("Humanoid"))
		end
	end

	return best
end

local function m1eTrigger()
	if Library.Unloaded or not Toggles.M1Extender.Value then return end

	local char = LocalPlayer.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	if not tool then return end
	if tool.ToolTip == "Gun" or charBusy(char) then return end

	local now = tick()
	if now - M1E.lastFire < 0.12 then return end
	M1E.lastFire = now

	local myHRP = char:FindFirstChild("HumanoidRootPart")
	if not myHRP then return end

	local target = m1eGetTarget(myHRP.Position)
	if not target then return end
	local head = target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart")
	if not head then return end

	if Toggles.M1E_Face.Value then
		local flat = Vector3.new(head.Position.X - myHRP.Position.X, 0, head.Position.Z - myHRP.Position.Z)
		if flat.Magnitude > 0.1 then
			myHRP.CFrame = CFrame.lookAt(myHRP.Position, myHRP.Position + flat)
		end
	end

	if tool:FindFirstChild("LeftClickRemote") then
		pcall(function()
			local dir = (head.Position - myHRP.Position).Unit
			tool.LeftClickRemote:FireServer(dir, 1)
		end)
	elseif resolveFARemotes() then
		pcall(function()
			FA.rA:FireServer(0)
			local sessionId = tostring(LocalPlayer.UserId):sub(2, 4) .. tostring(coroutine.running()):sub(11, 15)
			FA.rH:FireServer(head, { { target, head } }, {}, sessionId)
		end)
	end
end

UIS.InputBegan:Connect(function(input, gp)
	if gp or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	m1eTrigger()
end)

local function m1eBindTool(item)
	if item and item:IsA("Tool") then
		item.Activated:Connect(m1eTrigger)
	end
end

local function m1eBindChar(char)
	for _, item in ipairs(char:GetChildren()) do
		m1eBindTool(item)
	end
	char.ChildAdded:Connect(m1eBindTool)
end

if LocalPlayer.Character then
	task.spawn(m1eBindChar, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(c)
	task.spawn(m1eBindChar, c)
end)

local AL_Box = Tabs.Main:AddGroupbox({ Side = 1, Name = "Aimbot Lock", IconName = "crosshair" })

AL_Box:AddToggle("AL_On", { Text = "Enabled", Default = false })

AL_Box:AddDropdown("AL_Mode", {
	Values = { "Camera Lock", "Mouse Lock" },
	Default = "Camera Lock",
	Text = "Mode",
})

AL_Box:AddDropdown("AL_FOVMode", {
	Values = { "Mouse", "Center" },
	Default = "Center",
	Text = "FOV Mode",
})

AL_Box:AddToggle("AL_NPC", { Text = "Include NPC", Default = false })

AL_Box:AddLabel("Camera Lock Key"):AddKeyPicker("AL_Key", {
	Default = "None",
	Mode = "Hold",
	Text = "Camera Lock",
	SyncToggleState = false,
})

AL_Box:AddToggle("AL_ShowFov", { Text = "Show FOV", Default = false })
AL_Box:AddSlider("AL_FOV", { Text = "FOV", Default = 200, Min = 30, Max = 800, Rounding = 0 })
AL_Box:AddSlider("AL_Smooth", { Text = "Smoothness", Default = 5, Min = 1, Max = 30, Rounding = 0 })
AL_Box:AddSlider("AL_Pred", { Text = "Prediction", Default = 0.12, Min = 0, Max = 0.3, Rounding = 3 })

local AL_UIS = game:GetService("UserInputService")
local AL_Players = game:GetService("Players")
local AL_RunService = game:GetService("RunService")
local AL_LP = AL_Players.LocalPlayer
local AL_Mouse = AL_LP:GetMouse()
local AL_GuiService = game:GetService("GuiService")
local AL_NAME = "AL_Lock"

local AL = { target = nil }

local alCircle = Drawing.new("Circle")
alCircle.Thickness = 1
alCircle.NumSides = 64
alCircle.Filled = false
alCircle.Color = Color3.new(1, 1, 1)
alCircle.Visible = false

local function alAlive(head)
	if not head or not head.Parent then return false end
	local m = head:FindFirstAncestorOfClass("Model")
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function alGetTarget(fromVP, fov)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local best, bestD = nil, fov

	local function check(m)
		if m == AL_LP.Character then return end
		local hum = m:FindFirstChildOfClass("Humanoid")
		local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
		if not hum or not head or hum.Health <= 0 then return end
		local sp, on = cam:WorldToViewportPoint(head.Position)
		if not on or sp.Z <= 0 then return end
		local d = (Vector2.new(sp.X, sp.Y) - fromVP).Magnitude
		if d < bestD then
			best, bestD = head, d
		end
	end

	for _, p in ipairs(AL_Players:GetPlayers()) do
		if p.Character then check(p.Character) end
	end

	if Toggles.AL_NPC.Value then
		local enemies = workspace:FindFirstChild("Enemies")
		if enemies then
			for _, m in ipairs(enemies:GetChildren()) do check(m) end
		end
	end

	return best
end

AL_RunService:BindToRenderStep(AL_NAME, Enum.RenderPriority.Camera.Value + 1, function()
	if Library.Unloaded then
		alCircle:Remove()
		AL_RunService:UnbindFromRenderStep(AL_NAME)
		return
	end

	local cam = workspace.CurrentCamera
	if not cam then return end
	local vs = cam.ViewportSize
	local isCam = Options.AL_Mode.Value == "Camera Lock"

	local fovCenter
	if Options.AL_FOVMode.Value == "Mouse" then
		fovCenter = Vector2.new(AL_Mouse.X, AL_Mouse.Y)
	else
		fovCenter = Vector2.new(vs.X / 2, vs.Y / 2)
	end

	alCircle.Visible = Toggles.AL_On.Value and Toggles.AL_ShowFov.Value
	if alCircle.Visible then
		local inset = AL_GuiService:GetGuiInset()
		alCircle.Position = fovCenter + Vector2.new(inset.X, inset.Y)
		alCircle.Radius = Options.AL_FOV.Value
	end

	if not Toggles.AL_On.Value then
		AL.target = nil
		return
	end

	local held
	if isCam then
		held = Options.AL_Key:GetState()
	else
		held = AL_UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
	end
	if not held then
		AL.target = nil
		return
	end

	if not alAlive(AL.target) then
		AL.target = alGetTarget(fovCenter, Options.AL_FOV.Value)
	end
	local head = AL.target
	if not head then return end

	local alpha = 1 / math.max(Options.AL_Smooth.Value, 1)

	if isCam then
		local goal = CFrame.lookAt(cam.CFrame.Position, head.Position)
		cam.CFrame = cam.CFrame:Lerp(goal, alpha)
	else
		local predicted = head.Position + head.AssemblyLinearVelocity * Options.AL_Pred.Value
		local sp, on = cam:WorldToViewportPoint(predicted)
		if not on or sp.Z <= 0 then return end
		mousemoverel((sp.X - AL_Mouse.X) * alpha, (sp.Y - AL_Mouse.Y) * alpha)
	end
end)

Tabs.Macro = Window:AddTab("Macro", "keyboard")

local MacroBox = Tabs.Macro:AddGroupbox({ Side = 1, Name = "Macro Sequence", IconName = "list" })

local MACRO_ACTIONS = { "None", "Melee", "Fruit", "Sword", "Gun", "Z", "X", "C", "V", "F", "M1", "Wait" }
local MACRO_SLOTS = { Melee = Enum.KeyCode.One, Fruit = Enum.KeyCode.Two, Sword = Enum.KeyCode.Three, Gun = Enum.KeyCode.Four }
local MACRO_KEYS = { Z = Enum.KeyCode.Z, X = Enum.KeyCode.X, C = Enum.KeyCode.C, V = Enum.KeyCode.V, F = Enum.KeyCode.F }
local MACRO_DEFAULTS = { "Fruit", "Z", "X", "C", "None", "None" }
local MR_STEPS = 6

MacroBox:AddToggle("M_On", { Text = "Enabled", Default = false })

MacroBox:AddDropdown("M_Mode", {
	Values = { "Once", "Loop" },
	Default = "Once",
	Text = "Mode",
})

for i = 1, MR_STEPS do
	MacroBox:AddDropdown("M_Step" .. i, {
		Values = MACRO_ACTIONS,
		Default = MACRO_DEFAULTS[i],
		Text = "Passo " .. i,
	})
end

MacroBox:AddSlider("M_Delay", { Text = "Delay entre passos", Default = 0.15, Min = 0.03, Max = 1, Rounding = 2, Suffix = "s" })
MacroBox:AddSlider("M_Hold", { Text = "Tempo segurado", Default = 0.06, Min = 0.02, Max = 0.5, Rounding = 2, Suffix = "s" })

MacroBox:AddLabel("Macro Key"):AddKeyPicker("M_Key", {
	Default = "None",
	Mode = "Hold",
	Text = "Macro",
	SyncToggleState = false,
})

local MR = { running = false, wasHeld = false }
local MR_VIM = game:GetService("VirtualInputManager")
local MR_RunService = game:GetService("RunService")

local function mrEquipped()
	local c = game.Players.LocalPlayer.Character
	local tool = c and c:FindFirstChildOfClass("Tool")
	if not tool then return nil end
	local tip = string.lower(tool.ToolTip or "")
	if tip == "gun" then return "Gun" end
	if tip == "melee" then return "Melee" end
	if tip == "sword" then return "Sword" end
	return "Fruit"
end

local function mrTap(kc, hold)
	MR_VIM:SendKeyEvent(true, kc, false, game)
	task.wait(hold)
	MR_VIM:SendKeyEvent(false, kc, false, game)
end

local function mrDo(action)
	if action == "None" then return end
	if action == "Wait" then
		task.wait(Options.M_Delay.Value)
		return
	end
	if MACRO_SLOTS[action] then
		if mrEquipped() ~= action then
			mrTap(MACRO_SLOTS[action], Options.M_Hold.Value)
			task.wait(0.12)
		end
		return
	end
	if MACRO_KEYS[action] then
		mrTap(MACRO_KEYS[action], Options.M_Hold.Value)
		return
	end
	if action == "M1" then
		MR_VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
		task.wait(Options.M_Hold.Value)
		MR_VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end
end

local function macroRun()
	if MR.running then return end
	MR.running = true
	task.spawn(function()
		for i = 1, MR_STEPS do
			if not Toggles.M_On.Value or Library.Unloaded then break end
			local action = Options["M_Step" .. i].Value
			mrDo(action)
			if action ~= "None" and action ~= "Wait" then
				task.wait(Options.M_Delay.Value)
			end
		end
		MR.running = false
	end)
end

MR_RunService.Heartbeat:Connect(function()
	if Library.Unloaded or not Toggles.M_On.Value then
		MR.wasHeld = false
		return
	end
	local held = Options.M_Key:GetState()
	if Options.M_Mode.Value == "Once" then
		if held and not MR.wasHeld then macroRun() end
	else
		if held and not MR.running then macroRun() end
	end
	MR.wasHeld = held
end)

-- // === Z Boost (keybind configurável, impulso pra frente na direção da câmera) ===
local ZB = { cd = 0 }

local ZBoostBox = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Z Boost",
	IconName = "wind",
})

ZBoostBox:AddToggle("ZBoost", {
	Text = "Z Boost",
	Default = false,
})

ZBoostBox:AddLabel("Z Boost Key"):AddKeyPicker("ZB_Key", {
	Default = "None",
	Mode = "Toggle",
	Text = "Z Boost",
	SyncToggleState = false,
})

local function zBoost()
	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not hrp or not cam then return end

	local att = Instance.new("Attachment", hrp)
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = math.huge
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = cam.CFrame.LookVector * 400
	lv.Parent = hrp

	task.delay(0.9, function()
		if lv then lv:Destroy() end
		if att then att:Destroy() end
	end)
end

Options.ZB_Key:OnClick(function()
	if Library.Unloaded or not Toggles.ZBoost.Value then return end
	if tick() - ZB.cd < 0.35 then return end
	ZB.cd = tick()
	zBoost()
end)

-- // === Skill Soru (após o flashstep, aperta arma + skill sozinho) ===
local SS = { last = 0 }

local SkillSoruBox = Tabs.Main:AddGroupbox({
	Side = "Right",
	Name = "Skill Soru",
	IconName = "crosshair",
})

SkillSoruBox:AddToggle("SkillSoru", {
	Text = "Skill Soru",
	Default = false,
})

SkillSoruBox:AddDropdown("SS_Weapon", {
	Values = { "Fruit", "Melee", "Sword", "Gun" },
	Default = "Fruit",
	Text = "Weapon",
})

SkillSoruBox:AddDropdown("SS_Skill", {
	Values = { "Z", "X", "C", "V" },
	Default = "Z",
	Text = "Skill",
})

SkillSoruBox:AddSlider("SS_Delay", {
	Text = "Delay",
	Default = 0.3, Min = 0.1, Max = 0.5, Rounding = 2,
	Suffix = "s",
})

local FLASH_NAMES = { "FlashStepRegular", "FlashStepDraco", "FlashStep", "Flashstep", "Soru" }
local FLASH_IDS = {
	["17555632156"] = true, ["18461649274"] = true, ["616006778"] = true, ["616010882"] = true,
	["5403485593"] = true, ["5403491911"] = true, ["313762630"] = true, ["313762631"] = true,
	["1846164274"] = true, ["1846163351"] = true,
}

local function isFlash(track)
	if not track then return false end
	local tName = string.lower(track.Name or "")
	for _, n in ipairs(FLASH_NAMES) do
		if string.find(tName, string.lower(n)) then return true end
	end
	local id = track.Animation and track.Animation.AnimationId:match("%d+") or ""
	return FLASH_IDS[id] == true
end

local SLOT = {
	Melee = Enum.KeyCode.One,
	Fruit = Enum.KeyCode.Two,
	Sword = Enum.KeyCode.Three,
	Gun = Enum.KeyCode.Four,
}

local function tapKey(kc)
	local vim = game:GetService("VirtualInputManager")
	vim:SendKeyEvent(true, kc, false, game)
	task.wait(0.06)
	vim:SendKeyEvent(false, kc, false, game)
end

local function equippedType()
	local c = LocalPlayer.Character
	local tool = c and c:FindFirstChildOfClass("Tool")
	if not tool then return nil end
	local tip = string.lower(tool.ToolTip or "")
	if tip == "gun" then return "Gun" end
	if tip == "melee" then return "Melee" end
	if tip == "sword" then return "Sword" end
	return "Fruit"
end

local function runSkillSoru()
	if tick() - SS.last < 0.35 then return end
	SS.last = tick()
	task.spawn(function()
		task.wait(Options.SS_Delay.Value)
		if not Toggles.SkillSoru.Value then return end
		local wanted = Options.SS_Weapon.Value
		if equippedType() ~= wanted then
			local slot = SLOT[wanted]
			if slot then tapKey(slot) end
			task.wait(0.12)
		end
		local key = Enum.KeyCode[Options.SS_Skill.Value]
		if key then tapKey(key) end
	end)
end

local function hookSoruAnim(char)
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	hum.AnimationPlayed:Connect(function(track)
		if Toggles.SkillSoru.Value and isFlash(track) then
			runSkillSoru()
		end
	end)
end

if LocalPlayer.Character then
	task.spawn(hookSoruAnim, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(c)
	task.spawn(hookSoruAnim, c)
end)

-- // === Infinity Soru: mantém o cooldown do flashstep em 0.95 ===
RunService.Heartbeat:Connect(function()
	if Library.Unloaded then return end
	local c = LocalPlayer.Character
	if not c then return end
	if Toggles.InfinitySoru.Value then
		if c:GetAttribute("FlashstepCooldown") ~= 0.95 then
			c:SetAttribute("FlashstepCooldown", 0.95)
		end
	elseif c:GetAttribute("FlashstepCooldown") == 0.95 then
		c:SetAttribute("FlashstepCooldown", nil)
	end
end)

do
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local LP = Players.LocalPlayer

    local SGB = { on = false, speed = 300 }
    local DUR = 0.2

    local function skullGuitarEquipped()
        local c = LP.Character
        local tool = c and c:FindFirstChildOfClass("Tool")
        return tool ~= nil and string.find(string.lower(tool.Name), "skull guitar", 1, true) ~= nil
    end

    local function tapBoost()
        local c = LP.Character
        local hrp = c and c:FindFirstChild("HumanoidRootPart")
        local cam = workspace.CurrentCamera
        if not hrp or not cam then return end

        local look = cam.CFrame.LookVector
        local flat = Vector3.new(look.X, 0, look.Z)
        if flat.Magnitude < 0.001 then return end

        local att = Instance.new("Attachment")
        att.Name = "Spooky_SGBoost"
        att.Parent = hrp

        local lv = Instance.new("LinearVelocity")
        lv.Name = "Spooky_SGBoost"
        lv.Attachment0 = att
        lv.MaxForce = math.huge
        lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
        lv.VectorVelocity = flat.Unit * SGB.speed
        lv.Parent = hrp

        task.delay(DUR, function()
            if lv then lv:Destroy() end
            if att then att:Destroy() end
        end)
    end

    UIS.InputBegan:Connect(function(input, gp)
        if gp or not SGB.on then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if not skullGuitarEquipped() then return end
        tapBoost()
    end)

    local Box = Tabs.Main:AddGroupbox({
        Side = "Right",
        Name = "Skull Guitar Tap Boost",
        IconName = "wind",
    })

    Box:AddToggle("SGB_On", {
        Text = "Tap Boost (Skull Guitar)",
        Default = false,
        Callback = function(v)
            SGB.on = v
        end,
    })

    Box:AddSlider("SGB_Speed", {
        Text = "Velocidade",
        Default = 350,
        Min = 350,
        Max = 750,
        Rounding = 0,
        Callback = function(v)
            SGB.speed = v
        end,
    })
end

do
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local LP = Players.LocalPlayer

    local CT = { dist = 60 }

    local function getRoot()
        local c = LP.Character
        return c and c:FindFirstChild("HumanoidRootPart")
    end

    local function teleportAlongCursor()
        local root = getRoot()
        local cam = workspace.CurrentCamera
        if not root or not cam then return end

        local mouse = UIS:GetMouseLocation()
        local ray = cam:ViewportPointToRay(mouse.X, mouse.Y)

        local flat = Vector3.new(ray.Direction.X, 0, ray.Direction.Z)
        if flat.Magnitude < 0.001 then return end

        local target = Vector3.new(
            root.Position.X + flat.Unit.X * CT.dist,
            root.Position.Y,
            root.Position.Z + flat.Unit.Z * CT.dist
        )

        local rot = root.CFrame - root.CFrame.Position
        root.CFrame = CFrame.new(target) * rot
        root.AssemblyLinearVelocity = Vector3.zero
    end

    local Box = Tabs.Main:AddGroupbox({
        Side = "Left",
        Name = "Click Teleport",
        IconName = "map-pin",
    })

    Box:AddLabel("Click Teleport Key"):AddKeyPicker("CT_Key", {
        Default = "None",
        Mode = "Toggle",
        Text = "Click Teleport",
        SyncToggleState = false,
    })

    Options.CT_Key:OnClick(function()
        if Library.Unloaded then return end
        teleportAlongCursor()
    end)

    Box:AddSlider("CT_Dist", {
        Text = "Distância",
        Default = 200,
        Min = 200,
        Max = 300,
        Rounding = 0,
        Suffix = "studs",
        Callback = function(v)
            CT.dist = v
        end,
    })
end

do
    local RS = game:GetService("ReplicatedStorage")
    local LP = game.Players.LocalPlayer

    local AK = { on = false, cd = 1, last = 0 }

    local function isKenActive()
        local ok, v = pcall(function()
            return RS.Events.IsObservationActive:Invoke()
        end)
        return ok and v == true
    end

    local function tryKen()
        local c = LP.Character
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not c or not hum or hum.Health <= 0 then return end
        if not c:HasTag("Ken") then return end
        if c:FindFirstChild("KenDisabled") then return end

        local now = os.clock()
        if now - AK.last < AK.cd then return end
        if isKenActive() then return end

        AK.last = now
        local ok, err = pcall(function()
            RS.Remotes.CommE:FireServer("Ken", true)
        end)
        if not ok then
            warn("[auto ken] " .. tostring(err))
        end
    end

    local function onDamage()
        if AK.on then
            tryKen()
        end
    end

    local function bindChar(c)
        c:GetAttributeChangedSignal("LastDamageTick"):Connect(onDamage)
        c:GetAttributeChangedSignal("LastDamageTakenAt"):Connect(onDamage)
    end

    if LP.Character then
        bindChar(LP.Character)
    end
    LP.CharacterAdded:Connect(bindChar)

    local Box = Tabs.Main:AddGroupbox({
        Side = "Right",
        Name = "Auto Ken Damage",
        IconName = "eye",
    })

    Box:AddToggle("AK_On", {
        Text = "Auto Ken ao tomar dano",
        Default = false,
        Callback = function(v)
            AK.on = v
        end,
    })

    Box:AddSlider("AK_Cd", {
        Text = "Cooldown",
        Default = 1,
        Min = 0.5,
        Max = 5,
        Rounding = 1,
        Suffix = "s",
        Callback = function(v)
            AK.cd = v
        end,
    })
end

local DodgeBox = Tabs.Main:AddGroupbox({ Side = 2, Name = "Dash Distance", IconName = "wind" })

DodgeBox:AddToggle("DD_On", { Text = "Dash Distance", Default = false })
DodgeBox:AddSlider("DD_Dist", { Text = "Distancia Dash", Default = 500, Min = 50, Max = 2500, Rounding = 0 })

local UIS = game:GetService("UserInputService")
local DD_owned = false
local DD_lastDash = 0
local DD_childConn

local function ddDist()
    return math.clamp(tonumber(Options.DD_Dist.Value) or 500, 50, 2500)
end

local function ddAttrs()
    local c = game.Players.LocalPlayer.Character
    if not c then return end
    if Toggles.DD_On.Value then
        local d = ddDist()
        if c:GetAttribute("DashLength") ~= d then c:SetAttribute("DashLength", d) end
        if c:GetAttribute("DashLengthAir") ~= d then c:SetAttribute("DashLengthAir", d) end
        DD_owned = true
    elseif DD_owned then
        c:SetAttribute("DashLength", nil)
        c:SetAttribute("DashLengthAir", nil)
        DD_owned = false
    end
end

local function ddBoost()
    if not Toggles.DD_On.Value then return end
    if tick() - DD_lastDash < 0.22 then return end
    local c = game.Players.LocalPlayer.Character
    if not c then return end
    if c:GetAttribute("isUsingSkill") or c:GetAttribute("UsingSkill") or c:GetAttribute("Busy") then return end
    DD_lastDash = tick()

    local hrp = c:FindFirstChild("HumanoidRootPart")
    local hum = c:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end

    local dir = (hum.MoveDirection.Magnitude > 0.1) and hum.MoveDirection.Unit or hrp.CFrame.LookVector
    local spd = math.clamp(ddDist() * 0.9, 120, 2000)
    local y = hrp.AssemblyLinearVelocity.Y
    hrp.AssemblyLinearVelocity = Vector3.new(dir.X * spd, math.clamp(y, -5, 30), dir.Z * spd)

    task.delay(0.18, function()
        local cc = game.Players.LocalPlayer.Character
        local h = cc and cc:FindFirstChild("HumanoidRootPart")
        if h then
            local v = h.AssemblyLinearVelocity
            h.AssemblyLinearVelocity = Vector3.new(v.X * 0.15, v.Y, v.Z * 0.15)
        end
    end)
end

local function ddHook()
    if DD_childConn then DD_childConn:Disconnect(); DD_childConn = nil end
    local c = game.Players.LocalPlayer.Character
    if not c then return end
    DD_childConn = c.ChildAdded:Connect(function(ch)
        if Toggles.DD_On.Value and (ch.Name == "Dash" or ch.Name == "Dashing") then
            ddBoost()
        end
    end)
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe or not Toggles.DD_On.Value then return end
    if input.KeyCode == Enum.KeyCode.Q and not UIS:GetFocusedTextBox() then
        ddBoost()
    end
end)

Toggles.DD_On:OnChanged(function()
    ddAttrs()
    ddHook()
end)
Options.DD_Dist:OnChanged(ddAttrs)

game.Players.LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    DD_owned = false
    ddAttrs()
    ddHook()
end)

task.spawn(function()
    while not Library.Unloaded do
        task.wait(0.2)
        pcall(ddAttrs)
    end
end)

-- // === Walk on Water ===
local WW = { platform = nil }

local WalkWaterBox = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Walk on Water",
	IconName = "footprints",
})

WalkWaterBox:AddToggle("WalkWater", {
	Text = "Walk on Water",
	Default = false,
	Callback = function(v)
		if not v then
			if WW.platform and WW.platform.Parent then WW.platform.CanCollide = false end
			pcall(function()
				local plane = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("WaterBase-Plane")
				if plane then
					plane.CanCollide = false
					plane.Size = Vector3.new(1000, 80, 1000)
				end
			end)
		end
	end,
})

local function getWaterPlatform()
	if not WW.platform or not WW.platform.Parent then
		local p = Instance.new("Part")
		p.Name = "SpookyWaterPlatform"
		p.Size = Vector3.new(200, 1, 200)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.Parent = workspace
		WW.platform = p
	end
	return WW.platform
end

RunService.Heartbeat:Connect(function()
	if Library.Unloaded then return end
	if not Toggles.WalkWater.Value then
		if WW.platform and WW.platform.Parent then WW.platform.CanCollide = false end
		return
	end

	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local p = getWaterPlatform()
	if hrp.Position.Y >= 9.5 then
		p.Position = Vector3.new(hrp.Position.X, 9.2, hrp.Position.Z)
		p.CanCollide = true
	else
		p.CanCollide = false
	end
end)

-- // === Anti Stun (zera o Stun só quando vem dano, sem mexer em skill/dash) ===
local AS = {
	active = false,
	conns = {},
	char = nil,
	root = nil,
	stunObj = nil,
	stunConn = nil,
	lastDmg = 0,
	recent = {}, -- movers criados no HRP nas últimas janelas
}

local AS_WINDOW = 0.35
local AS_MAX_RECENT = 20

local function asIsMover(obj)
	return obj:IsA("BodyVelocity") or obj:IsA("BodyPosition") or obj:IsA("BodyGyro") or obj:IsA("BodyForce")
end

local function asTrackMover(child)
	if not asIsMover(child) then return end
	if string.sub(child.Name, 1, 7) == "Spooky_" then return end
	table.insert(AS.recent, { obj = child, t = os.clock() })
	if #AS.recent > AS_MAX_RECENT then table.remove(AS.recent, 1) end
end

-- destrói só os movers que nasceram perto do hit, e limpa a lista
local function asCancelRecent()
	local now = os.clock()
	for i = #AS.recent, 1, -1 do
		local e = AS.recent[i]
		if now - e.t <= AS_WINDOW and e.obj and e.obj.Parent then
			pcall(function() e.obj:Destroy() end)
		end
		table.remove(AS.recent, i)
	end
end

local function asOnStun()
	if not AS.active or not AS.stunObj then return end
	if (tonumber(AS.stunObj.Value) or 0) <= 0 then return end
	if charBusy(AS.char) then return end
	if os.clock() - AS.lastDmg > AS_WINDOW then return end
	AS.stunObj.Value = 0
	asCancelRecent()
end

local function asClear()
	for _, c in ipairs(AS.conns) do
		pcall(function() c:Disconnect() end)
	end
	table.clear(AS.conns)
	if AS.stunConn then
		pcall(function() AS.stunConn:Disconnect() end)
		AS.stunConn = nil
	end
	table.clear(AS.recent)
	AS.stunObj, AS.root, AS.char = nil, nil, nil
end

local function asBindRoot(root)
	AS.root = root
	table.insert(AS.conns, root.ChildAdded:Connect(asTrackMover))
end

local function asBind(char)
	asClear()
	if not char or not char.Parent then return end
	AS.char = char
	AS.lastDmg = 0

	-- só dano real dispara, sem reagir a InCombat / LastDetected*
	table.insert(AS.conns, char.AttributeChanged:Connect(function(attr)
		if attr == "LastDamageTick" or attr == "LastDamageTakenAt" then
			AS.lastDmg = os.clock()
			asOnStun()
		end
	end))

	local function watch(child)
		if child.Name == "Stun" and child:IsA("NumberValue") then
			AS.stunObj = child
			if AS.stunConn then pcall(function() AS.stunConn:Disconnect() end) end
			AS.stunConn = child.Changed:Connect(asOnStun)
			asOnStun()
		elseif child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			asBindRoot(child)
		end
	end

	table.insert(AS.conns, char.ChildAdded:Connect(watch))
	table.insert(AS.conns, char.ChildRemoved:Connect(function(child)
		if child == AS.stunObj then
			if AS.stunConn then
				pcall(function() AS.stunConn:Disconnect() end)
				AS.stunConn = nil
			end
			AS.stunObj = nil
		end
	end))

	local existingRoot = char:FindFirstChild("HumanoidRootPart")
	if existingRoot then asBindRoot(existingRoot) end

	local existingStun = char:FindFirstChild("Stun")
	if existingStun and existingStun:IsA("NumberValue") then
		watch(existingStun)
	end
end

local AntiStunBox = Tabs.Main:AddGroupbox({
	Side = "Left",
	Name = "Anti Stun",
	IconName = "shield",
})

AntiStunBox:AddToggle("AntiStun", {
	Text = "Anti Stun",
	Default = false,
	Callback = function(v)
		AS.active = v
		if v then
			asBind(LocalPlayer.Character)
		else
			asClear()
		end
	end,
})

LocalPlayer.CharacterAdded:Connect(function(c)
	if AS.active then
		task.delay(0.2, function() asBind(c) end)
	end
end)

-- // === Executar Script (loader externo, modo PVP / FARM) ===
local LOADER_URL = "https://raw.githubusercontent.com/hermanos-dev/hermanos-hub/refs/heads/main/Loader.lua"

local ExecBox = Tabs.Main:AddGroupbox({
	Side = "left",
	Name = "Executar Script",
	IconName = "play",
})

ExecBox:AddDropdown("ScriptMode", {
	Values = { "PVP", "FARM" },
	Default = "PVP",
	Text = "Mode",
})

ExecBox:AddButton("Executar", function()
	getgenv().script_mode = Options.ScriptMode.Value
	local ok, err = pcall(function()
		loadstring(game:HttpGet(LOADER_URL))()
	end)
	if ok then
		print("[executar] loader rodou, mode:", Options.ScriptMode.Value)
	else
		print("[executar] falhou:", err)
	end
end)

do
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer

	local HITBOX_COLOR = Color3.fromRGB(255, 30, 30)
	local MULT = 250

	local HB = { on = false, vis = false, size = 25, orig = {}, boxes = {} }

	if not _G.HB_CombatHooked then
		_G.HB_CombatHooked = true
		task.spawn(function()
			pcall(function()
				local cuInst = game:GetService("ReplicatedStorage"):WaitForChild("Modules", 5):WaitForChild("CombatUtil", 5)
				local CombatUtil = require(cuInst)
				if typeof(CombatUtil) ~= "table" or not CombatUtil.GetWeaponData then return end
				local oldGet = CombatUtil.GetWeaponData
				CombatUtil.GetWeaponData = function(...)
					local data = oldGet(...)
					if not HB.on or not data then return data end
					return setmetatable({}, {
						__index = function(_, key)
							local v = data[key]
							if key == "HitboxMagnitude" and type(v) == "number" then
								return v * MULT
							end
							return v
						end,
						__newindex = function(_, key, val)
							data[key] = val
						end,
					})
				end
			end)
		end)
	end

	local function restorePart(part)
		local o = HB.orig[part]
		if o and part.Parent then
			pcall(function()
				part.Size = o.Size
				part.Transparency = o.Transparency
				part.CanCollide = o.CanCollide
				part.Massless = o.Massless
			end)
		end
		HB.orig[part] = nil
	end

	local function killBox(model)
		local sb = HB.boxes[model]
		if sb then
			pcall(function() sb:Destroy() end)
			HB.boxes[model] = nil
		end
	end

	local function clearBoxes()
		for model in pairs(HB.boxes) do
			killBox(model)
		end
	end

	local function drawBox(model, adornee)
		local sb = HB.boxes[model]
		if not sb or not sb.Parent then
			sb = Instance.new("SelectionBox")
			sb.Name = "HBVisual"
			sb.Color3 = HITBOX_COLOR
			sb.SurfaceColor3 = HITBOX_COLOR
			sb.SurfaceTransparency = 0.72
			sb.LineThickness = 0.05
			local ok = pcall(function()
				sb.Parent = game:GetService("CoreGui")
			end)
			if not ok or not sb.Parent then
				sb.Parent = workspace
			end
			HB.boxes[model] = sb
		end
		sb.Adornee = adornee
		sb.Visible = true
	end

	local function expandModel(model)
		if model == LocalPlayer.Character then return end

		local hum = model:FindFirstChildOfClass("Humanoid")
		local head = model:FindFirstChild("Head")

		if not hum or hum.Health <= 0 then
			if head then restorePart(head) end
			killBox(model)
			return
		end

		if head and head:IsA("BasePart") then
			if not HB.orig[head] then
				HB.orig[head] = {
					Size = head.Size,
					Transparency = head.Transparency,
					CanCollide = head.CanCollide,
					Massless = head.Massless,
				}
			end
			local s = HB.size
			pcall(function()
				head.Size = Vector3.new(s, s, s)
				head.Transparency = 1
				head.CanCollide = false
				head.Massless = true
			end)
		end

		if HB.vis then
			local adornee = head or model:FindFirstChild("HumanoidRootPart")
			if adornee and adornee:IsA("BasePart") then
				drawBox(model, adornee)
			end
		else
			killBox(model)
		end
	end

	local function scan()
		if not HB.on then return end
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				expandModel(plr.Character)
			end
		end
	end

	local function clearAll()
		for part in pairs(HB.orig) do
			restorePart(part)
		end
		HB.orig = {}
		clearBoxes()
	end

	task.spawn(function()
		while not Library.Unloaded do
			if HB.on then scan() end
			task.wait(0.35)
		end
		clearAll()
	end)

	local HBBox = Tabs.Main:AddGroupbox({
    Side = "Right",
    Name = "Hitbox",
    IconName = "box",
	})

	HBBox:AddToggle("HB_On", {
		Text = "Hitbox Expander",
		Default = false,
		Callback = function(v)
			HB.on = v
			if v then
				scan()
			else
				clearAll()
			end
		end,
	})

	HBBox:AddSlider("HB_Size", {
		Text = "Tamanho da Hitbox",
		Default = 25,
		Min = 5,
		Max = 100,
		Rounding = 0,
		Callback = function(v)
			HB.size = v
			if HB.on then scan() end
		end,
	})

	HBBox:AddToggle("HB_Vis", {
		Text = "Visualize Hitbox",
		Default = false,
		Callback = function(v)
			HB.vis = v
			if v then
				scan()
			else
				clearBoxes()
			end
		end,
	})
end

-- // === UI Settings ===
local MenuGroup = Tabs["UI Settings"]:AddGroupbox({
	Side = "Left",
	Name = "Menu",
	IconName = "wrench",
})

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = false,
	Text = "Open Keybind Menu",
	Callback = function(value) Library.KeybindFrame.Visible = value end,
})
MenuGroup:AddToggle("KeybindMenuVisibilityControl", {
	Default = false,
	Text = "Keybind Menu Visibility",
	Callback = function(value) Library.KeybindMenu:SetVisibilityControl(value) end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = false,
	Callback = function(Value) Library.ShowCustomCursor = Value end,
})
MenuGroup:AddToggle("AlwaysOnTop", {
	Text = "Always On Top",
	Default = false,
	Callback = function(Value) Window:SetAlwaysOnTop(Value) end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "Notification Side",
	Callback = function(Value) Library:SetNotifySide(Value) end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "DPI Scale",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		Library:SetDPIScale(tonumber(Value))
	end,
})
MenuGroup:AddSlider("UICornerSlider", {
	Text = "Corner Radius",
	Default = Library.CornerRadius,
	Min = 0, Max = 20, Rounding = 0,
	Callback = function(value) Window:SetCornerRadius(value) end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
	:AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })

MenuGroup:AddButton("Unload", function()
	SJ.held = false
	sjSetPower(SJ_DEFAULT_JUMP)
	sbClear()
	Toggles.SA_Soru:SetValue(false)
	Toggles.AimbotSoru:SetValue(false)
	Toggles.InfinitySoru:SetValue(false)
	Toggles.FastAttack:SetValue(false)
	Toggles.ZBoost:SetValue(false)
	Toggles.M1Extender:SetValue(false)
	Toggles.SkillSoru:SetValue(false)
	Toggles.WalkWater:SetValue(false)
	Toggles.AntiStun:SetValue(false)
	if WW.platform then
		pcall(function() WW.platform:Destroy() end)
		WW.platform = nil
	end
	Library:Unload()
end)

Library.ToggleKeybind = Options.MenuKeybind

-- // === Managers ===
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("MyScriptHub")
SaveManager:SetFolder("MyScriptHub/specific-game")
SaveManager:SetSubFolder("specific-place")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()
