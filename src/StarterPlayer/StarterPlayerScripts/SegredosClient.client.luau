-- LocalScript: StarterPlayerScripts > SegredosClient
-- Easter eggs do leste (veja SegredosData): avisos, santuario secreto (so aparece para quem achou os 3 selos),
-- botoes dos poderes (teclas B, N, M e L) e a recarga de cada um. O servidor decide tudo; aqui so se mostra.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local SegredosData = require(ReplicatedStorage:WaitForChild("SegredosData"))
local acao = ReplicatedStorage:WaitForChild("SegredosAcao")
local aviso = ReplicatedStorage:WaitForChild("SegredosAviso")

local COR_FUNDO = Color3.fromRGB(20, 22, 32)
local COR_TEXTO = Color3.fromRGB(240, 242, 250)
local COR_FRACO = Color3.fromRGB(160, 165, 185)

---------------------------------------------------------------
-- Estado (publicado pelo servidor no atributo "SegredosEstado")
---------------------------------------------------------------
local estado = { Simbolos = {}, Pegos = {}, Completo = false, AltarY = 3 }
local function lerEstado()
	local j = player:GetAttribute("SegredosEstado")
	if type(j) ~= "string" then return end
	local ok, e = pcall(function() return HttpService:JSONDecode(j) end)
	if ok and type(e) == "table" then
		e.Pegos = type(e.Pegos) == "table" and e.Pegos or {}
		e.Simbolos = type(e.Simbolos) == "table" and e.Simbolos or {}
		estado = e
	end
end

local function claOk(def)
	return def.Cla == nil or player:GetAttribute("Cla") == def.Cla
end

-- rank ninja minimo do poder (Tesouros do Sabio: Jonin ou maior); o atributo "Rank" vem do servidor
local function rankOk(def)
	if def.RankMin == nil then return true end
	local meu = SegredosData.RankOrdem[player:GetAttribute("Rank")] or 0
	return meu >= (SegredosData.RankOrdem[def.RankMin] or 99)
end

local function desbloqueado(id)
	local def = SegredosData.Poderes[id]
	return def ~= nil and estado.Pegos[id] == true and claOk(def) and rankOk(def)
end

---------------------------------------------------------------
-- Interface: aviso no topo e botoes dos poderes
---------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SegredosGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.Parent = player:WaitForChild("PlayerGui")

local function canto(parent, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = parent
end

local toast = Instance.new("Frame")
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.Size = UDim2.fromOffset(460, 78)
toast.Position = UDim2.new(0.5, 0, 0, 110)
toast.BackgroundColor3 = COR_FUNDO
toast.BackgroundTransparency = 0.08
toast.Visible = false
toast.Parent = gui
canto(toast, 12)
local toastBorda = Instance.new("UIStroke")
toastBorda.Thickness = 3
toastBorda.Parent = toast
local toastTitulo = Instance.new("TextLabel")
toastTitulo.BackgroundTransparency = 1
toastTitulo.Position = UDim2.fromOffset(12, 6)
toastTitulo.Size = UDim2.new(1, -24, 0, 28)
toastTitulo.Font = Enum.Font.GothamBlack
toastTitulo.TextSize = 22
toastTitulo.TextColor3 = COR_TEXTO
toastTitulo.TextXAlignment = Enum.TextXAlignment.Left
toastTitulo.Parent = toast
local toastSub = Instance.new("TextLabel")
toastSub.BackgroundTransparency = 1
toastSub.Position = UDim2.fromOffset(12, 34)
toastSub.Size = UDim2.new(1, -24, 0, 38)
toastSub.Font = Enum.Font.GothamBold
toastSub.TextSize = 14
toastSub.TextWrapped = true
toastSub.TextColor3 = COR_FRACO
toastSub.TextXAlignment = Enum.TextXAlignment.Left
toastSub.TextYAlignment = Enum.TextYAlignment.Top
toastSub.Parent = toast

local CORES_AVISO = {
	seal = Color3.fromRGB(245, 205, 90),
	reveal = Color3.fromRGB(150, 220, 255),
	info = Color3.fromRGB(150, 155, 175),
	erro = Color3.fromRGB(235, 80, 80),
}
local toastToken = 0
local function mostrar(tipo, titulo, sub, cor)
	toastToken += 1
	local meu = toastToken
	toastTitulo.Text = titulo
	toastSub.Text = sub or ""
	toastBorda.Color = cor or CORES_AVISO[tipo] or CORES_AVISO.info
	toast.Position = UDim2.new(0.5, 0, 0, 90)
	toast.Visible = true
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 110) }):Play()
	task.delay(tipo == "reveal" and 7 or 4.5, function()
		if toastToken == meu then toast.Visible = false end
	end)
