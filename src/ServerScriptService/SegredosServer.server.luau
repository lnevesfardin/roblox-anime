-- Script: ServerScriptService > SegredosServer
-- Easter eggs do lado leste da vila (veja SegredosData para o passo a passo e os textos).
--  * Cria os 3 selos escondidos (ProximityPrompt, tecla E) e guarda quais cada jogador achou.
--  * SegredosAcao (RemoteFunction): "pegar", idDoPoder  -> libera o poder no santuario (so com os 3 selos, perto do altar e do cla certo)
--                                   "usar", idDoPoder   -> usa o poder (cooldown e efeito no servidor)
--  * SegredosAviso (RemoteEvent): o servidor manda avisos (selo achado, santuario revelado) para o cliente mostrar.
--  * Atributo do jogador "SegredosEstado" (JSON): { Simbolos = {bool,bool,bool}, Pegos = { gene = true }, Completo = bool, AltarY = n }
-- Salvo em PlayerData: data.Segredos = { Simbolos = { ["1"] = true }, Pegos = { gene = true } }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local SegredosData = require(ReplicatedStorage:WaitForChild("SegredosData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local acao = Instance.new("RemoteFunction")
acao.Name = "SegredosAcao"
acao.Parent = ReplicatedStorage

local aviso = Instance.new("RemoteEvent")
aviso.Name = "SegredosAviso"
aviso.Parent = ReplicatedStorage

-- numeros de dano flutuantes (criado tambem por CombatServer/AbilityServer; aqui so se ainda nao existir)
local numeroEvent = ReplicatedStorage:FindFirstChild("DanoNumero")
if not numeroEvent then
	numeroEvent = Instance.new("RemoteEvent")
	numeroEvent.Name = "DanoNumero"
	numeroEvent.Parent = ReplicatedStorage
end

---------------------------------------------------------------
-- Progresso do jogador
---------------------------------------------------------------
local function segredos(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	if type(data.Segredos) ~= "table" then data.Segredos = {} end
	local s = data.Segredos
	if type(s.Simbolos) ~= "table" then s.Simbolos = {} end
	if type(s.Pegos) ~= "table" then s.Pegos = {} end
	return s
end

local function contarSelos(s)
	local n = 0
	for _, sim in ipairs(SegredosData.Simbolos) do
		if s.Simbolos[tostring(sim.Id)] then n += 1 end
	end
	return n
end

local function completo(s)
	return contarSelos(s) >= #SegredosData.Simbolos
end

-- altura do chao no centro do santuario (calculada uma vez; o cliente usa para desenhar o altar)
local altarY = 3

local function publicar(player)
	local s = segredos(player)
	if not s then return end
	local e = { Simbolos = {}, Pegos = {}, Completo = completo(s), AltarY = altarY }
	for _, sim in ipairs(SegredosData.Simbolos) do
		table.insert(e.Simbolos, s.Simbolos[tostring(sim.Id)] == true)
	end
	for id in pairs(SegredosData.Poderes) do
		if s.Pegos[id] then e.Pegos[id] = true end
	end
	player:SetAttribute("SegredosEstado", HttpService:JSONEncode(e))
end

local function salvar(player)
	task.spawn(function() pcall(PlayerData.Save, player) end)
end

---------------------------------------------------------------
-- Selos escondidos no leste
---------------------------------------------------------------
local pasta = workspace:FindFirstChild(SegredosData.Pasta)
if pasta then pasta:Destroy() end
pasta = Instance.new("Folder")
pasta.Name = SegredosData.Pasta
pasta.Parent = workspace

local function paramsChao()
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local ign = { pasta }
	local vila = workspace:FindFirstChild("Vila_Shinobi")
	local lim = vila and vila:FindFirstChild("Limites_Mapa")
	if lim then table.insert(ign, lim) end
	rp.FilterDescendantsInstances = ign
	return rp
end

local function alturaChao(x, z)
	local r = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), paramsChao())
	return r and r.Position.Y or 3
end

altarY = alturaChao(SegredosData.Altar.X, SegredosData.Altar.Z)

-- direcao horizontal (de 4) com mais espaco livre: o selo "olha" para o lado aberto
local function ladoAberto(pos)
	local melhor, melhorDist = Vector3.new(0, 0, 1), -1
	for _, d in ipairs({ Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) }) do
		local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), d * 40, paramsChao())
		local dist = r and (r.Position - pos).Magnitude or 40
		if dist > melhorDist then melhor, melhorDist = d, dist end
	end
	return melhor
