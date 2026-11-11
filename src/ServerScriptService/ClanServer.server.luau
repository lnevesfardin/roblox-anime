-- Script: ServerScriptService > ClanServer
-- Roleta de clã, estatura e traço inicial de cada clã. O servidor sorteia e guarda tudo; o cliente só pede.
-- ClanAction (RemoteFunction): "estado" | "girar" | "escolher", índice | "manter" | "altura", valor

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local ClanData = require(ReplicatedStorage:WaitForChild("ClanData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local action = Instance.new("RemoteFunction")
action.Name = "ClanAction"
action.Parent = ReplicatedStorage

local rng = Random.new()
local ocupado = {} -- evita dois pedidos ao mesmo tempo do mesmo jogador

local pastaCaes = Instance.new("Folder")
pastaCaes.Name = "Companheiros"
pastaCaes.Parent = workspace
local caes = {} -- [player] = Model

---------------------------------------------------------------
-- Sala da roleta: o personagem fica parado dentro do quarto, ao lado do painel,
-- para o jogador ver o tamanho e o traço do clã enquanto escolhe
---------------------------------------------------------------
local naSala = {} -- [player] = CFrame de onde ele estava

local function posicionarNaSala(player)
	local sala = workspace:FindFirstChild("SalaRoleta")
	local ponto = sala and sala:FindFirstChild("PontoJogador")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (ponto and root and hum) then return false end
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	-- pés no chão do quarto, qualquer que seja a estatura
	local pe = root.Position.Y - (hum.HipHeight + root.Size.Y / 2)
	if hum.RigType == Enum.HumanoidRigType.R6 then pe = root.Position.Y - 3 * char:GetScale() end
	char:PivotTo(ponto.CFrame + Vector3.new(0, root.Position.Y - pe, 0))
	return true
end

local function entrarSala(player)
	if player:GetAttribute("InRun") then return false end
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return false end
	if not naSala[player] then
		naSala[player] = char:GetPivot()
	end
	return posicionarNaSala(player)
end

local function sairSala(player)
	local volta = naSala[player]
	naSala[player] = nil
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then return end
	if volta then
		pcall(function() player:RequestStreamAroundAsync(volta.Position, 5) end)
		char:PivotTo(volta)
	end
	root.Anchored = false
	root.AssemblyLinearVelocity = Vector3.zero
end

---------------------------------------------------------------
-- Traços visíveis
---------------------------------------------------------------
local function olhos(char, cor)
	local head = char:FindFirstChild("Head")
	if not head then return end
	local s = head.Size.Y
	for _, lado in ipairs({ -1, 1 }) do
		local o = Instance.new("Part")
		o.Name = "OlhoCla"
		o.Shape = Enum.PartType.Ball
		o.Size = Vector3.one * s * 0.13
		o.Material = Enum.Material.Neon
		o.Color = cor
		o.CanCollide, o.CanQuery, o.CanTouch, o.Massless = false, false, false, true
		o.CFrame = head.CFrame * CFrame.new(lado * s * 0.19, s * 0.1, -head.Size.Z * 0.48)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, o
		w.Parent = o
		o.Parent = char
	end
end

local function cabeloBranco(char)
	for _, acc in ipairs(char:GetChildren()) do
		if acc:IsA("Accessory") and acc.AccessoryType == Enum.AccessoryType.Hair then
			local h = acc:FindFirstChild("Handle")
			if h then
				if h:IsA("MeshPart") then
					h.TextureID = ""
				else
					local mesh = h:FindFirstChildOfClass("SpecialMesh")
					if mesh then mesh.TextureId = "" end
				end
				h.Color = Color3.fromRGB(240, 240, 245)
			end
		end
	end
end

local function criarCao(player)
	local m = Instance.new("Model")
	m.Name = "Cao_" .. player.Name
	local function p(nome, size, off, cor)
		local x = Instance.new("Part")
		x.Name = nome
		x.Size = size
		x.Color = cor
		x.Material = Enum.Material.SmoothPlastic
		x.Anchored = true
		x.CanCollide, x.CanQuery, x.CanTouch = false, false, false
		x.CFrame = CFrame.new(off)
		x.Parent = m
		return x
	end
	local pelo, claro, escuro = Color3.fromRGB(236, 232, 222), Color3.fromRGB(250, 248, 240), Color3.fromRGB(60, 50, 45)
	local corpo = p("Corpo", Vector3.new(1, 0.9, 1.9), Vector3.new(0, 1.05, 0), pelo)
	p("Cabeca", Vector3.new(0.9, 0.85, 0.9), Vector3.new(0, 1.55, -1.15), claro)
	p("Focinho", Vector3.new(0.45, 0.4, 0.45), Vector3.new(0, 1.42, -1.7), claro)
	p("Nariz", Vector3.new(0.18, 0.16, 0.12), Vector3.new(0, 1.52, -1.94), escuro)
	p("OrelhaE", Vector3.new(0.22, 0.5, 0.3), Vector3.new(-0.36, 1.85, -1.05), escuro)
	p("OrelhaD", Vector3.new(0.22, 0.5, 0.3), Vector3.new(0.36, 1.85, -1.05), escuro)
	p("Rabo", Vector3.new(0.22, 0.22, 0.8), Vector3.new(0, 1.45, 1.2), claro)
	for _, o in ipairs({ { -0.32, -0.65 }, { 0.32, -0.65 }, { -0.32, 0.65 }, { 0.32, 0.65 } }) do
		p("Pata", Vector3.new(0.3, 0.7, 0.3), Vector3.new(o[1], 0.35, o[2]), pelo)
	end
	m.PrimaryPart = corpo
	m.WorldPivot = CFrame.new(0, 0, 0)
	m.Parent = pastaCaes
	return m
end

local function tirarCao(player)
	if caes[player] then
		caes[player]:Destroy()
		caes[player] = nil
	end
end

local function aplicar(player)
	local data = PlayerData.Get(player)
	local char = player.Character
	if not data then return end
	local cla = data.Cla.Id
	player:SetAttribute("Cla", cla or "")
	if not data.Equipped then
		-- os botões de poder do cliente leem este atributo: kit provisório do clã
		player:SetAttribute("Equipped", cla and ClanData.Kit[cla] or nil)
	end
	player:SetAttribute("BonusVelocidade", cla == "Shirokiba" and 2 or 0)
	player:SetAttribute("BonusChakra", cla == "Uzu" and 0.3 or 0)
	player:SetAttribute("DescontoEnergia", cla == "Lee" and 0.2 or 0)
	if cla == "Inu" then
		if not caes[player] then caes[player] = criarCao(player) end
	else
		tirarCao(player)
	end
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	for _, d in ipairs(char:GetChildren()) do
		if d.Name == "OlhoCla" then d:Destroy() end
	end
	-- estatura (0.9 a 1.1)
	pcall(function()
		char:ScaleTo(data.Altura)
	end)
	if cla == "Uchiwa" then
		olhos(char, Color3.fromRGB(255, 40, 40))
	elseif cla == "Byakugan" then
		olhos(char, Color3.fromRGB(225, 215, 255))
	elseif cla == "Shirokiba" then
		cabeloBranco(char)
	end
	if naSala[player] then
		posicionarNaSala(player) -- a estatura mudou: encosta os pés no chão de novo
	end
end

---------------------------------------------------------------
-- Roleta
---------------------------------------------------------------
local function estado(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	return {
		Id = data.Cla.Id,
		Giros = data.Cla.Giros,
		Opcoes = table.clone(data.Cla.Opcoes),
		Altura = data.Altura,
		Gems = data.Gems,
	}
end

local function girar(player)
	local data = PlayerData.Get(player)
	local c = data.Cla
	-- quem já tem clã precisa decidir a oferta pendente antes de girar de novo
	if c.Id and #c.Opcoes > 0 then
		return { ok = false, erro = "Decide the pending offer first." }
	end
	if #c.Opcoes >= 6 then
		return { ok = false, erro = "Choose one of your clans." }
	end
	if c.Giros > 0 then
		c.Giros -= 1
	elseif not PlayerData.SpendGems(player, ClanData.RESPIN_GEMS) then
		return { ok = false, erro = "Not enough gems." }
	end
	local minimo = 1
	if c.Pity100 + 1 >= ClanData.PITY_LEGENDARY then
		minimo = 4
	elseif c.Pity10 + 1 >= ClanData.PITY_RARE then
		minimo = 2
	end
	local id = ClanData.Roll(rng, minimo)
	-- evita repetir um clã que já está entre as opções (ou o clã atual)
	for _ = 1, 6 do
		if id ~= c.Id and not table.find(c.Opcoes, id) then break end
		id = ClanData.Roll(rng, minimo)
	end
	local ordem = ClanData.RarityOrder(id)
	c.Pity10 = ordem >= 2 and 0 or c.Pity10 + 1
	c.Pity100 = ordem >= 4 and 0 or c.Pity100 + 1
	table.insert(c.Opcoes, id)
	return { ok = true, clan = id }
end

local function escolher(player, idx)
	local data = PlayerData.Get(player)
	local c = data.Cla
	local id = type(idx) == "number" and c.Opcoes[idx]
	if not id then
		return { ok = false, erro = "Invalid option." }
	end
	if c.Id and c.Id ~= id then
		-- trocar de clã zera o caminho do clã antigo (o cliente avisa antes)
		c.Etapa = 0
		c.Progresso = {}
	end
	c.Id = id
	c.Opcoes = {}
	aplicar(player)
	return { ok = true }
end

action.OnServerInvoke = function(player, acao, valor)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, erro = "Loading..." }
	end
	if acao == "estado" then
		return { ok = true, estado = estado(player) }
	end
	if acao == "sala" then
		if valor == true then
			return { ok = entrarSala(player), estado = estado(player) }
		end
		sairSala(player)
		return { ok = true, estado = estado(player) }
	end
	if ocupado[player] then
		return { ok = false, erro = "Wait..." }
	end
	ocupado[player] = true
	local r
	if acao == "girar" then
		r = girar(player)
	elseif acao == "escolher" then
		r = escolher(player, valor)
	elseif acao == "manter" then
		if data.Cla.Id then
			data.Cla.Opcoes = {}
			r = { ok = true }
		else
			r = { ok = false, erro = "Choose a clan." }
		end
	elseif acao == "altura" then
		if type(valor) == "number" and valor == valor then
			-- arredonda para 2 casas e prende nos limites
			data.Altura = math.clamp(math.floor(valor * 100 + 0.5) / 100, ClanData.HEIGHT_MIN, ClanData.HEIGHT_MAX)
			aplicar(player)
			r = { ok = true }
		else
			r = { ok = false, erro = "Invalid height." }
		end
	else
		r = { ok = false, erro = "?" }
	end
	ocupado[player] = nil
	r.estado = estado(player)
	return r
end

---------------------------------------------------------------
-- Jogadores
---------------------------------------------------------------
local function setup(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("Humanoid", 10)
		-- espera roupas e cabelo chegarem para pintar o cabelo e medir a cabeça
		if not player:HasAppearanceLoaded() then
			player.CharacterAppearanceLoaded:Wait()
		end
		for _ = 1, 50 do
			if PlayerData.Get(player) then break end
			task.wait(0.2)
		end
		aplicar(player)
	end)
	task.spawn(function()
		for _ = 1, 50 do
			if PlayerData.Get(player) then break end
			task.wait(0.2)
		end
		aplicar(player)
	end)
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
Players.PlayerRemoving:Connect(function(player)
	tirarCao(player)
	ocupado[player] = nil
	naSala[player] = nil
end)

-- Mokuton: regenera 1% da vida por segundo
task.spawn(function()
	while true do
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			if p:GetAttribute("Cla") == "Mokuton" then
				local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 and hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.01)
				end
			end
		end
	end
end)

-- Inu: o cão segue o dono, ao lado e um pouco atrás
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
RunService.Heartbeat:Connect(function(dt)
	for player, cao in pairs(caes) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and cao.Parent then
			local alvo = (root.CFrame * CFrame.new(3, 0, 2.5)).Position
			params.FilterDescendantsInstances = { player.Character, pastaCaes }
			local hit = workspace:Raycast(alvo + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
			local y = hit and hit.Position.Y or (root.Position.Y - 3)
			local atual = cao:GetPivot()
			local destino = Vector3.new(alvo.X, y, alvo.Z)
			local dist = (destino - atual.Position).Magnitude
			if dist > 60 then
				cao:PivotTo(CFrame.new(destino))
			elseif dist > 0.6 then
				local novo = atual.Position:Lerp(destino, math.min(dt * 5, 1))
				local olhar = Vector3.new(destino.X, novo.Y, destino.Z)
				if (olhar - novo).Magnitude > 0.05 then
					cao:PivotTo(CFrame.lookAt(novo, olhar))
				end
			else
				local l = root.CFrame.LookVector
				cao:PivotTo(CFrame.lookAt(atual.Position, atual.Position + Vector3.new(l.X, 0, l.Z)))
			end
		end
	end
end)
