-- LocalScript: StarterPlayerScripts > AbilityClient
-- Poderes: Q e E (básicos) e R (forte). No celular aparecem 3 botões.
-- Mostra os 3 poderes do personagem equipado com a recarga na parte de baixo da tela.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local useEvent = ReplicatedStorage:WaitForChild("UseAbility")
local feedbackEvent = ReplicatedStorage:WaitForChild("AbilityFeedback")

local player = Players.LocalPlayer
local KEYS = { "Q", "E", "R" }
local COLORS = {
	kenji_arashi = Color3.fromRGB(70, 170, 255),
	ren_kuroba = Color3.fromRGB(255, 120, 30),
	hana_midori = Color3.fromRGB(150, 210, 255),
}
local readyAt = { 0, 0, 0 }
local total = { 1, 1, 1 }

---------------------------------------------------------------
-- HUD
---------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HudPoderes"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local barra = Instance.new("Frame")
barra.Size = UDim2.fromOffset(318, 66)
barra.Position = UDim2.new(0.5, -159, 1, -84)
barra.BackgroundTransparency = 1
barra.Visible = false
barra.Parent = gui

local aviso = Instance.new("TextLabel")
aviso.Size = UDim2.fromOffset(400, 24)
aviso.Position = UDim2.new(0.5, -200, 1, -116)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.GothamBold
aviso.TextSize = 16
aviso.TextColor3 = Color3.fromRGB(255, 120, 120)
aviso.TextStrokeTransparency = 0.4
aviso.Text = ""
aviso.Parent = gui

local slots = {}
for i = 1, 3 do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(100, 62)
	f.Position = UDim2.fromOffset((i - 1) * 109, 0)
	f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	f.BackgroundTransparency = 0.15
	f.ClipsDescendants = true
	f.Parent = barra
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", f)
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(80, 80, 100)

	local tecla = Instance.new("TextLabel")
	tecla.Size = UDim2.fromOffset(22, 18)
	tecla.Position = UDim2.fromOffset(6, 4)
	tecla.BackgroundTransparency = 1
	tecla.Font = Enum.Font.GothamBlack
	tecla.TextSize = 15
	tecla.TextColor3 = Color3.new(1, 1, 1)
	tecla.TextXAlignment = Enum.TextXAlignment.Left
	tecla.Text = KEYS[i]
	tecla.ZIndex = 3
	tecla.Parent = f

	local nome = Instance.new("TextLabel")
	nome.Size = UDim2.new(1, -10, 0, 30)
	nome.Position = UDim2.fromOffset(5, 24)
	nome.BackgroundTransparency = 1
	nome.Font = Enum.Font.GothamBold
	nome.TextSize = 12
	nome.TextWrapped = true
	nome.TextColor3 = Color3.new(1, 1, 1)
	nome.ZIndex = 3
	nome.Parent = f

	local sombra = Instance.new("Frame")
	sombra.AnchorPoint = Vector2.new(0, 1)
	sombra.Position = UDim2.fromScale(0, 1)
	sombra.Size = UDim2.fromScale(1, 0)
	sombra.BackgroundColor3 = Color3.new(0, 0, 0)
	sombra.BackgroundTransparency = 0.35
	sombra.BorderSizePixel = 0
	sombra.ZIndex = 2
	sombra.Parent = f

	local tempo = Instance.new("TextLabel")
	tempo.Size = UDim2.fromOffset(40, 18)
	tempo.Position = UDim2.new(1, -44, 0, 4)
	tempo.BackgroundTransparency = 1
	tempo.Font = Enum.Font.GothamBlack
	tempo.TextSize = 14
	tempo.TextColor3 = Color3.fromRGB(255, 220, 120)
	tempo.TextXAlignment = Enum.TextXAlignment.Right
	tempo.ZIndex = 4
	tempo.Text = ""
	tempo.Parent = f

	slots[i] = { frame = f, stroke = stroke, nome = nome, sombra = sombra, tempo = tempo }
end

local avisoAte = 0
local function mostrarAviso(t)
	aviso.Text = t
	avisoAte = os.clock() + 2.5
end

local function personagem()
	local id = player:GetAttribute("Equipped")
	local c = id and CharacterData.GetCharacter(id)
	if c and c.Abilities then
		return id, c
	end
	return nil
end

local function atualizarNomes()
	local id, c = personagem()
	barra.Visible = c ~= nil
	if not c then
		return
	end
	for i = 1, 3 do
		slots[i].nome.Text = c.Abilities[i].Name
		slots[i].stroke.Color = COLORS[id] or Color3.fromRGB(80, 80, 100)
		if i == 3 then
			slots[i].stroke.Thickness = 3
		end
	end
end

player:GetAttributeChangedSignal("Equipped"):Connect(function()
	readyAt = { 0, 0, 0 }
	atualizarNomes()
end)
atualizarNomes()

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = 1, 3 do
		local left = readyAt[i] - now
		if left > 0 then
			slots[i].sombra.Size = UDim2.fromScale(1, math.clamp(left / total[i], 0, 1))
			slots[i].tempo.Text = tostring(math.ceil(left))
		else
			slots[i].sombra.Size = UDim2.fromScale(1, 0)
			slots[i].tempo.Text = ""
		end
	end
	if now > avisoAte then
		aviso.Text = ""
	end
end)

---------------------------------------------------------------
-- Usar poder
---------------------------------------------------------------

-- investida do Lightning Hand (Tatashi): o movimento do personagem é feito aqui no cliente
local function investida()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	task.delay(0.22, function()
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.1 then
			return
		end
		look = look.Unit
		local t0 = os.clock()
		while os.clock() - t0 < 0.18 and root.Parent do
			root.AssemblyLinearVelocity = look * 95 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

local function usar(slot)
	local id, c = personagem()
	if not c then
		mostrarAviso("Equip a character first (Collection).")
		return
	end
	if os.clock() < readyAt[slot] then
		return
	end
	local cd = c.Abilities[slot].Cooldown
	readyAt[slot] = os.clock() + cd
	total[slot] = cd
	useEvent:FireServer(slot)
	if id == "hana_midori" and slot == 1 then
		investida()
	end
end

local POS_TOQUE = {
	UDim2.new(1, -255, 1, -120),
	UDim2.new(1, -215, 1, -195),
	UDim2.new(1, -140, 1, -230),
}
for i = 1, 3 do
	ContextActionService:BindAction("Poder" .. i, function(_, state)
		if state == Enum.UserInputState.Begin then
			usar(i)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode[KEYS[i]])
	ContextActionService:SetTitle("Poder" .. i, KEYS[i])
	ContextActionService:SetPosition("Poder" .. i, POS_TOQUE[i])
end

feedbackEvent.OnClientEvent:Connect(function(p)
	if p.msg then
		mostrarAviso(p.msg)
	end
	if p.slot then
		readyAt[p.slot] = os.clock() + p.cooldown
		if p.cooldown > 0 then
			total[p.slot] = p.cooldown
		end
	end
end)