end

local function peca(nome, tamanho, cf, cor, material, parent)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = tamanho
	p.CFrame = cf
	p.Color = cor
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- o jogador examinou um selo: guarda o progresso e avisa (selo achado / santuario revelado)
local function acharSelo(player, sim)
	local s = segredos(player)
	if not s then return end
	local k = tostring(sim.Id)
	if s.Simbolos[k] then
		aviso:FireClient(player, "info", "Already studied", "You already studied this seal.")
		return
	end
	s.Simbolos[k] = true
	local n = contarSelos(s)
	local total = #SegredosData.Simbolos
	if n >= total then
		aviso:FireClient(player, "reveal", "ALL " .. total .. " SEALS AWAKENED!", "A hidden sanctuary has appeared on the east side of the village. Follow the pillar of light.")
	else
		local dica = n == 1 and "More seals hide in the corners of the east side of the village." or "One more seal to go."
		aviso:FireClient(player, "seal", ("%s found  (%d/%d)"):format(sim.Nome, n, total), dica)
	end
	publicar(player)
	salvar(player)
end

local function criarSelo(sim)
	local x, z = sim.Pos.X, sim.Pos.Z
	local y = alturaChao(x, z)
	local base = Vector3.new(x, y, z)
	local olhar = ladoAberto(base)
	local m = Instance.new("Model")
	m.Name = "Selo_" .. sim.Id

	local lajeCF = CFrame.lookAt(base + Vector3.new(0, 2.6, 0), base + Vector3.new(0, 2.6, 0) + olhar)
	local laje = peca("Laje", Vector3.new(3.2, 5.2, 0.9), lajeCF, Color3.fromRGB(78, 80, 88), Enum.Material.Slate, m)
	peca("Base", Vector3.new(4.6, 0.7, 2.6), CFrame.lookAt(base + Vector3.new(0, 0.35, 0), base + Vector3.new(0, 0.35, 0) + olhar), Color3.fromRGB(58, 58, 64), Enum.Material.Slate, m)

	-- simbolo brilhando na frente da laje
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.LightInfluence = 0
	gui.Brightness = 1.5
	gui.Parent = laje
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = sim.Emoji
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = sim.Cor
	t.Parent = gui

	local luz = Instance.new("PointLight")
	luz.Color = sim.Cor
	luz.Brightness = 1.4
	luz.Range = 14
	luz.Parent = laje

	local fagulha = Instance.new("ParticleEmitter")
	fagulha.Color = ColorSequence.new(sim.Cor)
	fagulha.LightEmission = 1
	fagulha.Rate = 4
	fagulha.Lifetime = NumberRange.new(1.5, 2.5)
	fagulha.Speed = NumberRange.new(0.5, 1.5)
	fagulha.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	fagulha.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	fagulha.EmissionDirection = Enum.NormalId.Top
	fagulha.Parent = laje

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Examine"
	prompt.ObjectText = sim.Nome
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = laje
	prompt.Triggered:Connect(function(player)
		acharSelo(player, sim)
	end)

	m.PrimaryPart = laje
	m.Parent = pasta
end

for _, sim in ipairs(SegredosData.Simbolos) do
	criarSelo(sim)
end

---------------------------------------------------------------
-- Poderes: efeitos (o servidor decide tudo)
---------------------------------------------------------------
local function inimigosPerto(pos, raio)
	local lista = {}
	for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and m.Parent and not m:GetAttribute("Sumido") then
			local d = Vector3.new(r.Position.X - pos.X, 0, r.Position.Z - pos.Z).Magnitude
			local raioM = math.max(m:GetAttribute("Raio") or 0, 0)
			if d <= raio + raioM and math.abs(r.Position.Y - pos.Y) < 40 then
				table.insert(lista, { model = m, hum = h, root = r, raio = raioM, d = d })
			end
		end
	end
	table.sort(lista, function(a, b) return a.d < b.d end)
	return lista
end

