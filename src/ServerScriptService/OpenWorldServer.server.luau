-- Script: ServerScriptService > OpenWorldServer
-- Fase 6: mundo aberto (zona 1 = Fire Country Woods, fora do portão leste).
--  * Só entra quem tem o nível mínimo da zona (quem não tem volta para a vila com aviso).
--  * Inimigos de cada área voltam a aparecer; à noite ficam mais fortes e dão mais recompensa.
--  * Chefe da zona (Bandit King) volta alguns minutos depois de derrotado.
--  * Evento do chefe do mundo (Rogue Warlord) a cada 20-30 min, com aviso para o servidor inteiro;
--    a recompensa é dividida pelo dano de cada jogador (atributo "UltimoAtacante" que o
--    CombatServer e o AbilityServer marcam no Humanoid a cada golpe).
-- Aparência dos inimigos: ServerStorage.InimigosMundo.<Nome> (troque o Model mantendo o nome).
-- Estado do evento para os clientes: ReplicatedStorage.MundoEstado (atributos).
-- Avisos: ReplicatedStorage.AvisoMundo (RemoteEvent, servidor -> cliente).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local WorldData = require(ReplicatedStorage:WaitForChild("WorldData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local rng = Random.new()

local avisoMundo = Instance.new("RemoteEvent")
avisoMundo.Name = "AvisoMundo"
avisoMundo.Parent = ReplicatedStorage

local estado = Instance.new("Folder")
estado.Name = "MundoEstado"
estado:SetAttribute("EventoAtivo", false)
estado:SetAttribute("EventoNome", WorldData.ChefeMundo.Name)
estado:SetAttribute("EventoVida", 0)
estado:SetAttribute("EventoMax", 1)
estado:SetAttribute("EventoProximo", 0)
estado.Parent = ReplicatedStorage

local pasta = Instance.new("Folder")
pasta.Name = "InimigosMundo"
pasta.Parent = workspace

local missaoEv = ServerStorage:FindFirstChild("MissaoProgresso")

local function avisoPara(player, texto, bom)
	local ev = ReplicatedStorage:FindFirstChild("MissionEvent")
	if ev then
		ev:FireClient(player, { tipo = "aviso", texto = texto, bom = bom })
	end
end

local function ehNoite()
	return workspace:GetAttribute("Noite") == true
end

---------------------------------------------------------------
-- Modelos dos inimigos
---------------------------------------------------------------
local modelos = ServerStorage:FindFirstChild("InimigosMundo")
if not modelos then
	modelos = Instance.new("Folder")
	modelos.Name = "InimigosMundo"
	modelos.Parent = ServerStorage
end

local function rigPadrao(nome, cor)
	local ok, m = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = Color3.fromRGB(215, 170, 130)
		d.LeftArmColor, d.RightArmColor = d.HeadColor, d.HeadColor
		d.TorsoColor = cor
		d.LeftLegColor = cor:Lerp(Color3.new(0, 0, 0), 0.35)
		d.RightLegColor = d.LeftLegColor
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not m then
		warn("[OpenWorld] Não deu para criar o modelo de " .. nome .. ": " .. tostring(m))
		return nil
	end
	m.Name = nome
	-- faixa na testa (só para diferenciar até a skin final)
	local head = m:FindFirstChild("Head")
	if head then
		local f = Instance.new("Part")
		f.Name = "Faixa"
		f.Size = Vector3.new(head.Size.X * 1.06, head.Size.Y * 0.22, head.Size.Z * 1.06)
		f.CFrame = head.CFrame * CFrame.new(0, head.Size.Y * 0.18, 0)
		f.Color = cor:Lerp(Color3.new(0, 0, 0), 0.5)
		f.Material = Enum.Material.Fabric
		f.CanCollide, f.Massless = false, true
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, f
		w.Parent = f
		f.Parent = m
	end
	m.Parent = modelos
	return m
end

local function modeloDe(nome, cor)
	local m = modelos:FindFirstChild(nome)
	if m and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChild("HumanoidRootPart") then
		return m
	end
	return rigPadrao(nome, cor or Color3.fromRGB(90, 90, 90))
end

---------------------------------------------------------------
-- Criar inimigo + IA
---------------------------------------------------------------
local function jogadorPerto(pos, raio)
	local melhor, dist = nil, raio
	for _, player in ipairs(Players:GetPlayers()) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and not r.Anchored then
			local d = (r.Position - pos).Magnitude
			if d < dist then
				melhor, dist = h, d
			end
		end
	end
	return melhor, dist
end

local function marcaNoChao(pos, raio, tempo)
	local p = Instance.new("Part")
	p.Name = "AvisoGolpe"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.2, raio * 2, raio * 2)
	p.CFrame = CFrame.new(pos.X, 0.25, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Color = Color3.fromRGB(220, 40, 40)
	p.Material = Enum.Material.Neon
	p.Transparency = 0.55
	p.Parent = workspace
	task.delay(tempo, function() p:Destroy() end)
end

local function pancada(pos, raio, dano)
	for _, player in ipairs(Players:GetPlayers()) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 and (r.Position - pos).Magnitude <= raio then
			h:TakeDamage(dano)
			r.AssemblyLinearVelocity = ((r.Position - pos) * Vector3.new(1, 0, 1)).Unit * 45 + Vector3.new(0, 40, 0)
		end
	end
end

-- opts: { nome, info, nivel, pos, casa, escala, chefe = true|nil, aoMorrer = function(m, hum, root) }
local function criarInimigo(opts)
	local base = modeloDe(opts.nome, opts.info.Cor)
	if not base then return nil end
	local m = base:Clone()
	m.Name = opts.nome
	local hum = m:FindFirstChildOfClass("Humanoid")
	local root = m:FindFirstChild("HumanoidRootPart")
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = false end
	end
	if opts.escala and opts.escala ~= 1 then
		pcall(function() m:ScaleTo(opts.escala) end)
	end
	local noite = ehNoite()
	local vida = opts.vida * (noite and WorldData.Noite.Vida or 1)
	hum.MaxHealth = vida
	hum.Health = vida
	hum.WalkSpeed = opts.info.Velocidade or 14
	hum.DisplayName = string.format("%s [Lv %d]", opts.nome, opts.nivel)
	hum.HealthDisplayDistance = 60
	hum.NameDisplayDistance = 80
	m:SetAttribute("Raio", opts.chefe and 3 or 0)
	m:SetAttribute("Nivel", opts.nivel)
	m:SetAttribute("MundoAberto", true)
	local dano = opts.dano * (noite and WorldData.Noite.Dano or 1)
	local casa = opts.casa or opts.pos
	m:PivotTo(CFrame.new(opts.pos.X, 3.5 * (opts.escala or 1), opts.pos.Z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
	m.Parent = pasta
	CollectionService:AddTag(m, "Inimigo")

	local morto = false
	hum.Died:Connect(function()
		if morto then return end
		morto = true
		CollectionService:RemoveTag(m, "Inimigo")
		if opts.aoMorrer then
			task.spawn(opts.aoMorrer, m, hum, root, noite)
		end
		task.delay(3, function() m:Destroy() end)
	end)

	-- IA: persegue quem chega perto, bate, e volta para casa se for longe demais
	task.spawn(function()
		local ultimoGolpe, ultimoEspecial = 0, os.clock()
		local alcance = opts.info.Alcance or 40
		local coleira = alcance + 35
		while m.Parent and hum.Health > 0 do
			local alvo, dist = jogadorPerto(root.Position, alcance)
			local longe = (root.Position - casa).Magnitude > coleira
			if alvo and not longe then
				local r = alvo.Parent:FindFirstChild("HumanoidRootPart")
				if r then
					hum:MoveTo(r.Position)
					local alcanceGolpe = 5 * (opts.escala or 1)
					if dist < alcanceGolpe and os.clock() - ultimoGolpe > 1.3 then
						ultimoGolpe = os.clock()
						alvo:TakeDamage(dano)
					end
					-- chefes: pancada no chão com aviso vermelho
					if opts.chefe and os.clock() - ultimoEspecial > 7 and dist < 20 then
						ultimoEspecial = os.clock()
						local centro = root.Position
						marcaNoChao(centro, 14, 1.2)
						task.delay(1.2, function()
							if hum.Health > 0 and m.Parent then
								pancada(root.Position, 14, dano * 1.8)
							end
						end)
					end
				end
			else
				if (root.Position - casa).Magnitude > 8 then
					hum:MoveTo(casa)
				elseif hum.Health < hum.MaxHealth then
					hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.05) -- recupera em casa
				end
			end
			task.wait(0.3)
		end
	end)
	return m, hum, root
end

-- dá recompensa a quem estava perto quando o inimigo caiu
local function recompensarPerto(pos, raio, xp, moedas, noite)
	local mult = noite and WorldData.Noite.Recompensa or 1
	local ganhou = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude <= raio then
			PlayerData.AddXP(player, math.floor(xp * mult))
			PlayerData.AddCoins(player, math.floor(moedas * mult))
			if missaoEv then
				missaoEv:Fire(player, "derrotar", 1, "Mundo")
			end
			table.insert(ganhou, player)
		end
	end
	return ganhou, mult
end

local function escalaNivel(nivel, min)
	return 1 + (nivel - min) * 0.06
end

---------------------------------------------------------------
-- Inimigos das áreas (voltam a aparecer)
---------------------------------------------------------------
local function pontoNaArea(a)
	local ang = rng:NextNumber(0, math.pi * 2)
	local d = math.sqrt(rng:NextNumber()) * a.Raio
	return a.Centro + Vector3.new(math.cos(ang) * d, 0, math.sin(ang) * d)
end

local function novoInimigoArea(a)
	local info = WorldData.Inimigos[a.Inimigo]
	if not info then return end
	local nivel = rng:NextInteger(info.Nivel[1], info.Nivel[2])
	local k = escalaNivel(nivel, info.Nivel[1])
	local pos = pontoNaArea(a)
	local m = criarInimigo({
		nome = a.Inimigo, info = info, nivel = nivel, pos = pos, casa = pos,
		vida = info.Vida * k, dano = info.Dano * k,
		aoMorrer = function(_, _, root, noite)
			recompensarPerto(root.Position, 80, info.XP * k, info.Moedas * k, noite)
		end,
	})
	if m then
		m:SetAttribute("Area", a.Id)
	end
end

task.spawn(function()
	while true do
		for _, z in ipairs(WorldData.Zonas) do
			for _, a in ipairs(z.Areas) do
				local vivos = 0
				for _, c in ipairs(pasta:GetChildren()) do
					if c:GetAttribute("Area") == a.Id then
						local h = c:FindFirstChildOfClass("Humanoid")
						if h and h.Health > 0 then vivos += 1 end
					end
				end
				if vivos < a.Quantos then
					novoInimigoArea(a)
				end
			end
		end
		task.wait(5)
	end
end)

---------------------------------------------------------------
-- Chefe da zona
---------------------------------------------------------------
local function chamarChefeZona()
	local c = WorldData.ChefeZona
	criarInimigo({
		nome = c.Name, info = c, nivel = c.Nivel, pos = c.Pos, casa = c.Pos, escala = c.Escala, chefe = true,
		vida = c.Vida, dano = c.Dano,
		aoMorrer = function(_, _, root, noite)
			local ganhou, mult = recompensarPerto(root.Position, 90, c.XP, c.Moedas, noite)
			for _, p in ipairs(ganhou) do
				avisoPara(p, string.format("%s defeated! +%d XP  +%d coins", c.Name, math.floor(c.XP * mult), math.floor(c.Moedas * mult)), true)
			end
			task.delay(c.Respawn, chamarChefeZona)
		end,
	})
end
task.delay(3, chamarChefeZona)

---------------------------------------------------------------
-- Evento: chefe do mundo
---------------------------------------------------------------
local function avisarTodos(texto, cor, grande)
	avisoMundo:FireAllClients({ texto = texto, cor = cor, grande = grande })
end

local function rodarEvento(aviso)
	local c = WorldData.ChefeMundo
	aviso = aviso or c.Aviso
	avisarTodos(string.format("%s will appear in Fire Country Woods in %d seconds!", c.Name, aviso), Color3.fromRGB(255, 170, 60), true)
	task.wait(aviso)

	local n = #Players:GetPlayers()
	local vida = c.VidaBase + c.VidaPorJogador * math.max(n, 1)
	local danoPor = {} -- [UserId] = dano
	local total = 0
	local lacaios = false
	local terminou = false

	local m, hum, root = criarInimigo({
		nome = c.Name, info = c, nivel = c.Nivel, pos = c.Pos, casa = c.Pos, escala = c.Escala, chefe = true,
		vida = vida, dano = c.Dano,
		aoMorrer = function(_, _, _, noite)
			terminou = true
			estado:SetAttribute("EventoAtivo", false)
			local mult = noite and WorldData.Noite.Recompensa or 1
			local topId, topDano = nil, 0
			for uid, d in pairs(danoPor) do
				if d > topDano then topId, topDano = uid, d end
			end
			avisarTodos(c.Name .. " was defeated!", Color3.fromRGB(110, 220, 120), true)
			for uid, d in pairs(danoPor) do
				local player = Players:GetPlayerByUserId(uid)
				local parte = total > 0 and d / total or 0
				if player and parte >= c.ParteMinima then
					local xp = math.floor((c.XP + c.XPExtra * parte) * mult)
					local moedas = math.floor((c.Moedas + c.MoedasExtra * parte) * mult)
					PlayerData.AddXP(player, xp)
					PlayerData.AddCoins(player, moedas)
					local extra = ""
					if uid == topId and c.GemasTop > 0 then
						PlayerData.AddGems(player, c.GemasTop)
						extra = string.format("  +%d gems (top damage!)", c.GemasTop)
					end
					avisoPara(player, string.format("You dealt %d%% of the damage: +%d XP  +%d coins%s", math.floor(parte * 100 + 0.5), xp, moedas, extra), true)
				end
			end
		end,
	})
	if not m then return end

	estado:SetAttribute("EventoMax", hum.MaxHealth)
	estado:SetAttribute("EventoVida", hum.Health)
	estado:SetAttribute("EventoAtivo", true)
	avisarTodos(c.Name .. " has appeared in Fire Country Woods!", Color3.fromRGB(230, 70, 70), true)

	local ultimaVida = hum.Health
	hum.HealthChanged:Connect(function(v)
		local perdeu = ultimaVida - v
		ultimaVida = v
		estado:SetAttribute("EventoVida", math.max(v, 0))
		if perdeu > 0 then
			local uid = hum:GetAttribute("UltimoAtacante")
			if uid then
				danoPor[uid] = (danoPor[uid] or 0) + perdeu
				total += perdeu
			end
		end
		-- com metade da vida chama ajudantes
		if not lacaios and v > 0 and v <= hum.MaxHealth * 0.5 then
			lacaios = true
			local info = WorldData.Inimigos[c.Lacaio]
			if info then
				for i = 1, 3 do
					local ang = (i / 3) * math.pi * 2
					local p = root.Position + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 10
					local nivel = info.Nivel[2]
					local k = escalaNivel(nivel, info.Nivel[1])
					criarInimigo({
						nome = c.Lacaio, info = info, nivel = nivel, pos = p, casa = c.Pos,
						vida = info.Vida * k, dano = info.Dano * k,
						aoMorrer = function(_, _, r, noite)
							recompensarPerto(r.Position, 80, info.XP * k, info.Moedas * k, noite)
						end,
					})
				end
				avisarTodos(c.Name .. " called for backup!", Color3.fromRGB(255, 170, 60), false)
			end
		end
	end)

	local inicio = os.clock()
	while not terminou and os.clock() - inicio < c.Duracao do
		task.wait(1)
	end
	if not terminou and m.Parent then
		terminou = true
		estado:SetAttribute("EventoAtivo", false)
		CollectionService:RemoveTag(m, "Inimigo")
		m:Destroy()
		avisarTodos(c.Name .. " escaped... he will be back.", Color3.fromRGB(200, 200, 200), true)
	end
end

task.spawn(function()
	while true do
		local c = WorldData.ChefeMundo
		local espera = rng:NextInteger(c.IntervaloMin, c.IntervaloMax)
		estado:SetAttribute("EventoProximo", os.time() + espera + c.Aviso)
		task.wait(espera)
		if #Players:GetPlayers() > 0 then
			local ok, err = pcall(rodarEvento)
			if not ok then
				warn("[OpenWorld] Erro no evento: " .. tostring(err))
				estado:SetAttribute("EventoAtivo", false)
			end
		end
	end
end)

-- Para testar no Studio: ServerStorage.TesteChefeMundo:Fire(segundosDeAviso)
if game:GetService("RunService"):IsStudio() then
	local teste = Instance.new("BindableEvent")
	teste.Name = "TesteChefeMundo"
	teste.Event:Connect(function(aviso)
		task.spawn(rodarEvento, aviso)
	end)
	teste.Parent = ServerStorage
end

---------------------------------------------------------------
-- Entrada da zona: só com o nível mínimo
---------------------------------------------------------------
local ultimoAviso = {}
task.spawn(function()
	while true do
		for _, player in ipairs(Players:GetPlayers()) do
			local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			if r then
				local z = WorldData.ZonaEm(r.Position)
				if z then
					local data = PlayerData.Get(player)
					local nivel = data and data.Level or 0
					if nivel < z.NivelMin then
						player.Character:PivotTo(CFrame.new(z.Volta) * CFrame.Angles(0, math.rad(90), 0))
						if os.clock() - (ultimoAviso[player] or 0) > 3 then
							ultimoAviso[player] = os.clock()
							avisoPara(player, string.format("%s requires level %d.", z.Name, z.NivelMin), false)
						end
					end
				end
			end
		end
		task.wait(0.5)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	ultimoAviso[player] = nil
end)
