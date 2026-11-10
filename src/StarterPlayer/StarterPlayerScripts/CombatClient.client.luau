-- LocalScript: StarterPlayerScripts > CombatClient
-- Clique / toque / F = combo. X (segurar) = soco carregado, Y = soco aéreo, C = soco com investida. Também mostra o aviso das ondas e a barra do boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local attackEvent = ReplicatedStorage:WaitForChild("Attack")
local statusEvent = ReplicatedStorage:WaitForChild("RunStatus")

local gui = Instance.new("ScreenGui")
gui.Name = "HudOnda"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local texto = Instance.new("TextLabel")
texto.Size = UDim2.fromOffset(700, 40)
texto.Position = UDim2.new(0.5, -350, 0, 14)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.GothamBlack
texto.TextSize = 26
texto.TextColor3 = Color3.new(1, 1, 1)
texto.TextStrokeTransparency = 0.3
texto.Text = ""
texto.Parent = gui

local bossFrame = Instance.new("Frame")
bossFrame.Size = UDim2.fromOffset(420, 24)
bossFrame.Position = UDim2.new(0.5, -210, 0, 62)
bossFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bossFrame.Visible = false
bossFrame.Parent = gui
Instance.new("UICorner", bossFrame).CornerRadius = UDim.new(0, 6)

local bossBar = Instance.new("Frame")
bossBar.Size = UDim2.new(1, 0, 1, 0)
bossBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
bossBar.BorderSizePixel = 0
bossBar.Parent = bossFrame
Instance.new("UICorner", bossBar).CornerRadius = UDim.new(0, 6)

local bossLabel = Instance.new("TextLabel")
bossLabel.Size = UDim2.new(1, 0, 1, 0)
bossLabel.BackgroundTransparency = 1
bossLabel.Font = Enum.Font.GothamBold
bossLabel.TextSize = 14
bossLabel.TextColor3 = Color3.new(1, 1, 1)
bossLabel.Parent = bossFrame

statusEvent.OnClientEvent:Connect(function(p)
	if p.clear then
		texto.Text = ""
		bossFrame.Visible = false
		return
	end
	texto.Text = p.text or ""
	if p.boss then
		bossFrame.Visible = true
		bossBar.Size = UDim2.new(math.clamp(p.boss.hp / p.boss.max, 0, 1), 0, 1, 0)
		bossLabel.Text = ("%s   %d / %d"):format(p.boss.name, math.ceil(p.boss.hp), p.boss.max)
	else
		bossFrame.Visible = false
	end
end)

---------------------------------------------------------------
-- Golpes: combo, soco carregado (X), soco aéreo (Y) e soco com investida (C)
---------------------------------------------------------------

local CD = { X = 3, Y = 3, C = 4 }
local readyAt = { X = 0, Y = 0, C = 0 }

local function raiz()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function inimigoPerto(root, maxDist)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local best, bestScore
	for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and not m:GetAttribute("Sumido") then
			local dir = (r.Position - root.Position) * Vector3.new(1, 0, 1)
			if dir.Magnitude <= maxDist then
				local score = dir.Magnitude - (dir.Magnitude > 0.1 and dir.Unit:Dot(look) or 1) * 10
				if not bestScore or score < bestScore then
					best, bestScore = dir.Unit, score
				end
			end
		end
	end
	return best
end

-- combo
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F then
		attackEvent:FireServer("combo")
	end
end)

-- barra de recarga dos golpes extras
local barra = Instance.new("Frame")
barra.Size = UDim2.fromOffset(168, 66)
barra.Position = UDim2.new(0.5, -159 - 178, 1, -84)
barra.BackgroundTransparency = 1
barra.Parent = gui

local slots = {}
for i, info in ipairs({ { "X", "Charge" }, { "Y", "Air" }, { "C", "Dash" } }) do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(52, 52)
	f.Position = UDim2.fromOffset((i - 1) * 58, 7)
	f.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	f.BackgroundTransparency = 0.2
	f.Parent = barra
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local shade = Instance.new("Frame")
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Parent = f
	Instance.new("UICorner", shade).CornerRadius = UDim.new(0, 8)
	local key = Instance.new("TextLabel")
	key.Size = UDim2.new(1, 0, 0, 24)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBlack
	key.TextSize = 18
	key.TextColor3 = Color3.new(1, 1, 1)
	key.Text = info[1]
	key.Parent = f
	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 0, 1, -18)
	name.Size = UDim2.new(1, 0, 0, 16)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 11
	name.TextColor3 = Color3.fromRGB(220, 220, 230)
	name.Text = info[2]
	name.Parent = f
	local secs = Instance.new("TextLabel")
	secs.Size = UDim2.fromScale(1, 1)
	secs.BackgroundTransparency = 1
	secs.Font = Enum.Font.GothamBlack
	secs.TextSize = 18
	secs.TextColor3 = Color3.new(1, 1, 1)
	secs.TextStrokeTransparency = 0.4
	secs.Text = ""
	secs.Parent = f
	slots[info[1]] = { shade = shade, secs = secs }