end

aviso.OnClientEvent:Connect(function(tipo, titulo, sub)
	mostrar(tipo, titulo, sub)
end)

-- botoes dos poderes (canto inferior direito, ao lado dos botoes de toque do combate)
local barra = Instance.new("Frame")
barra.AnchorPoint = Vector2.new(1, 1)
barra.Position = UDim2.new(1, -100, 1, -16)
barra.Size = UDim2.fromOffset(300, 68)
barra.BackgroundTransparency = 1
barra.Parent = gui
local lista = Instance.new("UIListLayout")
lista.FillDirection = Enum.FillDirection.Horizontal
lista.HorizontalAlignment = Enum.HorizontalAlignment.Right
lista.VerticalAlignment = Enum.VerticalAlignment.Bottom
lista.SortOrder = Enum.SortOrder.LayoutOrder
lista.Padding = UDim.new(0, 8)
lista.Parent = barra
local escala = Instance.new("UIScale")
escala.Parent = barra

local chips = {} -- [id] = { botao, sombra, tempo, ate, total }
for i, id in ipairs(SegredosData.Ordem) do
	local def = SegredosData.Poderes[id]
	local b = Instance.new("TextButton")
	b.Name = "Poder_" .. id
	b.LayoutOrder = i
	b.Size = UDim2.fromOffset(64, 64)
	b.BackgroundColor3 = COR_FUNDO
	b.AutoButtonColor = false
	b.Text = def.Emoji
	b.TextSize = 32
	b.Font = Enum.Font.GothamBlack
	b.Visible = false
	b.ClipsDescendants = true
	b.Parent = barra
	canto(b, 12)
	local borda = Instance.new("UIStroke")
	borda.Color = def.Cor
	borda.Thickness = 3
	borda.Parent = b
	local sombra = Instance.new("Frame")
	sombra.AnchorPoint = Vector2.new(0, 1)
	sombra.Position = UDim2.fromScale(0, 1)
	sombra.Size = UDim2.fromScale(1, 0)
	sombra.BackgroundColor3 = Color3.new(0, 0, 0)
	sombra.BackgroundTransparency = 0.35
	sombra.BorderSizePixel = 0
	sombra.Parent = b
	local tempo = Instance.new("TextLabel")
	tempo.BackgroundTransparency = 1
	tempo.Size = UDim2.fromScale(1, 1)
	tempo.Font = Enum.Font.GothamBlack
	tempo.TextSize = 22
	tempo.TextColor3 = COR_TEXTO
	tempo.Text = ""
	tempo.ZIndex = 3
	tempo.Parent = b
	local tecla = Instance.new("TextLabel")
	tecla.BackgroundColor3 = def.Cor
	tecla.Position = UDim2.new(1, -20, 1, -20)
	tecla.Size = UDim2.fromOffset(18, 18)
	tecla.Font = Enum.Font.GothamBlack
	tecla.TextSize = 13
	tecla.TextColor3 = Color3.new(0, 0, 0)
	tecla.Text = def.Tecla
	tecla.ZIndex = 4
	tecla.Parent = b
	canto(tecla, 5)
	chips[id] = { botao = b, borda = borda, sombra = sombra, tempo = tempo, ate = 0, total = def.Cooldown }
end

local function atualizarChips()
	local jogando = player:GetAttribute("Jogando") == true
	for id, c in pairs(chips) do
		c.botao.Visible = jogando and desbloqueado(id)
	end
end

-- o leque (Bashosen) mostra no botao o PROXIMO elemento da fila (o servidor guarda no atributo "BashosenElem")
local function atualizarElemento()
	local c = chips.bashosen
	local def = SegredosData.Poderes.bashosen
	if not (c and def and def.Elementos) then return end
	local el = def.Elementos[player:GetAttribute("BashosenElem") or 1] or def.Elementos[1]
	c.botao.Text = el.Emoji
	c.borda.Color = el.Cor