local function anel(pos, diametro, cor, tempo)
	local r = Instance.new("Part")
	r.Anchored = true
	r.CanCollide = false
	r.CanQuery = false
	r.Shape = Enum.PartType.Cylinder
	r.Material = Enum.Material.Neon
	r.Color = cor
	r.Transparency = 0.25
	r.Size = Vector3.new(0.3, 1, 1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	r.Parent = workspace
	TweenService:Create(r, TweenInfo.new(tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, diametro, diametro), Transparency = 1 }):Play()
	Debris:AddItem(r, tempo + 0.1)
end

local function brilho(parent, nome, cor, dur)
	local old = parent:FindFirstChild(nome)
	if old then old:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Name = nome
	hl.FillColor = cor
	hl.FillTransparency = 0.7
	hl.OutlineColor = cor
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = parent
	Debris:AddItem(hl, dur)
	return hl
end

local EFEITOS = {}

-- Gene do Hashirama: cura rapida por alguns segundos
EFEITOS.gene = function(player, def)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (hum and root and hum.Health > 0) then return false, "You can't use it now." end
	local token = (player:GetAttribute("GeneToken") or 0) + 1
	player:SetAttribute("GeneToken", token)
	brilho(char, "GeneBrilho", def.Cor, def.Duracao)
	anel(root.Position - Vector3.new(0, 2.6, 0), 14, def.Cor, 0.7)
	local folhas = Instance.new("ParticleEmitter")
	folhas.Color = ColorSequence.new(def.Cor)
	folhas.LightEmission = 0.6
	folhas.Rate = 14
	folhas.Lifetime = NumberRange.new(0.8, 1.4)
	folhas.Speed = NumberRange.new(2, 5)
	folhas.SpreadAngle = Vector2.new(180, 180)
	folhas.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	folhas.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	folhas.Parent = root
	Debris:AddItem(folhas, def.Duracao + 0.5)
	task.spawn(function()
		for _ = 1, def.Duracao do
			if player:GetAttribute("GeneToken") ~= token or not hum.Parent or hum.Health <= 0 then break end
			hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * def.Cura)
			task.wait(1)
		end
		if folhas.Parent then folhas.Enabled = false end
	end)
	return true
end

-- Olho do Shisui: genjutsu, inimigos por perto ficam imobilizados e perdem vida
EFEITOS.olho = function(player, def)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then return false, "You can't use it now." end
	local alvos = inimigosPerto(root.Position, def.Alcance)
	if #alvos == 0 then return false, "No enemies nearby." end
	anel(root.Position - Vector3.new(0, 2.6, 0), def.Alcance * 2, def.Cor, 0.9)
	for i = 1, math.min(#alvos, def.Alvos) do
		local e = alvos[i]
		local chefe = e.raio > 2
		local dur = chefe and def.Duracao * 0.4 or def.Duracao -- o boss se solta mais rapido e perde menos vida
		local h = e.hum
		-- imobilizar (mesmo protocolo do "prender" do AbilityServer)
		if h:GetAttribute("VelPreso") == nil then h:SetAttribute("VelPreso", h.WalkSpeed) end
		local token = (h:GetAttribute("PresoToken") or 0) + 1
		h:SetAttribute("PresoToken", token)
		h.WalkSpeed = 0
		if not chefe then e.model:SetAttribute("Atordoado", os.clock() + dur) end
		task.delay(dur, function()
			if h.Parent and h:GetAttribute("PresoToken") == token then
				h.WalkSpeed = h:GetAttribute("VelPreso") or 13
				h:SetAttribute("VelPreso", nil)
			end
		end)
		-- marca do olho em cima do inimigo
		local hl = brilho(e.model, "OlhoMarca", def.Cor, dur + 0.2)
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromOffset(60, 60)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 4 + e.raio, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = e.root
		bb.Parent = e.model
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.Text = def.Emoji
		t.TextScaled = true
		t.Parent = bb
		Debris:AddItem(bb, dur + 0.2)
		-- dreno de vida: a cada 0.5s, uma fatia da vida maxima (boss perde so um quarto disso)
		task.spawn(function()
			local passou = 0
			local pct = def.Dreno * (chefe and 0.25 or 1)
			while passou < dur and h.Parent and h.Health > 0 do
				task.wait(0.5)
				passou += 0.5
				if h.Parent and h.Health > 0 then
					local dano = math.max(1, h.MaxHealth * pct * 0.5)
					h:SetAttribute("UltimoAtacante", player.UserId) -- a kill conta para quem usou o olho
					e.model:SetAttribute("DanoJutsu", true)
					h:TakeDamage(dano)
					if e.root.Parent then
						numeroEvent:FireClient(player, e.root.Position + Vector3.new(0, 1.5 + e.raio, 0), math.floor(dano + 0.5), def.Cor, "queima")
					end
				end
			end
			if hl.Parent then hl:Destroy() end
			if bb.Parent then bb:Destroy() end
		end)
	end
	return true
end

-- Manto da Kurama: mais dano e mais velocidade (usa os atributos de buff que o combate ja le)
EFEITOS.manto = function(player, def)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum and hum.Health > 0) then return false, "You can't use it now." end
	local token = (player:GetAttribute("BuffToken") or 0) + 1
	player:SetAttribute("BuffToken", token)
	player:SetAttribute("BuffDano", def.Dano)
	player:SetAttribute("BuffVelocidade", def.Velocidade)
	brilho(char, "BuffBrilho", def.Cor, def.Duracao)
	anel(root.Position - Vector3.new(0, 2.6, 0), 18, def.Cor, 0.8)
	task.delay(def.Duracao, function()
		if player:GetAttribute("BuffToken") == token then
			player:SetAttribute("BuffDano", 0)
			player:SetAttribute("BuffVelocidade", 0)
		end
	end)
	return true
