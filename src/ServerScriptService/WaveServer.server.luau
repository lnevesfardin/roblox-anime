-- Script: ServerScriptService > WaveServer
-- Controla a partida: contagem, 5 ondas, boss, recompensa e volta ao lobby.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local MapData = require(ReplicatedStorage:WaitForChild("MapData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local statusEvent = Instance.new("RemoteEvent")
statusEvent.Name = "RunStatus"
statusEvent.Parent = ReplicatedStorage

-- ligação com as missões: MissionServer começa a partida do Exame e fica sabendo da vitória
local partidaVencida = Instance.new("BindableEvent")
partidaVencida.Name = "PartidaVencida"
partidaVencida.Parent = ServerStorage

-- animações padrão do Roblox (parado e correndo)
local ANIM_IDLE = "rbxassetid://507766666"
local ANIM_RUN = "rbxassetid://507767714"

local state = "idle" -- idle | countdown | running | ending
local participants = {}
local enemies = {}
local avisoTexto, avisoAte = "", 0

---------------------------------------------------------------
-- Auxiliares
---------------------------------------------------------------

local function broadcast(payload)
	for plr in pairs(participants) do
		if plr.Parent then
			statusEvent:FireClient(plr, payload)
		end
	end
end

local function participantCount()
	local n = 0
	for _ in pairs(participants) do
		n += 1
	end
	return n
end

local function aliveParticipants()
	local n = 0
	for plr in pairs(participants) do
		local h = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			n += 1
		end
	end
	return n
end

local function enemyAlive(e)
	return e.model.Parent ~= nil and e.hum.Health > 0
end

local function aliveEnemyCount()
	local n = 0
	for _, e in ipairs(enemies) do
		if enemyAlive(e) then
			n += 1
		end
	end
	return n
end

local function nearestTarget(pos)
	local best, bestDist
	for plr in pairs(participants) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			local d = ((root.Position - pos) * Vector3.new(1, 0, 1)).Magnitude
			if not bestDist or d < bestDist then
				best, bestDist = { hum = hum, root = root }, d
			end
		end
	end
	return best, bestDist
end

local function cleanup()
	for _, e in ipairs(enemies) do
		if e.model then
			e.model:Destroy()
		end
	end
	enemies = {}
	participants = {}
	for _, p in ipairs(Players:GetPlayers()) do
		p:SetAttribute("InRun", nil)
	end
	state = "idle"
end

---------------------------------------------------------------
-- Inimigos
---------------------------------------------------------------

---------------------------------------------------------------
-- Cobras (visual feito com esferas)
---------------------------------------------------------------

local function weld(a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function newBall(parent, size, cf, color, material)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(size, size, size)
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Parent = parent
	return p
end

-- baseCF = ponto no chão onde a cobra fica; a cabeça aponta para -Z
local function buildSnake(parent, anchor, baseCF, scale, color, isEnemy)
	for i = 1, 6 do
		local d = (1.3 - i * 0.12) * scale
		local cf = baseCF * CFrame.new(math.sin(i * 1.3) * 0.3 * scale, d / 2, i * 0.8 * scale)
		weld(anchor, newBall(parent, d, cf, color))
	end
	weld(anchor, newBall(parent, 1.1 * scale, baseCF * CFrame.new(0, 0.55 * scale, 0), color))

	local hd = 1.5 * scale
	local headCF = baseCF * CFrame.new(0, hd / 2 + 0.5 * scale, -0.5 * scale)
	local head = newBall(parent, hd, headCF, color)
	if isEnemy then
		head.Name = "Head"
	end
	weld(anchor, head)

	for _, sx in ipairs({ -1, 1 }) do
		weld(anchor, newBall(parent, 0.3 * scale, headCF * CFrame.new(sx * 0.35 * scale, 0.25 * scale, -hd / 2 + 0.1 * scale),
			Color3.fromRGB(255, 230, 40), Enum.Material.Neon))
	end

	local tongue = Instance.new("Part")
	tongue.Size = Vector3.new(0.12 * scale, 0.1 * scale, 0.8 * scale)
	tongue.CFrame = headCF * CFrame.new(0, -0.15 * scale, -hd / 2 - 0.3 * scale)
	tongue.Color = Color3.fromRGB(220, 30, 40)
	tongue.CanCollide = false
	tongue.CanQuery = false
	tongue.CanTouch = false
	tongue.Massless = true
	tongue.Parent = parent
	weld(anchor, tongue)
end

-- White Snake: olhos brilhantes e duas cobras nos ombros
local function decorateBoss(model, scale)
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = model
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	if head then
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
		for _, sx in ipairs({ -1, 1 }) do
			local eye = newBall(decor, 0.28 * scale, head.CFrame * CFrame.new(sx * 0.28 * scale, 0.05 * scale, -0.6 * scale),
				Color3.fromRGB(255, 230, 40), Enum.Material.Neon)
			weld(head, eye)
		end
	end
	if torso then
		for _, sx in ipairs({ -1, 1 }) do
			local base = torso.CFrame * CFrame.new(sx * 1.1 * scale, 0.9 * scale, 0.3 * scale)
			buildSnake(decor, torso, base, scale * 0.55, Color3.fromRGB(35, 80, 45), false)
		end
	end
end

local template
local function getTemplate()
	if template then
		return template
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if ok and model then
		template = model
	else
		warn("[WaveServer] Não consegui criar o modelo dos inimigos: " .. tostring(model))
	end
	return template
end

-- Visuais procedurais (sem assets de terceiros): cada Look pinta o corpo e cola pecas no modelo
local LOOKS = {
	Cientista = { Pele = Color3.fromRGB(235, 215, 195), Torso = Color3.fromRGB(245, 245, 245), Bracos = Color3.fromRGB(245, 245, 245), Pernas = Color3.fromRGB(70, 80, 95), Cabelo = Color3.fromRGB(60, 90, 60), Oculos = true, Tubo = true, Jaleco = true },
	Som = { Pele = Color3.fromRGB(225, 195, 170), Torso = Color3.fromRGB(45, 45, 55), Bracos = Color3.fromRGB(120, 35, 45), Pernas = Color3.fromRGB(35, 35, 45), Capuz = Color3.fromRGB(40, 35, 60), Corda = Color3.fromRGB(130, 90, 160) },
	Clone = { Pele = Color3.fromRGB(230, 205, 185), Torso = Color3.fromRGB(95, 105, 130), Bracos = Color3.fromRGB(75, 85, 110), Pernas = Color3.fromRGB(50, 55, 75), Capuz = Color3.fromRGB(60, 65, 90), Cabelo = Color3.fromRGB(205, 205, 215) },
	Taka = { Pele = Color3.fromRGB(235, 210, 190), Torso = Color3.fromRGB(25, 25, 30), Bracos = Color3.fromRGB(25, 25, 30), Pernas = Color3.fromRGB(20, 20, 25), Capa = Color3.fromRGB(20, 20, 26), Faixa = Color3.fromRGB(200, 30, 30), Careca = true },
}

local function peca(model, base, tamanho, offset, cor, material, forma)
	if not base then
		return nil
	end
	local p = Instance.new("Part")
	p.Size = tamanho
	p.Color = cor
	p.Material = material or Enum.Material.SmoothPlastic
	if forma then
		p.Shape = forma
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = base.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = p
	w.Parent = p
	p.Parent = model
	return p
end

local function aplicarLook(model, look)
	local cfg = LOOKS[look]
	if not cfg then
		return
	end
	local function paint(nome, cor)
		local part = model:FindFirstChild(nome)
		if part then
			part.Color = cor
		end
	end
	for _, n in ipairs({ "Head" }) do paint(n, cfg.Pele) end
	for _, n in ipairs({ "UpperTorso", "LowerTorso" }) do paint(n, cfg.Torso) end
	for _, n in ipairs({ "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand" }) do
		paint(n, cfg.Bracos)
	end
	for _, n in ipairs({ "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot" }) do paint(n, cfg.Pernas) end
	if look == "Som" then
		for _, n in ipairs({ "LeftHand", "RightHand" }) do paint(n, cfg.Pele) end
	end
	local bc = model:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = cfg.Pele
		bc.TorsoColor3 = cfg.Torso
		bc.LeftArmColor3 = cfg.Bracos
		bc.RightArmColor3 = cfg.Bracos
		bc.LeftLegColor3 = cfg.Pernas
		bc.RightLegColor3 = cfg.Pernas
	end
	local head = model:FindFirstChild("Head")
	local torso = model:FindFirstChild("UpperTorso")
	local low = model:FindFirstChild("LowerTorso")
	local mao = model:FindFirstChild("RightHand")
	if cfg.Cabelo and head then
		peca(model, head, Vector3.new(1.3, 0.35, 1.3), CFrame.new(0, 0.5, 0.05), cfg.Cabelo, Enum.Material.SmoothPlastic)
		peca(model, head, Vector3.new(1.3, 0.8, 0.3), CFrame.new(0, 0.25, 0.5), cfg.Cabelo, Enum.Material.SmoothPlastic)
	end
	if cfg.Capuz and head then
		peca(model, head, Vector3.new(1.45, 0.5, 1.5), CFrame.new(0, 0.5, 0.05), cfg.Capuz, Enum.Material.Fabric)
		peca(model, head, Vector3.new(1.45, 1.3, 0.35), CFrame.new(0, 0, 0.65), cfg.Capuz, Enum.Material.Fabric)
		peca(model, head, Vector3.new(0.3, 1.2, 1.3), CFrame.new(-0.7, 0, 0.1), cfg.Capuz, Enum.Material.Fabric)
		peca(model, head, Vector3.new(0.3, 1.2, 1.3), CFrame.new(0.7, 0, 0.1), cfg.Capuz, Enum.Material.Fabric)
		if cfg.Cabelo then
			peca(model, head, Vector3.new(1.1, 0.25, 0.2), CFrame.new(0, 0.4, -0.65), cfg.Cabelo, Enum.Material.SmoothPlastic)
		end
	end
	if cfg.Oculos and head then
		peca(model, head, Vector3.new(1.15, 0.3, 0.12), CFrame.new(0, 0.1, -0.62), Color3.fromRGB(150, 220, 255), Enum.Material.Glass)
	end
	if cfg.Jaleco and torso and low then
		peca(model, torso, Vector3.new(2.1, 1.2, 1.15), CFrame.new(0, -0.1, 0), cfg.Torso, Enum.Material.Fabric)
		peca(model, low, Vector3.new(2.1, 1.0, 1.15), CFrame.new(0, -0.3, 0), cfg.Torso, Enum.Material.Fabric)
		peca(model, torso, Vector3.new(0.35, 1.6, 0.1), CFrame.new(0, 0.1, -0.6), Color3.fromRGB(40, 50, 70), Enum.Material.Fabric)
	end
	if cfg.Tubo and mao then
		peca(model, mao, Vector3.new(0.3, 1.2, 0.3), CFrame.new(0, -0.3, -0.2), Color3.fromRGB(80, 255, 110), Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	if cfg.Corda and low then
		peca(model, low, Vector3.new(2.1, 0.35, 1.15), CFrame.new(0, 0.1, 0), cfg.Corda, Enum.Material.Fabric)
	end
	if cfg.Capa and torso and low then
		peca(model, torso, Vector3.new(2.3, 1.7, 1.2), CFrame.new(0, -0.05, 0.1), cfg.Capa, Enum.Material.Fabric)
		peca(model, low, Vector3.new(2.3, 1.4, 1.2), CFrame.new(0, -0.5, 0.1), cfg.Capa, Enum.Material.Fabric)
		peca(model, torso, Vector3.new(2.5, 0.5, 1.3), CFrame.new(0, 0.8, 0.1), cfg.Capa, Enum.Material.Fabric)
		peca(model, torso, Vector3.new(0.3, 2.6, 0.1), CFrame.new(0, -0.5, -0.65), cfg.Faixa, Enum.Material.SmoothPlastic)
		peca(model, low, Vector3.new(2.3, 0.2, 1.25), CFrame.new(0, -0.9, 0.1), cfg.Faixa, Enum.Material.SmoothPlastic)
	end
end

local function spawnEnemy(name, color, scale, health, damage, position, isBoss, speed, noDecor, look)
	local tpl = getTemplate()
	if not tpl then
		return nil
	end
	local model = tpl:Clone()
	model.Name = name

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Color = color
		elseif d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then
			d:Destroy()
		end
	end
	local bc = model:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = color
		bc.TorsoColor3 = color
		bc.LeftArmColor3 = color
		bc.RightArmColor3 = color
		bc.LeftLegColor3 = color
		bc.RightLegColor3 = color
	end

	if look then
		aplicarLook(model, look)
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	hum.DisplayName = name
	hum.MaxHealth = health
	hum.Health = health
	hum.WalkSpeed = speed or (isBoss and 11 or 13)
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	hum.NameDisplayDistance = 80
	hum.HealthDisplayDistance = 80
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn

	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	model:PivotTo(CFrame.new(position))
	hum.WalkSpeed = speed or (isBoss and 11 or 13)
	model:SetAttribute("Raio", (scale - 1) * 3)
	CollectionService:AddTag(model, "Inimigo")
	model.Parent = workspace
	if isBoss and not noDecor then
		decorateBoss(model, scale)
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local idle = Instance.new("Animation")
		idle.AnimationId = ANIM_IDLE
		local run = Instance.new("Animation")
		run.AnimationId = ANIM_RUN
		local idleTrack = animator:LoadAnimation(idle)
		local runTrack = animator:LoadAnimation(run)
		idleTrack.Looped = true
		runTrack.Looped = true
		idleTrack:Play()
		hum.Running:Connect(function(speed)
			if speed > 1 then
				if not runTrack.IsPlaying then
					idleTrack:Stop(0.1)
					runTrack:Play(0.1)
				end
			elseif runTrack.IsPlaying then
				runTrack:Stop(0.1)
				idleTrack:Play(0.1)
			end
		end)
	end)

	local entry = {
		model = model,
		hum = hum,
		root = root,
		damage = damage,
		lastHit = 0,
		isBoss = isBoss,
		radius = (scale - 1) * 3,
		nextSlam = 0,
		nextBite = 0,
		nextSummon = 0,
		interval = 1.5,
	}
	table.insert(enemies, entry)
	hum.Died:Connect(function()
		Debris:AddItem(model, 2)
	end)
	return entry
end

local function randomSpawnPos(centro, spawnPart, floorY, maxR)
	for _ = 1, 10 do
		local ang = math.random() * math.pi * 2
		local r = 16 + math.random() * (maxR - 16)
		local p = Vector3.new(centro.Position.X + math.cos(ang) * r, floorY + 4, centro.Position.Z + math.sin(ang) * r)
		local dx, dz = p.X - spawnPart.Position.X, p.Z - spawnPart.Position.Z
		if math.sqrt(dx * dx + dz * dz) > 30 then
			return p
		end
	end
	return Vector3.new(centro.Position.X, floorY + 4, centro.Position.Z - 30)
end

-- Cobra inimiga (invocada pelo White Snake): rápida, frágil e morde
local function spawnSnake(cfg, position)
	local model = Instance.new("Model")
	model.Name = cfg.SnakeName

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 1, 2)
	root.Transparency = 1
	root.CFrame = CFrame.new(position)
	root.Parent = model

	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R15
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.HipHeight = 0
	hum.MaxHealth = cfg.SnakeHealth
	hum.Health = cfg.SnakeHealth
	hum.WalkSpeed = 20
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.Parent = model
	model.PrimaryPart = root

	buildSnake(model, root, root.CFrame * CFrame.new(0, -0.5, 0), 1, cfg.SnakeColor, true)

	model:SetAttribute("Raio", -1)
	CollectionService:AddTag(model, "Inimigo")
	model.Parent = workspace
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	local entry = {
		model = model, hum = hum, root = root, damage = cfg.SnakeDamage, lastHit = 0,
		isBoss = false, isSnake = true, radius = -1, interval = 1.0,
		nextSlam = 0, nextBite = 0, nextSummon = 0,
	}
	table.insert(enemies, entry)
	hum.Died:Connect(function()
		Debris:AddItem(model, 1.5)
	end)
	return entry
end

local function mark(position, radius, y, color)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.4, radius * 2, radius * 2)
	p.CFrame = CFrame.new(position.X, y, position.Z) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.6
	p.Parent = workspace
	return p
end

local function damageInRadius(center, radius, damage)
	for plr in pairs(participants) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			local dx, dz = root.Position.X - center.X, root.Position.Z - center.Z
			if math.sqrt(dx * dx + dz * dz) <= radius then
				hum:TakeDamage(damage)
			end
		end
	end
end

-- Poça de veneno: machuca aos poucos quem ficar em cima
local function venomPool(center, radius, duration, floorY)
	local pool = mark(center, radius, floorY + 0.3, Color3.fromRGB(90, 210, 60))
	pool.Transparency = 0.5
	task.spawn(function()
		local t = 0
		while t < duration and state == "running" do
			task.wait(0.5)
			t += 0.5
			damageInRadius(center, radius, 3)
		end
		pool:Destroy()
	end)
end

-- Poder 1: Golpe Venenoso. Marca o chão em volta do boss; 1.5s depois dá dano e deixa veneno.
local function bossSlam(e, cfg, floorY)
	print("[WaveServer] Boss: golpe venenoso")
	local center = e.root.Position
	local radius = 16 + e.radius
	local m = mark(center, radius, floorY + 0.25, cfg.SlamColor or Color3.fromRGB(80, 220, 70))
	task.delay(1.5, function()
		if enemyAlive(e) and state == "running" then
			damageInRadius(center, radius, cfg.BossDamage * 1.6)
			m.Transparency = 0.2
			if cfg.SlamPool ~= false then
				venomPool(center, radius * 0.7, 5, floorY)
			end
		end
		Debris:AddItem(m, 0.2)
	end)
end

-- Poder 2: Mordidas de cobra. Marca o lugar onde cada jogador está; quem não sair leva dano.
local function bossBites(e, cfg, floorY)
	print("[WaveServer] Boss: mordidas de cobra")
	for plr in pairs(participants) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			local pos = root.Position
			local m = mark(pos, 7, floorY + 0.25, cfg.BiteColor or Color3.fromRGB(150, 255, 90))
			task.delay(1.4, function()
				if state == "running" then
					damageInRadius(pos, 7, cfg.BossDamage * 1.2)
					m.Transparency = 0.2
				end
				Debris:AddItem(m, 0.2)
			end)
		end
	end
end

-- Poder 3: invoca 3 cobras (no máximo 6 vivas ao mesmo tempo)
local function bossSummon(e, cfg, floorY, centro)
	local alive = 0
	for _, x in ipairs(enemies) do
		if (x.isSnake or x.isMinion) and enemyAlive(x) then
			alive += 1
		end
	end
	if alive >= 6 then
		return
	end
	print("[WaveServer] Boss: invocou cobras")
	for i = 1, 3 do
		local ang = (i / 3) * math.pi * 2 + math.random()
		local p = e.root.Position + Vector3.new(math.cos(ang) * 9, 0, math.sin(ang) * 9)
		local x = math.clamp(p.X, centro.Position.X - 46, centro.Position.X + 46)
		local z = math.clamp(p.Z, centro.Position.Z - 46, centro.Position.Z + 46)
		if cfg.Minion then
			local mn = cfg.Minion
			local ent = spawnEnemy(mn.Name, mn.Color, mn.Scale or 1, mn.Health, mn.Damage, Vector3.new(x, floorY + 3, z), false, mn.Speed)
			if ent then
				ent.isMinion = true
			end
		else
			spawnSnake(cfg, Vector3.new(x, floorY + 1, z))
		end
	end
end

local function setAviso(texto)
	avisoTexto = texto
	avisoAte = os.clock() + 2.5
end

local function aiLoop(cfg, floorY, centro)
	while state == "running" do
		local now = os.clock()
		for _, e in ipairs(enemies) do
			if enemyAlive(e) then
				local target, dist = nearestTarget(e.root.Position)
				if target then
					if dist <= 5 + e.radius then
						e.hum:MoveTo(e.root.Position)
						if now - e.lastHit >= e.interval then
							e.lastHit = now
							target.hum:TakeDamage(e.damage)
						end
					else
						e.hum:MoveTo(target.root.Position)
					end
					if e.isBoss then
						if now >= e.nextSlam then
							e.nextSlam = now + cfg.BossSlamEvery
							setAviso(cfg.BossName .. ": " .. (cfg.SlamLabel or "Venom Slam!"))
							bossSlam(e, cfg, floorY)
						end
						if now >= e.nextBite then
							e.nextBite = now + cfg.BossBiteEvery
							setAviso(cfg.BiteLabel or "Watch out: snake bites!")
							bossBites(e, cfg, floorY)
						end
						if now >= e.nextSummon then
							e.nextSummon = now + cfg.BossSummonEvery
							setAviso(cfg.BossName .. (cfg.SummonLabel or " summons snakes!"))
							bossSummon(e, cfg, floorY, centro)
						end
					end
				end
			end
		end
		task.wait(0.25)
	end
end

---------------------------------------------------------------
-- Partida
---------------------------------------------------------------

local function hookParticipant(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	hum.Died:Connect(function()
		if participants[plr] and state == "running" then
			participants[plr] = nil
			plr:SetAttribute("InRun", nil)
			statusEvent:FireClient(plr, { text = "You fell! Wait for the run to end." })
			task.delay(5, function()
				if plr.Parent then
					statusEvent:FireClient(plr, { clear = true })
				end
			end)
		end
	end)
end

local function runMap(mapId)
	local cfg = MapData.Maps[mapId]
	-- cfg.Arena: usa a arena de outro mapa (o Exame Ninja luta na arena Mapa_Ninja)
	local arena = workspace:FindFirstChild("Mapa_" .. ((cfg and cfg.Arena) or mapId))
	local spawnPart = arena and arena:FindFirstChild("ArenaSpawn")
	local centro = arena and arena:FindFirstChild("Centro")
	if not (cfg and spawnPart and centro) then
		warn("[WaveServer] Mapa não encontrado: " .. tostring(mapId))
		broadcast({ text = "Map unavailable." })
		task.wait(3)
		broadcast({ clear = true })
		cleanup()
		return
	end
	local floorY = arena:GetAttribute("PisoY") or centro.Position.Y

	getTemplate() -- prepara o modelo dos inimigos antes de começar

	for i = MapData.StartCountdown, 1, -1 do
		broadcast({ text = ("%s starts in %d..."):format(cfg.Name, i) })
		task.wait(1)
	end

	for plr in pairs(participants) do
		if not plr.Parent then
			participants[plr] = nil
		end
	end

	state = "running"
	local slot = 0
	for plr in pairs(participants) do
		local char = plr.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.Health > 0 and char.PrimaryPart then
			slot += 1
			local stats = PlayerData.GetCombatStats(plr)
			hum.MaxHealth = stats.Health
			hum.Health = stats.Health
			char:PivotTo(spawnPart.CFrame * CFrame.new((slot - 1) * 4 - 2, 3, 0))
			hookParticipant(plr)
		else
			participants[plr] = nil
		end
	end
	if participantCount() == 0 then
		cleanup()
		return
	end

	local n = participantCount()
	local hpScale = 1 + 0.6 * (n - 1)
	task.spawn(aiLoop, cfg, floorY, centro)
	print(("[WaveServer] %s iniciado com %d jogador(es)"):format(cfg.Name, n))

	local total = #cfg.Waves + 1 -- a última onda é o boss
	local victory = true

	for wave, w in ipairs(cfg.Waves) do
		print(("[WaveServer] Wave %d/%d: %s"):format(wave, total, w.Name))
		broadcast({ text = ("Wave %d/%d: %s"):format(wave, total, w.Name) })
		task.wait(2.5)

		for _, t in ipairs(w.Enemies) do
			local qtd = t.Count + (n - 1) * (t.Extra or 1)
			for _ = 1, qtd do
				spawnEnemy(t.Name, t.Color, t.Scale or 1, t.Health * hpScale, t.Damage,
					randomSpawnPos(centro, spawnPart, floorY, arena:GetAttribute("RaioSpawn") or 40), false, t.Speed, nil, t.Look)
			end
		end

		while aliveEnemyCount() > 0 and aliveParticipants() > 0 do
			broadcast({ text = ("Wave %d/%d: %s   |   Enemies: %d"):format(wave, total, w.Name, aliveEnemyCount()) })
			task.wait(0.5)
		end

		if aliveParticipants() == 0 then
			victory = false
			break
		end
		broadcast({ text = "Wave cleared!" })
		task.wait(MapData.PauseBetweenWaves)
	end

	if victory then
		print("[WaveServer] Boss: " .. cfg.BossName)
		broadcast({ text = ("Wave %d/%d: BOSS %s!"):format(total, total, cfg.BossName) })
		task.wait(3)
		local boss = spawnEnemy(cfg.BossName, cfg.BossColor, cfg.BossScale or 2.5, cfg.BossHealth * hpScale, cfg.BossDamage,
			Vector3.new(centro.Position.X, floorY + 10, centro.Position.Z - 20), true, nil, cfg.PlainBoss)
		if boss then
			boss.nextSlam = os.clock() + cfg.BossSlamEvery
			boss.nextBite = os.clock() + 5
			boss.nextSummon = os.clock() + 4
			while enemyAlive(boss) and aliveParticipants() > 0 do
				broadcast({
					text = (os.clock() < avisoAte) and avisoTexto or ("Wave %d/%d: Defeat %s"):format(total, total, cfg.BossName),
					boss = { name = cfg.BossName, hp = boss.hum.Health, max = boss.hum.MaxHealth },
				})
				task.wait(0.4)
			end
		end
		victory = boss ~= nil and not enemyAlive(boss) and aliveParticipants() > 0
		for _, e in ipairs(enemies) do
			if (e.isSnake or e.isMinion) and enemyAlive(e) then
				e.hum.Health = 0
			end
		end
	end

	state = "ending"

	if victory then
		local survivors = {}
		for plr in pairs(participants) do
			-- boosts 2x XP / 2x moedas (itens do Battle Pass) multiplicam a recompensa
			PlayerData.AddXP(plr, cfg.RewardXP * PlayerData.GetBoostMult(plr, "XP"))
			PlayerData.AddCoins(plr, cfg.RewardCoins * PlayerData.GetBoostMult(plr, "Coins"))
			table.insert(survivors, plr)
			partidaVencida:Fire(plr, mapId)
		end
		print("[WaveServer] Vitória!")
		broadcast({ text = ("VICTORY!   +%d XP   +%d coins"):format(cfg.RewardXP, cfg.RewardCoins) })
		task.wait(6)
		for _, plr in ipairs(survivors) do
			if plr.Parent then
				statusEvent:FireClient(plr, { clear = true })
				plr:LoadCharacter() -- volta para o lobby
			end
		end
	else
		print("[WaveServer] Derrota")
		broadcast({ text = "Defeat... try again!" })
		task.wait(4)
		broadcast({ clear = true })
	end

	cleanup()
end

local function onPortal(player, mapId)
	if not PlayerData.Get(player) then
		return
	end
	if state == "countdown" then
		participants[player] = true
		player:SetAttribute("InRun", true)
		return
	end
	if state ~= "idle" then
		statusEvent:FireClient(player, { text = "Run in progress. Wait for it to finish!" })
		task.delay(3, function()
			if player.Parent and not participants[player] then
				statusEvent:FireClient(player, { clear = true })
			end
		end)
		return
	end
	state = "countdown"
	participants = { [player] = true }
	player:SetAttribute("InRun", true)
	task.spawn(runMap, mapId)
end

local iniciarPartida = Instance.new("BindableEvent")
iniciarPartida.Name = "IniciarPartida"
iniciarPartida.Parent = ServerStorage
iniciarPartida.Event:Connect(onPortal)

for _, pad in ipairs(CollectionService:GetTagged("Portal")) do
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	local mapId = pad:GetAttribute("MapId")
	if prompt and mapId then
		prompt.Triggered:Connect(function(player)
			onPortal(player, mapId)
		end)
	end
end

Players.PlayerRemoving:Connect(function(player)
	participants[player] = nil
end)