end

local ocupado = false
local function usar(id)
	local def = SegredosData.Poderes[id]
	local c = chips[id]
	if not def or not c or not desbloqueado(id) then return end
	if c.ate > os.clock() or ocupado then return end
	ocupado = true
	local ok, r = pcall(function() return acao:InvokeServer("usar", id) end)
	ocupado = false
	if not ok or type(r) ~= "table" then return end
	if r.ok then
		c.total = r.cd or def.Cooldown
		c.ate = os.clock() + c.total
	elseif r.resta then
		c.total = def.Cooldown
		c.ate = os.clock() + r.resta
	elseif r.semChakra then
		-- sem chakra suficiente o poder nao dispara (nada e gasto)
		mostrar("erro", "Not enough chakra!", ("%s needs %d%% of your chakra."):format(def.Nome, math.floor((def.Chakra or 0) * 100 + 0.5)), Color3.fromRGB(80, 170, 255))
	elseif r.erro then
		mostrar("erro", def.Nome, r.erro, def.Cor)
	end
end

for id, c in pairs(chips) do
	c.botao.Activated:Connect(function() usar(id) end)
	local def = SegredosData.Poderes[id]
	ContextActionService:BindAction("Segredo_" .. id, function(_, st)
		if not desbloqueado(id) then return Enum.ContextActionResult.Pass end
		if st == Enum.UserInputState.Begin then usar(id) end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode[def.Tecla])
end

local function ajustarEscala()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	escala.Scale = require(game:GetService("ReplicatedStorage"):WaitForChild("HudEscala")).Barras(vp)
end
ajustarEscala()

---------------------------------------------------------------
-- Santuario secreto (desenhado so aqui no cliente: so quem achou os 3 selos ve)
---------------------------------------------------------------
local altar, pilar, pedestais = nil, nil, {}

local function neon(parent, nome, tamanho, cf, cor, transp)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = cor
	p.Transparency = transp or 0
	p.Size = tamanho
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function disco(parent, nome, altura, diametro, cf, cor, material, colide)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Shape = Enum.PartType.Cylinder
	p.CanCollide = colide ~= false
	p.Material = material
	p.Color = cor
	p.Size = Vector3.new(altura, diametro, diametro)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	p.Parent = parent
	return p
end

local function construirAltar()
	if altar then return end
	local c = Vector3.new(SegredosData.Altar.X, estado.AltarY or 3, SegredosData.Altar.Z)
	altar = Instance.new("Folder")
	altar.Name = "SantuarioSecreto"
	altar.Parent = workspace

	disco(altar, "Piso", 0.6, 14, CFrame.new(c + Vector3.new(0, 0.3, 0)), Color3.fromRGB(42, 46, 58), Enum.Material.Slate)
	disco(altar, "Anel", 0.2, 12, CFrame.new(c + Vector3.new(0, 0.65, 0)), Color3.fromRGB(190, 225, 255), Enum.Material.Neon, false).Transparency = 0.35

	local n = #SegredosData.Ordem
	for i, id in ipairs(SegredosData.Ordem) do
		local def = SegredosData.Poderes[id]
		local ang = math.rad(90 + (i - 1) * 360 / n)
		local pos = c + Vector3.new(math.cos(ang) * 5.2, 0, math.sin(ang) * 5.2)
		local base = disco(altar, "Pedestal_" .. id, 2.4, 3.2, CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(92, 94, 104), Enum.Material.Slate)
		disco(altar, "Topo_" .. id, 0.3, 2.6, CFrame.new(pos + Vector3.new(0, 2.8, 0)), def.Cor, Enum.Material.Neon, false)

		local flut = neon(altar, "Flutuante_" .. id, Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, 5.2, 0)), def.Cor, 1)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(150, 120)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 90
		bb.Adornee = flut
		bb.Parent = flut
		local icone = Instance.new("TextLabel")
		icone.BackgroundTransparency = 1
		icone.Size = UDim2.new(1, 0, 0, 70)
		icone.Text = def.Emoji
		icone.TextScaled = true
		icone.Font = Enum.Font.GothamBlack
		icone.Parent = bb
		local nome = Instance.new("TextLabel")
		nome.BackgroundTransparency = 1
		nome.Position = UDim2.fromOffset(0, 70)
		nome.Size = UDim2.new(1, 0, 0, 50)
		nome.TextSize = 15
		nome.TextWrapped = true
		nome.Font = Enum.Font.GothamBlack
		nome.TextColor3 = COR_TEXTO
		nome.TextStrokeTransparency = 0.4
		nome.Parent = bb

		local luz = Instance.new("PointLight")
		luz.Color = def.Cor
		luz.Range = 12
		luz.Brightness = 1.2
		luz.Parent = base

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Awaken"
		prompt.ObjectText = def.Nome
		prompt.HoldDuration = 1.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.Parent = base
		prompt.Triggered:Connect(function()
			local ok, r = pcall(function() return acao:InvokeServer("pegar", id) end)
			if not ok or type(r) ~= "table" then return end
			if r.ok then
				mostrar("poder", def.Nome .. " awakened!", ("Press %s to use it. %s"):format(def.Tecla, def.Desc), def.Cor)
			else
				mostrar("erro", def.Nome, r.erro or "...", def.Cor)
			end
		end)

		pedestais[id] = { flut = flut, bb = bb, icone = icone, nome = nome, prompt = prompt, fase = i * 1.7 }
	end

	-- pilar de luz que mostra de longe onde fica o santuario
	pilar = neon(altar, "Pilar", Vector3.new(2.5, 320, 2.5), CFrame.new(c + Vector3.new(0, 160, 0)), Color3.fromRGB(200, 230, 255), 1)