end

RunService.RenderStepped:Connect(function()
	for k, s in pairs(slots) do
		local left = readyAt[k] - os.clock()
		if left > 0 then
			s.shade.Size = UDim2.fromScale(1, math.clamp(left / CD[k], 0, 1))
			s.secs.Text = ("%.1f"):format(left)
		else
			s.shade.Size = UDim2.fromScale(1, 0)
			s.secs.Text = ""
		end
	end
end)

-- X: segurar para carregar, soltar para bater
local charging, chargeStart, chargeBall, chargeConn
local function pararCarga()
	charging = false
	if chargeConn then
		chargeConn:Disconnect()
		chargeConn = nil
	end
	if chargeBall then
		chargeBall:Destroy()
		chargeBall = nil
	end
end

local function acaoCarregado(_, estado)
	if estado == Enum.UserInputState.Begin then
		if os.clock() < readyAt.X or charging then
			return Enum.ContextActionResult.Sink
		end
		charging, chargeStart = true, os.clock()
		chargeBall = Instance.new("Part")
		chargeBall.Shape = Enum.PartType.Ball
		chargeBall.Material = Enum.Material.Neon
		chargeBall.Color = Color3.fromRGB(255, 230, 160)
		chargeBall.Transparency = 0.3
		chargeBall.Anchored, chargeBall.CanCollide, chargeBall.CanQuery, chargeBall.CanTouch = true, false, false, false
		chargeBall.Parent = workspace
		chargeConn = RunService.RenderStepped:Connect(function()
			local char = player.Character
			local mao = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart"))
			if mao and chargeBall then
				chargeBall.Size = Vector3.one * (0.6 + math.min((os.clock() - chargeStart) / 1.2, 1) * 2.4)
				chargeBall.CFrame = mao.CFrame
			end
		end)
	elseif charging then
		local t = os.clock() - chargeStart
		pararCarga()
		readyAt.X = os.clock() + CD.X
		attackEvent:FireServer("charged", t)
	end
	return Enum.ContextActionResult.Sink
end

-- Y: se estiver no chão, pula e bate no ar
local function acaoAereo(_, estado)
	if estado ~= Enum.UserInputState.Begin or os.clock() < readyAt.Y then
		return Enum.ContextActionResult.Sink
	end
	local root, hum = raiz()
	if not root or not hum or hum.Health <= 0 then
		return Enum.ContextActionResult.Sink
	end
	readyAt.Y = os.clock() + CD.Y
	if hum.FloorMaterial ~= Enum.Material.Air then
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 55, root.AssemblyLinearVelocity.Z)
		task.delay(0.3, function()
			attackEvent:FireServer("air")
		end)
	else
		attackEvent:FireServer("air")
	end
	return Enum.ContextActionResult.Sink
end

-- C: avança na direção do inimigo mais próximo (ou para a frente) batendo em quem tocar
local function acaoInvestida(_, estado)
	if estado ~= Enum.UserInputState.Begin or os.clock() < readyAt.C then
		return Enum.ContextActionResult.Sink
	end
	local root, hum = raiz()
	if not root or not hum or hum.Health <= 0 then
		return Enum.ContextActionResult.Sink
	end
	readyAt.C = os.clock() + CD.C
	local dir = inimigoPerto(root, 28)
	if not dir then
		local l = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		dir = l.Magnitude > 0.01 and l.Unit or Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	attackEvent:FireServer("dash")
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.28 and root.Parent do
			root.AssemblyLinearVelocity = dir * 85 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			RunService.Heartbeat:Wait()
		end
	end)
	return Enum.ContextActionResult.Sink
end

local acoes = {
	{ "SocoCarregado", acaoCarregado, Enum.KeyCode.X, "X", UDim2.new(1, -75, 1, -110) },
	{ "SocoAereo", acaoAereo, Enum.KeyCode.Y, "Y", UDim2.new(1, -75, 1, -190) },
	{ "SocoInvestida", acaoInvestida, Enum.KeyCode.C, "C", UDim2.new(1, -75, 1, -270) },
}
for _, a in ipairs(acoes) do
	ContextActionService:BindAction(a[1], a[2], true, a[3])
	ContextActionService:SetTitle(a[1], a[4])
	ContextActionService:SetPosition(a[1], a[5])
end