end

---------------------------------------------------------------
-- Pedidos do cliente
---------------------------------------------------------------
local cooldown = {} -- [player] = { [idDoPoder] = os.clock() em que libera }

local function claOk(player, def)
	return def.Cla == nil or player:GetAttribute("Cla") == def.Cla
end

acao.OnServerInvoke = function(player, pedido, id)
	local s = segredos(player)
	if not s then return { ok = false, erro = "Loading..." } end
	local def = type(id) == "string" and SegredosData.Poderes[id]
	if not def then return { ok = false, erro = "Invalid." } end

	if pedido == "pegar" then
		if not completo(s) then return { ok = false, erro = "Find the three seals first." } end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local altar = Vector3.new(SegredosData.Altar.X, altarY, SegredosData.Altar.Z)
		if not root or (root.Position - altar).Magnitude > SegredosData.DistAltar then
			return { ok = false, erro = "Come closer to the sanctuary." }
		end
		if not claOk(player, def) then
			return { ok = false, erro = ("Only the %s clan can awaken this."):format(def.ClaNome or def.Cla) }
		end
		if s.Pegos[id] then return { ok = false, erro = "Already awakened." } end
		s.Pegos[id] = true
		publicar(player)
		salvar(player)
		return { ok = true }

	elseif pedido == "usar" then
		if not s.Pegos[id] then return { ok = false, erro = "You haven't awakened this power." } end
		if not claOk(player, def) then
			return { ok = false, erro = ("Only the %s clan can use this."):format(def.ClaNome or def.Cla) }
		end
		local cds = cooldown[player]
		if not cds then
			cds = {}
			cooldown[player] = cds
		end
		local resta = (cds[id] or 0) - os.clock()
		if resta > 0 then return { ok = false, erro = "Recharging...", resta = resta } end
		local ok, erro = EFEITOS[id](player, def)
		if not ok then return { ok = false, erro = erro } end
		cds[id] = os.clock() + def.Cooldown
		return { ok = true, cd = def.Cooldown }
	end
	return { ok = false, erro = "Invalid." }
end

-- ao entrar, espera os dados carregarem e publica o progresso para o cliente
local function entrou(player)
	task.spawn(function()
		local t0 = os.clock()
		while player.Parent and not PlayerData.Get(player) and os.clock() - t0 < 120 do
			task.wait(0.5)
		end
		if player.Parent then publicar(player) end
	end)
end
Players.PlayerAdded:Connect(entrou)
for _, p in ipairs(Players:GetPlayers()) do entrou(p) end
Players.PlayerRemoving:Connect(function(player)
	cooldown[player] = nil
end)