end

local function atualizarAltar()
	if not estado.Completo then return end
	local primeira = altar == nil
	construirAltar()
	local alguem = false
	for id, p in pairs(pedestais) do
		local def = SegredosData.Poderes[id]
		local pegou = estado.Pegos[id] == true
		if pegou then
			p.icone.TextTransparency = 0.6
			p.nome.Text = def.Nome .. "\nAWAKENED"
			p.prompt.Enabled = false
		elseif not claOk(def) then
			p.icone.TextTransparency = 0.45
			p.nome.Text = ("%s\n%s clan only"):format(def.Nome, def.ClaNome or def.Cla)
			p.prompt.ActionText = "Locked"
			p.prompt.Enabled = true
		elseif not rankOk(def) then
			p.icone.TextTransparency = 0.45
			p.nome.Text = ("%s\n%s rank only"):format(def.Nome, def.RankNome or def.RankMin)
			p.prompt.ActionText = "Locked"
			p.prompt.Enabled = true
		else
			p.icone.TextTransparency = 0
			p.nome.Text = def.Nome
			p.prompt.ActionText = "Awaken"
			p.prompt.Enabled = true
			alguem = true
		end
	end
	if pilar then
		TweenService:Create(pilar, TweenInfo.new(primeira and 3 or 0.8), { Transparency = alguem and 0.55 or 1 }):Play()
	end
end

-- emoji flutuando de leve em cima de cada pedestal
RunService.Heartbeat:Connect(function()
	local agora = os.clock()
	for id, c in pairs(chips) do
		if c.botao.Visible then
			local resta = c.ate - agora
			if resta > 0 then
				c.sombra.Size = UDim2.fromScale(1, math.clamp(resta / c.total, 0, 1))
				c.tempo.Text = tostring(math.ceil(resta))
			elseif c.tempo.Text ~= "" then
				c.sombra.Size = UDim2.fromScale(1, 0)
				c.tempo.Text = ""
			end
		end
	end
	for _, p in pairs(pedestais) do
		if p.bb.Parent then
			p.bb.StudsOffsetWorldSpace = Vector3.new(0, math.sin(agora * 2 + p.fase) * 0.35, 0)
		end
	end
end)

local function tudo()
	lerEstado()
	atualizarChips()
	atualizarElemento()
	atualizarAltar()
end
for _, nome in ipairs({ "SegredosEstado", "Cla", "Jogando", "Rank", "BashosenElem" }) do
	player:GetAttributeChangedSignal(nome):Connect(tudo)
end
local cam = workspace.CurrentCamera
if cam then cam:GetPropertyChangedSignal("ViewportSize"):Connect(ajustarEscala) end
tudo()
