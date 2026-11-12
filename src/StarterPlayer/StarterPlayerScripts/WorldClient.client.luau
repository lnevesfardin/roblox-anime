-- LocalScript: StarterPlayerScripts > WorldClient
-- Fase 6: nome da zona ao entrar no mundo aberto, avisos do servidor (AvisoMundo)
-- e barra de vida do chefe do mundo durante o evento (ReplicatedStorage.MundoEstado).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local WorldData = require(ReplicatedStorage:WaitForChild("WorldData"))

local gui = Instance.new("ScreenGui")
gui.Name = "MundoUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local function texto(parent, props)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.4
	t.TextScaled = true
	for k, v in pairs(props) do t[k] = v end
	t.Parent = parent
	return t
end

---------------------------------------------------------------
-- Nome da zona
---------------------------------------------------------------
local zonaTitulo = texto(gui, {
	Name = "ZonaTitulo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3),
	Size = UDim2.fromScale(0.5, 0.07), Text = "", TextTransparency = 1, TextStrokeTransparency = 1,
})
local zonaSub = texto(zonaTitulo, {
	Name = "Sub", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 1.05),
	Size = UDim2.fromScale(0.5, 0.5), Font = Enum.Font.GothamBold, Text = "",
	TextColor3 = Color3.fromRGB(255, 210, 120), TextTransparency = 1, TextStrokeTransparency = 1,
})

local mostrando = 0
local function mostrarZona(titulo, sub)
	mostrando += 1
	local eu = mostrando
	zonaTitulo.Text = titulo
	zonaSub.Text = sub or ""
	local ti = TweenInfo.new(0.6)
	for _, t in ipairs({ zonaTitulo, zonaSub }) do
		TweenService:Create(t, ti, { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	end
	task.delay(3, function()
		if eu ~= mostrando then return end
		for _, t in ipairs({ zonaTitulo, zonaSub }) do
			TweenService:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

task.spawn(function()
	local zonaAtual = nil
	while true do
		-- some enquanto a tela de entrada (PLAY/OPTIONS) está aberta
		local titulo = gui.Parent and gui.Parent:FindFirstChild("Titulo")
		gui.Enabled = not (titulo and titulo:IsA("ScreenGui") and titulo.Enabled)
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r then
			local z = WorldData.ZonaEm(r.Position)
			if z ~= zonaAtual then
				if z then
					mostrarZona(string.upper(z.Name), z.Faixa)
				elseif zonaAtual then
					mostrarZona("HIDDEN LEAF VILLAGE", "Safe zone")
				end
				zonaAtual = z
			end
		end
		task.wait(0.5)
	end
end)

---------------------------------------------------------------
-- Pergaminhos já lidos somem só para este jogador
---------------------------------------------------------------
local function atualizarPergaminhos()
	local pasta = workspace:FindFirstChild("PergaminhosMundo")
	if not pasta then return end
	local lidos = {}
	for id in string.gmatch(player:GetAttribute("PergaminhosLidos") or "", "[^,]+") do lidos[id] = true end
	for _, rolo in ipairs(pasta:GetChildren()) do
		local some = lidos[rolo:GetAttribute("Id")] == true
		for _, d in ipairs(rolo:GetDescendants()) do
			if d:IsA("BasePart") then d.Transparency = some and 1 or 0
			elseif d:IsA("ProximityPrompt") or d:IsA("PointLight") then d.Enabled = not some end
		end
		rolo.Transparency = some and 1 or 0
	end
end
player:GetAttributeChangedSignal("PergaminhosLidos"):Connect(atualizarPergaminhos)
task.spawn(function()
	workspace:WaitForChild("PergaminhosMundo", 30)
	task.wait(1)
	atualizarPergaminhos()
end)

---------------------------------------------------------------
-- Avisos do servidor
---------------------------------------------------------------
local faixa = Instance.new("Frame")
faixa.Name = "Aviso"
faixa.AnchorPoint = Vector2.new(0.5, 0)
faixa.Position = UDim2.fromScale(0.5, 0.12)
faixa.Size = UDim2.fromScale(0.55, 0.06)
faixa.BackgroundColor3 = Color3.fromRGB(20, 15, 15)
faixa.BackgroundTransparency = 1
faixa.Visible = false
faixa.Parent = gui
Instance.new("UICorner", faixa).CornerRadius = UDim.new(0, 8)
local faixaTexto = texto(faixa, { Size = UDim2.fromScale(0.94, 0.75), Position = UDim2.fromScale(0.03, 0.125), Font = Enum.Font.GothamBold })

local avisoN = 0
ReplicatedStorage:WaitForChild("AvisoMundo").OnClientEvent:Connect(function(d)
	avisoN += 1
	local eu = avisoN
	faixaTexto.Text = d.texto or ""
	faixaTexto.TextColor3 = d.cor or Color3.new(1, 1, 1)
	faixa.Size = d.grande and UDim2.fromScale(0.6, 0.07) or UDim2.fromScale(0.45, 0.05)
	faixa.Visible = true
	faixa.BackgroundTransparency = 0.25
	task.delay(6, function()
		if eu == avisoN then faixa.Visible = false end
	end)
end)

---------------------------------------------------------------
-- Barra do chefe do mundo
---------------------------------------------------------------
local estado = ReplicatedStorage:WaitForChild("MundoEstado")

local barra = Instance.new("Frame")
barra.Name = "ChefeMundo"
barra.AnchorPoint = Vector2.new(0.5, 0)
barra.Position = UDim2.fromScale(0.5, 0.04)
barra.Size = UDim2.fromScale(0.4, 0.028)
barra.BackgroundColor3 = Color3.fromRGB(25, 20, 25)
barra.Visible = false
barra.Parent = gui
Instance.new("UICorner", barra).CornerRadius = UDim.new(0, 6)
local contorno = Instance.new("UIStroke", barra)
contorno.Color = Color3.fromRGB(220, 170, 60)
contorno.Thickness = 2
local enche = Instance.new("Frame")
enche.Size = UDim2.fromScale(1, 1)
enche.BackgroundColor3 = Color3.fromRGB(200, 45, 45)
enche.Parent = barra
Instance.new("UICorner", enche).CornerRadius = UDim.new(0, 6)
local nomeChefe = texto(barra, {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2), Size = UDim2.fromScale(1, 0.9),
	Font = Enum.Font.GothamBlack,
})
local vidaTexto = texto(barra, { Size = UDim2.fromScale(1, 0.8), Position = UDim2.fromScale(0, 0.1), Font = Enum.Font.GothamBold, ZIndex = 3 })

local function atualizar()
	local ativo = estado:GetAttribute("EventoAtivo")
	barra.Visible = ativo == true
	if not ativo then return end
	local v = estado:GetAttribute("EventoVida") or 0
	local mx = math.max(estado:GetAttribute("EventoMax") or 1, 1)
	nomeChefe.Text = string.upper(estado:GetAttribute("EventoNome") or "") .. "  (WORLD BOSS)"
	vidaTexto.Text = string.format("%d / %d", math.ceil(v), math.ceil(mx))
	enche.Size = UDim2.fromScale(math.clamp(v / mx, 0, 1), 1)
end
estado.AttributeChanged:Connect(atualizar)
atualizar()
