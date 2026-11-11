-- LocalScript: StarterPlayerScripts > Titulo
-- Tela de entrada: logo SHINOBI LEGENDS (SL) com PLAY e OPTIONS, sobre uma vista aérea da vila.
-- PLAY marca player:SetAttribute("Jogando", true); o ClanClient então abre a sala da roleta para quem não tem clã.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "Titulo"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Parent = pg

local raiz = Instance.new("TextButton") -- botão invisível: segura os cliques para não socar atrás da tela
raiz.Size = UDim2.fromScale(1, 1)
raiz.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
raiz.BackgroundTransparency = 0.45
raiz.Text = ""
raiz.AutoButtonColor = false
raiz.Parent = gui
local grad = Instance.new("UIGradient")
grad.Rotation = 90
grad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 0) })
grad.Parent = raiz

local centro = Instance.new("Frame")
centro.AnchorPoint = Vector2.new(0.5, 0.5)
centro.Position = UDim2.fromScale(0.5, 0.5)
centro.Size = UDim2.fromOffset(760, 520)
centro.BackgroundTransparency = 1
centro.Parent = raiz
local escala = Instance.new("UIScale")
escala.Parent = centro
local function ajustar()
	local vp = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(vp.X / 820, vp.Y / 560), 0.4, 1.2)
end
ajustar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)

local LARANJA = Color3.fromRGB(255, 140, 40)

-- emblema: losango escuro com borda laranja e as letras SL
local losango = Instance.new("Frame")
losango.AnchorPoint = Vector2.new(0.5, 0.5)
losango.Position = UDim2.new(0.5, 0, 0, 96)
losango.Size = UDim2.fromOffset(120, 120)
losango.Rotation = 45
losango.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
losango.Parent = centro
Instance.new("UICorner", losango).CornerRadius = UDim.new(0, 16)
local bl = Instance.new("UIStroke")
bl.Color = LARANJA
bl.Thickness = 5
bl.Parent = losango
local sl = Instance.new("TextLabel")
sl.AnchorPoint = Vector2.new(0.5, 0.5)
sl.Position = UDim2.new(0.5, 0, 0, 96)
sl.Size = UDim2.fromOffset(140, 90)
sl.BackgroundTransparency = 1
sl.Text = "SL"
sl.Font = Enum.Font.GothamBlack
sl.TextSize = 64
sl.TextColor3 = Color3.new(1, 1, 1)
sl.Parent = centro

local function texto(t, tam, cor, y, alt)
	local l = Instance.new("TextLabel")
	l.Position = UDim2.fromOffset(0, y)
	l.Size = UDim2.new(1, 0, 0, alt)
	l.BackgroundTransparency = 1
	l.Text = t
	l.Font = Enum.Font.GothamBlack
	l.TextSize = tam
	l.TextColor3 = cor
	l.Parent = centro
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(10, 10, 14)
	s.Thickness = 3
	s.Parent = l
	return l
end
texto("SHINOBI", 78, Color3.new(1, 1, 1), 186, 80)
texto("LEGENDS", 78, LARANJA, 258, 80)

local function botao(t, cor, y)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(0.5, 0)
	b.Position = UDim2.new(0.5, 0, 0, y)
	b.Size = UDim2.fromOffset(300, 58)
	b.BackgroundColor3 = cor
	b.Text = t
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 26
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = centro
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 12)
	return b
end
local playBtn = botao("PLAY", LARANJA, 370)
local optBtn = botao("OPTIONS", Color3.fromRGB(38, 38, 44), 440)
Instance.new("UIStroke", optBtn).Color = Color3.fromRGB(90, 90, 100)

---------------------------------------------------------------
-- Esconde o resto da interface e trava o personagem enquanto a entrada está aberta
---------------------------------------------------------------
local OUTRAS = { "HUD", "HudOnda", "HudPoderes" }
local function outras(ligar)
	for _, n in ipairs(OUTRAS) do
		local g = pg:FindFirstChild(n)
		if g and g:IsA("ScreenGui") then g.Enabled = ligar end
	end
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, ligar) end)
end
-- trava andar e pular: engole as teclas de movimento enquanto a entrada está aberta
local ContextActionService = game:GetService("ContextActionService")
local K = Enum.KeyCode
ContextActionService:BindActionAtPriority("TravaTitulo", function()
	return Enum.ContextActionResult.Sink
end, false, 3000, K.W, K.A, K.S, K.D, K.Up, K.Down, K.Left, K.Right, K.Space, K.LeftShift, K.Thumbstick1, K.ButtonA, K.F, K.T)

-- câmera girando devagar por cima da praça
local function centroVila()
	local s = workspace:FindFirstChild("SpawnLocation")
	return s and s.Position or Vector3.new(64, 3, 30)
end
local function camera(ligar)
	local cam = workspace.CurrentCamera
	RunService:UnbindFromRenderStep("CameraTitulo")
	if ligar then
		RunService:BindToRenderStep("CameraTitulo", Enum.RenderPriority.Camera.Value + 1, function()
			local c = centroVila()
			local a = os.clock() * 0.06
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = CFrame.lookAt(c + Vector3.new(math.cos(a) * 80, 42, math.sin(a) * 80), c + Vector3.new(0, 8, 0))
		end)
	else
		cam.CameraType = Enum.CameraType.Custom
	end
end

-- as outras telas são criadas por outros scripts; esconde de novo conforme forem aparecendo
local vigiando = true
task.spawn(function()
	while vigiando do
		if raiz.Visible then outras(false) end
		task.wait(0.5)
	end
end)
outras(false)
camera(true)

playBtn.MouseButton1Click:Connect(function()
	if not gui.Enabled then return end
	vigiando = false
	TweenService:Create(raiz, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
	centro.Visible = false
	task.wait(0.3)
	gui.Enabled = false
	camera(false)
	outras(true)
	ContextActionService:UnbindAction("TravaTitulo")
	player:SetAttribute("Jogando", true)
end)

-- OPTIONS abre o painel de Configurações do HUD; quando ele fecha, a entrada volta
optBtn.MouseButton1Click:Connect(function()
	raiz.Visible = false
	local hud = pg:FindFirstChild("HUD")
	if hud then hud.Enabled = true end
	player:SetAttribute("PedirConfig", os.clock())
end)
player:GetAttributeChangedSignal("ConfigFechou"):Connect(function()
	if gui.Enabled and not player:GetAttribute("Jogando") then
		raiz.Visible = true
		outras(false)
	end
end)
