-- LocalScript: StarterPlayerScripts > Titulo
-- Tela de entrada: logo SHINOBI LEGENDS (SL) com PLAY e OPTIONS, sobre uma vista aérea da vila.
-- PLAY marca player:SetAttribute("Jogando", true); o ClanClient então abre a sala da roleta para quem não tem clã.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")

-- vinheta de abertura (por cima de tudo, enquanto a tela de entrada aparece embaixo)
task.spawn(function()
	local ok, Vinheta = pcall(function() return require(game:GetService("ReplicatedStorage"):WaitForChild("Vinheta", 10)) end)
	if ok and Vinheta then Vinheta.Abertura() end
end)

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

-- Arte da entrada: cole aqui o ID da imagem enviada ao Roblox, no formato "rbxassetid://123456".
-- Vazio = usa o logo desenhado por código (losango SL + SHINOBI LEGENDS).
local IMAGEM_ENTRADA = ""

local VERMELHO = Color3.fromRGB(225, 40, 45)

-- nuvens vermelhas nos cantos de baixo da tela (bolas pretas com contorno vermelho)
local function nuvens(lado) -- lado = 0 (esquerda) ou 1 (direita)
	local sinal = lado == 0 and 1 or -1
	for _, b in ipairs({ { 40, 30, 150 }, { 150, 10, 120 }, { 235, -10, 90 }, { 90, 110, 100 }, { 185, 80, 70 }, { 20, 150, 80 } }) do
		local c = Instance.new("Frame")
		c.AnchorPoint = Vector2.new(0.5, 0.5)
		c.Position = UDim2.new(lado, sinal * b[1], 1, -b[2])
		c.Size = UDim2.fromOffset(b[3], b[3])
		c.BackgroundColor3 = Color3.fromRGB(12, 8, 10)
		c.Parent = raiz
		Instance.new("UICorner", c).CornerRadius = UDim.new(1, 0)
		local st = Instance.new("UIStroke")
		st.Color = VERMELHO
		st.Thickness = 5
		st.Parent = c
	end
end

-- emblema: losango escuro com borda brilhante e as letras SL em pincelada (sem as listras coloridas)
local brilho = Instance.new("Frame")
brilho.AnchorPoint = Vector2.new(0.5, 0.5)
brilho.Position = UDim2.new(0.5, 0, 0, 160)
brilho.Size = UDim2.fromOffset(228, 228)
brilho.Rotation = 45
brilho.BackgroundColor3 = Color3.new(1, 1, 1)
brilho.Parent = centro
Instance.new("UICorner", brilho).CornerRadius = UDim.new(0, 12)
local gb = Instance.new("UIGradient")
gb.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(170, 90, 255)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 230, 120)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 70, 50)) })
gb.Rotation = -45
gb.Parent = brilho

local losango = Instance.new("CanvasGroup")
losango.AnchorPoint = Vector2.new(0.5, 0.5)
losango.Position = UDim2.new(0.5, 0, 0, 160)
losango.Size = UDim2.fromOffset(208, 208)
losango.Rotation = 45
losango.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
losango.Parent = centro
Instance.new("UICorner", losango).CornerRadius = UDim.new(0, 8)
local function letras(cor, dx, dy, contorno)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.new(0.5, dx, 0, 172 + dy)
	l.Size = UDim2.fromOffset(360, 190)
	l.BackgroundTransparency = 1
	l.Text = "SL"
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 170
	l.TextColor3 = cor
	l.Rotation = -9
	l.Parent = centro
	if contorno then
		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(10, 8, 10)
		st.Thickness = 9
		st.Parent = l
	end
	return l
end
local slSombra = letras(VERMELHO, 9, 9, true)
local sl = letras(Color3.fromRGB(245, 245, 245), 0, 0, true)

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
local nome1 = texto("SHINOBI LEGENDS", 46, Color3.new(1, 1, 1), 306, 50)
if IMAGEM_ENTRADA ~= "" then
	-- a arte já traz o logo: cobre a tela inteira e esconde o logo de código
	local arte = Instance.new("ImageLabel")
	arte.Size = UDim2.fromScale(1, 1)
	arte.BackgroundTransparency = 1
	arte.Image = IMAGEM_ENTRADA
	arte.ScaleType = Enum.ScaleType.Crop
	arte.ZIndex = 0
	arte.Parent = raiz
	raiz.BackgroundTransparency = 0
	grad.Enabled = false
	brilho.Visible, losango.Visible, sl.Visible, slSombra.Visible, nome1.Visible = false, false, false, false, false
end

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
