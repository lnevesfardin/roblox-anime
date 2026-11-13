-- Script: ServerScriptService > CombatServer
-- Golpes do jogador. O cliente só avisa qual golpe quer usar; o servidor decide recarga, chakra e dano.
-- Os golpes dependem do estilo de luta equipado (ReplicatedStorage > FightStyles — Fase 5):
--   clique / toque / F  = combo de 4 golpes do estilo
--   X (segurar e soltar) = golpe carregado (ou estrangulamento no Jiu-Jitsu)
--   Y                    = golpe aéreo / uppercut / arremesso
--   C                    = investida
-- Estilos: liberados pelas missões dos mestres (MissionServer), escolhidos pelo RemoteFunction
-- "EstiloAcao" ("equipar", id). Estado para o cliente: atributos "Estilo" e "EstiloEstado" (JSON).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local FightStyles = require(ReplicatedStorage:WaitForChild("FightStyles"))

local attackEvent = Instance.new("RemoteEvent")
attackEvent.Name = "Attack"
attackEvent.Parent = ReplicatedStorage

local estiloAcao = Instance.new("RemoteFunction")
estiloAcao.Name = "EstiloAcao"
estiloAcao.Parent = ReplicatedStorage

local CONE = 0.2 -- quanto maior, mais estreito o golpe à frente

local state = {} -- [player] = { n, last, nextHit, cd = { X, Y, C } }

local function getState(plr)
	if not state[plr] then
		state[plr] = { n = 0, last = 0, nextHit = 0, cd = { X = 0, Y = 0, C = 0 } }
	end
	return state[plr]
end

local function enemies()
	local list = {}
	for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and m.Parent and not m:GetAttribute("Sumido") then
			table.insert(list, { model = m, hum = h, root = r, raio = math.max(m:GetAttribute("Raio") or 0, 0) })
		end
	end
	return list
end

-- inimigos à frente do jogador (cone) ou ao redor (cone = nil)
local function inFront(root, range, cone)
	local look = root.CFrame.LookVector
	local out = {}
	for _, e in ipairs(enemies()) do
		local off = e.root.Position - root.Position
		local flat = Vector3.new(off.X, 0, off.Z)
		if flat.Magnitude <= range + e.raio and math.abs(off.Y) < 14 + e.raio * 2 then
			if not cone or flat.Magnitude < 1.5 or flat.Unit:Dot(look) > cone then
				table.insert(out, e)
			end
		end
	end
	return out
end

local function nearestInFront(root, range)
	local best, bd
	for _, e in ipairs(inFront(root, range, CONE)) do
		local d = (e.root.Position - root.Position).Magnitude
		if not bd or d < bd then
			best, bd = e, d
		end
	end
	return best
end

local function burst(pos, diameter, color, time)
	time = time or 0.25
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
	b.Material = Enum.Material.Neon
	b.Color = color
	b.Transparency = 0.2
	b.Size = Vector3.one
	b.CFrame = CFrame.new(pos)
	b.Parent = workspace
	TweenService:Create(b, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * diameter, Transparency = 1 }):Play()
	Debris:AddItem(b, time + 0.1)
end

-- rastro do golpe: uma meia-lua fina na frente do personagem, mais grossa no meio,
-- que some rápido (no lugar do quadrado branco de antes). n alterna o lado do golpe.
local function arco(root, n, kick, cor)
	local raio = kick and 4.6 or 3.3
	local altura = kick and -1.3 or 0.7
	local inclin = math.rad((n % 2 == 0) and 32 or -32)
	local base = root.CFrame * CFrame.new(0, altura, -0.8) * CFrame.Angles(0, 0, inclin)
	local segs = 9
	for i = 0, segs - 1 do
		local a0 = math.rad(-75 + i * (150 / segs))
		local a1 = math.rad(-75 + (i + 1) * (150 / segs))
		local p0 = (base * CFrame.new(math.sin(a0) * raio, 0, -math.cos(a0) * raio)).Position
		local p1 = (base * CFrame.new(math.sin(a1) * raio, 0, -math.cos(a1) * raio)).Position
		local w = 0.1 + 0.32 * math.sin(math.pi * (i + 0.5) / segs)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = cor
		p.Transparency = 0.3
		p.Size = Vector3.new(w, w * 0.5, (p1 - p0).Magnitude + 0.05)
		p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, i * 0.012),
			{ Transparency = 1, Size = p.Size * Vector3.new(0.4, 0.4, 1) }):Play()
		Debris:AddItem(p, 0.3)
	end
end

-- impacto no inimigo: faísca pequena + anel que abre
local function impacto(pos, tamanho, cor)
	burst(pos, tamanho, cor, 0.16)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
	r.Material = Enum.Material.Neon
	r.Color = Color3.fromRGB(255, 255, 255)
	r.Transparency = 0.35
	r.Size = Vector3.new(0.15, 1, 1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	r.Parent = workspace
	TweenService:Create(r, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, tamanho * 1.6, tamanho * 1.6), Transparency = 1 }):Play()
	Debris:AddItem(r, 0.3)
end

-- segura o inimigo parado por alguns segundos (Jiu-Jitsu)
local function prender(e, dur)
	if e.raio > 2 then
		dur *= 0.4
	end
	local hum = e.hum
	if hum:GetAttribute("VelPreso") == nil then
		hum:SetAttribute("VelPreso", hum.WalkSpeed)
	end
	local token = (hum:GetAttribute("PresoToken") or 0) + 1
	hum:SetAttribute("PresoToken", token)
	hum.WalkSpeed = 0
	task.delay(dur, function()
		if hum.Parent and hum:GetAttribute("PresoToken") == token then
			hum.WalkSpeed = hum:GetAttribute("VelPreso") or 13
			hum:SetAttribute("VelPreso", nil)
		end
	end)
end

-- Gelo: deixa o inimigo mais lento por alguns segundos (com um brilho azul)
local function lento(e, dur)
	local hum = e.hum
	if hum:GetAttribute("VelPreso") ~= nil or hum:GetAttribute("Lento") then return end
	hum:SetAttribute("Lento", true)
	local antes = hum.WalkSpeed
	hum.WalkSpeed = antes * 0.55
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.fromRGB(150, 220, 255)
	hl.FillTransparency = 0.6
	hl.OutlineTransparency = 1
	hl.Parent = e.model
	task.delay(dur, function()
		if hum.Parent then
			if hum:GetAttribute("VelPreso") == nil then hum.WalkSpeed = antes end
			hum:SetAttribute("Lento", nil)
		end
		hl:Destroy()
	end)
end

-- Lava: queima o inimigo por alguns segundos
local function queimar(e, porTick, ticks)
	if e.hum:GetAttribute("Queimando") then return end
	e.hum:SetAttribute("Queimando", true)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.6)
			if e.hum.Health <= 0 or not e.root.Parent then break end
			e.hum:TakeDamage(porTick)
			burst(e.root.Position + Vector3.new(0, 1, 0), 2.5, Color3.fromRGB(255, 110, 40), 0.25)
		end
		if e.hum.Parent then e.hum:SetAttribute("Queimando", nil) end
	end)
end

---------------------------------------------------------------
-- Estilo e maestria
---------------------------------------------------------------

local function enviarEstilo(plr)
	local data = PlayerData.Get(plr)
	if not data then return end
	local e = FightStyles.Garantir(data)
	plr:SetAttribute("Estilo", e.Equipado)
	plr:SetAttribute("EstiloEstado", HttpService:JSONEncode({ Eq = e.Equipado, Lib = e.Liberados, XP = e.XP }))
end

local atualizarEv = Instance.new("BindableEvent")
atualizarEv.Name = "AtualizarEstilos"
atualizarEv.Parent = ServerStorage
atualizarEv.Event:Connect(enviarEstilo)

estiloAcao.OnServerInvoke = function(plr, acao, id)
	local data = PlayerData.Get(plr)
	if not data then return { ok = false } end
	local e = FightStyles.Garantir(data)
	if acao == "equipar" and type(id) == "string" and FightStyles.Styles[id] and e.Liberados[id] then
		e.Equipado = id
		enviarEstilo(plr)
		return { ok = true }
	end
	return { ok = false }
end

local function estiloDe(plr)
	local data = PlayerData.Get(plr)
	if not data then return "Basico", FightStyles.Styles.Basico, 1 end
	local e = FightStyles.Garantir(data)
	local id = e.Equipado
	return id, FightStyles.Get(id), FightStyles.Nivel(e.XP[id])
end

-- cada golpe que acerta conta para a maestria do estilo
local aviso = ReplicatedStorage:WaitForChild("AbilityFeedback", 30)
local function ganharMaestria(plr, id, qtd)
	local data = PlayerData.Get(plr)
	if not data or qtd <= 0 then return end
	local e = FightStyles.Garantir(data)
	local antes = FightStyles.Nivel(e.XP[id])
	e.XP[id] = (e.XP[id] or 0) + qtd
	local depois = FightStyles.Nivel(e.XP[id])
	if depois > antes then
		if aviso then
			aviso:FireClient(plr, { msg = ("%s mastery %d!  (+%d%% damage)"):format(FightStyles.Get(id).Name, depois, math.floor((depois - 1) * FightStyles.BONUS_MAESTRIA * 100 + 0.5)) })
		end
		enviarEstilo(plr)
	elseif e.XP[id] % 10 < qtd then
		enviarEstilo(plr)
	end
end

local function prepararJogador(plr)
	for _ = 1, 60 do
		if PlayerData.Get(plr) then break end
		task.wait(0.25)
	end
	if plr.Parent then enviarEstilo(plr) end
end
Players.PlayerAdded:Connect(prepararJogador)
for _, plr in ipairs(Players:GetPlayers()) do task.spawn(prepararJogador, plr) end

---------------------------------------------------------------
-- Golpes
---------------------------------------------------------------

-- quem bateu por último (o chefe do mundo divide a recompensa pelo dano)
local atacanteAtual = nil

local function hit(e, amount, from, force, up)
	if e.hum.Health <= 0 then
		return
	end
	if atacanteAtual then e.hum:SetAttribute("UltimoAtacante", atacanteAtual) end
	e.hum:TakeDamage(amount)
	-- kill só com taijutsu (soco/chute, sem nenhum dano de jutsu nesse inimigo) conta para a missão do estilo Lee
	if e.hum.Health <= 0 and atacanteAtual and e.model:GetAttribute("DanoJutsu") ~= true then
		local autor = Players:GetPlayerByUserId(atacanteAtual)
		local prog = autor and ServerStorage:FindFirstChild("MissaoProgresso")
		if prog then prog:Fire(autor, "taijutsu", 1) end
	end
	-- o golpe "conecta": inimigo comum fica travado um instante e não revida no meio do combo (chefes não)
	if e.raio <= 2 then
		e.model:SetAttribute("Atordoado", math.max(e.model:GetAttribute("Atordoado") or 0, os.clock() + 0.7))
	end
	if force and force > 0 and not e.root.Anchored then
		if e.raio > 2 then
			force *= 0.2 -- o boss quase não é empurrado
			up = (up or 0) * 0.2
		end
		local d = (e.root.Position - from) * Vector3.new(1, 0, 1)
		if d.Magnitude < 0.1 then
			d = Vector3.new(0, 0, 1)
		end
		e.root.AssemblyLinearVelocity = d.Unit * force + Vector3.new(0, up or force * 0.2, 0)
	end
	impacto(e.root.Position, 2.4 + e.raio, Color3.fromRGB(255, 235, 180))
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.4
	hl.OutlineTransparency = 1
	hl.Parent = e.model
	Debris:AddItem(hl, 0.1)
end

local function context(plr)
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	-- BuffDano: poderes de clã como Sharingan e Abertura dos Portões
	return hum, root, PlayerData.GetCombatStats(plr).Damage * (1 + (plr:GetAttribute("BuffDano") or 0))
end

-- paga o chakra do golpe especial (o clã Lee paga menos). Devolve false se não tiver.
local function pagar(plr, custo)
	custo = (custo or 0) * (1 - (plr:GetAttribute("DescontoEnergia") or 0))
	local c = plr:GetAttribute("Chakra")
	if c == nil then return true end
	if c < custo then
		if aviso then aviso:FireClient(plr, { msg = "Not enough chakra." }) end
		return false
	end
	plr:SetAttribute("Chakra", c - custo)
	return true
end

local function onCombo(plr, st, hum, root, dmg, id, est)
	local now = os.clock()
	if now < st.nextHit then
		return
	end
	if now - st.last > FightStyles.COMBO_RESET then
		st.n = 0
	end
	st.n = st.n % #est.Combo + 1
	st.last = now
	local step = est.Combo[st.n]
	st.nextHit = now + step.wait
	local acertos = 0
	local kekkei = plr:GetAttribute("Kekkei")
	for _, e in ipairs(inFront(root, step.range, CONE)) do
		hit(e, dmg * step.mult, root.Position, step.force, step.up)
		if step.prender then prender(e, step.prender) end
		-- passivos de Kekkei Genkai nos socos
		if kekkei == "Gelo" then
			lento(e, 1.5)
		elseif kekkei == "Lava" then
			queimar(e, dmg * 0.12, 3)
		end
		acertos += 1
	end
	ganharMaestria(plr, id, acertos)
	-- efeito do golpe: rastro em meia-lua na cor do estilo; chute é maior e mais baixo
	arco(root, st.n, step.kick, st.n == #est.Combo and Color3.fromRGB(255, 220, 140) or est.Color)
end

-- X: golpe carregado — quanto mais tempo segurou (até ~1,2s), mais forte e longe.
-- No Jiu-Jitsu é um estrangulamento: segura o inimigo da frente e machuca aos poucos.
local function onX(plr, st, hum, root, dmg, id, est, held)
	local x = est.X
	if os.clock() < st.cd.X then
		return
	end
	if not pagar(plr, x.Chakra) then return end
	st.cd.X = os.clock() + x.Cd
	if x.Tipo == "estrangular" then
		local e = nearestInFront(root, x.Range)
		if not e then
			burst(root.Position + root.CFrame.LookVector * 3, 4, est.Color, 0.25)
			return
		end
		prender(e, x.Tempo)
		local ticks = 5
		for _ = 1, ticks do
			if e.hum.Health <= 0 then break end
			hit(e, dmg * x.Mult / ticks, nil, 0)
			burst(e.root.Position + Vector3.new(0, 1.5, 0), 3, est.Color, 0.2)
			task.wait(x.Tempo / ticks)
		end
		ganharMaestria(plr, id, 1)
		return
	end
	held = math.clamp(tonumber(held) or 0, 0, 1.5)
	local ratio = math.min(held / 1.2, 1)
	local range = x.Range + ratio * x.RangeExtra
	local look = root.CFrame.LookVector
	local acertos = 0
	for _, e in ipairs(inFront(root, range, CONE)) do
		hit(e, dmg * (x.Base + x.Extra * ratio), root.Position, x.Force + x.ForceExtra * ratio, 15 + 20 * ratio)
		acertos += 1
	end
	ganharMaestria(plr, id, acertos)
	local pos = root.Position + Vector3.new(look.X, 0, look.Z).Unit * (range * 0.55)
	burst(pos, 8 + ratio * 12, Color3.fromRGB(255, 255, 255), 0.35)
	burst(pos, 4 + ratio * 8, est.Color, 0.25)
end

-- Y: "aereo" só funciona no ar (o cliente pula antes); "uppercut" joga para cima;
-- "arremesso" pega o inimigo da frente e joga por cima do ombro
local function onY(plr, st, hum, root, dmg, id, est)
	local y = est.Y
	if os.clock() < st.cd.Y then
		return
	end
	if y.Tipo == "aereo" and hum.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if not pagar(plr, y.Chakra) then return end
	st.cd.Y = os.clock() + y.Cd
	local acertos = 0
	if y.Tipo == "aereo" then
		for _, e in ipairs(inFront(root, y.Range, nil)) do
			hit(e, dmg * y.Mult, root.Position, 45, 25)
			acertos += 1
		end
		burst(root.Position - Vector3.new(0, 2, 0), 18, Color3.fromRGB(190, 230, 255), 0.35)
		burst(root.Position, 8, est.Color, 0.25)
	elseif y.Tipo == "uppercut" then
		for _, e in ipairs(inFront(root, y.Range, CONE)) do
			hit(e, dmg * y.Mult, root.Position, 8, 75)
			acertos += 1
		end
		burst(root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 2, 0), 8, est.Color, 0.3)
	elseif y.Tipo == "arremesso" then
		local e = nearestInFront(root, y.Range)
		if e then
			hit(e, dmg * y.Mult, nil, 0)
			if e.raio <= 2 then
				e.root.AssemblyLinearVelocity = -root.CFrame.LookVector * 45 + Vector3.new(0, 55, 0)
			end
			acertos = 1
			task.delay(0.6, function()
				if e.root.Parent then burst(e.root.Position - Vector3.new(0, 2, 0), 9, est.Color, 0.3) end
			end)
		else
			burst(root.Position + root.CFrame.LookVector * 3, 4, est.Color, 0.25)
		end
	end
	ganharMaestria(plr, id, acertos)
end

-- C: investida — o cliente avança e o servidor acerta quem for tocado durante a investida
local function onC(plr, st, hum, root, dmg, id, est)
	local c = est.C
	if os.clock() < st.cd.C then
		return
	end
	if not pagar(plr, c.Chakra) then return end
	st.cd.C = os.clock() + c.Cd
	task.spawn(function()
		local hitSet = {}
		local acertos = 0
		local t0 = os.clock()
		while os.clock() - t0 < c.Time + 0.12 and root.Parent and hum.Health > 0 do
			local look = root.CFrame.LookVector
			for _, e in ipairs(enemies()) do
				if not hitSet[e.model] then
					local off = e.root.Position - root.Position
					local flat = Vector3.new(off.X, 0, off.Z)
					if flat.Magnitude <= 6.5 + e.raio and math.abs(off.Y) < 14 + e.raio * 2
						and (flat.Magnitude < 1.5 or flat.Unit:Dot(look) > -0.2) then
						hitSet[e.model] = true
						hit(e, dmg * c.Mult, root.Position, c.Prender and 10 or 50, 12)
						if c.Prender then prender(e, c.Prender) end
						burst(e.root.Position, 10, est.Color, 0.3)
						acertos += 1
					end
				end
			end
			task.wait()
		end
		ganharMaestria(plr, id, acertos)
	end)
end

attackEvent.OnServerEvent:Connect(function(plr, kind, extra)
	atacanteAtual = plr.UserId
	local hum, root, dmg = context(plr)
	if not hum then
		return
	end
	local st = getState(plr)
	local id, est, nivel = estiloDe(plr)
	dmg *= 1 + (nivel - 1) * FightStyles.BONUS_MAESTRIA
	if id == "Lee" then dmg *= 1 + (plr:GetAttribute("PortaoLee") or 0) * FightStyles.PORTOES.DANO end
	if kind == "charged" then
		onX(plr, st, hum, root, dmg, id, est, extra)
	elseif kind == "air" then
		onY(plr, st, hum, root, dmg, id, est)
	elseif kind == "dash" then
		onC(plr, st, hum, root, dmg, id, est)
	else
		onCombo(plr, st, hum, root, dmg, id, est)
	end
end)

---------------------------------------------------------------
-- 8 Portões Internos (estilo Lee): RemoteEvent "PortaoLee" (tecla Z) abre o próximo portão.
-- Atributos do jogador: PortaoLee (portões abertos) e PortaoVel (bônus de velocidade, lido pelo Corrida).
---------------------------------------------------------------
local portaoEv = Instance.new("RemoteEvent")
portaoEv.Name = "PortaoLee"
portaoEv.Parent = ReplicatedStorage
local PORT = FightStyles.PORTOES
local portaoLoop = {} -- [plr] = true enquanto o loop de custo roda
local portaoUlt = {}

local function fecharPortoes(plr, cansaco)
	plr:SetAttribute("PortaoLee", 0)
	plr:SetAttribute("PortaoVel", cansaco and -9 or 0)
	if cansaco then
		task.delay(PORT.CANSACO, function()
			if plr.Parent and (plr:GetAttribute("PortaoLee") or 0) == 0 then plr:SetAttribute("PortaoVel", 0) end
		end)
	end
end

local function loopPortoes(plr)
	if portaoLoop[plr] then return end
	portaoLoop[plr] = true
	task.spawn(function()
		local aberto8 = 0
		local esgotou = false
		while plr.Parent and (plr:GetAttribute("PortaoLee") or 0) > 0 do
			task.wait(0.5)
			local n = plr:GetAttribute("PortaoLee") or 0
			local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
			local chakra = plr:GetAttribute("Chakra")
			local id = estiloDe(plr)
			if not hum or hum.Health <= 0 or id ~= "Lee" or n <= 0 then break end
			if chakra then
				chakra -= PORT.CHAKRA_SEG * n * 0.5
				if chakra <= 0 then plr:SetAttribute("Chakra", 0) break end
				plr:SetAttribute("Chakra", chakra)
			end
			-- a vida cai, mas nunca mata
			hum.Health = math.max(1, hum.Health - hum.MaxHealth * PORT.VIDA_SEG * n * 0.5)
			if n >= 8 then
				aberto8 += 0.5
				if aberto8 >= 12 then esgotou = true break end -- o 8º portão só dura 12 s
			else
				aberto8 = 0
			end
		end
		portaoLoop[plr] = nil
		if plr.Parent then fecharPortoes(plr, esgotou) end
	end)
end

portaoEv.OnServerEvent:Connect(function(plr)
	local now = os.clock()
	if now - (portaoUlt[plr] or 0) < 0.6 then return end
	portaoUlt[plr] = now
	local id, _, nivel = estiloDe(plr)
	local hum = plr.Character and plr.Character:FindFirstChildOfClass("Humanoid")
	if id ~= "Lee" or not hum or hum.Health <= 0 then return end
	local n = plr:GetAttribute("PortaoLee") or 0
	local maxN = PORT.MAX_POR_MAESTRIA[math.clamp(nivel, 1, #PORT.MAX_POR_MAESTRIA)]
	if n >= maxN then
		if aviso then
			local prox = 0
			for m, v in ipairs(PORT.MAX_POR_MAESTRIA) do if v > n then prox = m break end end
			aviso:FireClient(plr, { msg = prox > 0 and ("Gate %d unlocks at Lee mastery %d."):format(n + 1, prox) or "All gates are open!" })
		end
		return
	end
	if hum.Health < hum.MaxHealth * 0.2 then
		if aviso then aviso:FireClient(plr, { msg = "Too hurt to open another gate." }) end
		return
	end
	if not pagar(plr, PORT.CHAKRA_ABRIR) then return end
	n += 1
	plr:SetAttribute("PortaoLee", n)
	plr:SetAttribute("PortaoVel", n * PORT.VELOCIDADE)
	if aviso then aviso:FireClient(plr, { msg = ("%s opened!  (%d/8)"):format(PORT.NOMES[n], n) }) end
	loopPortoes(plr)
end)

Players.PlayerRemoving:Connect(function(plr)
	state[plr] = nil
	portaoLoop[plr] = nil
	portaoUlt[plr] = nil
end)
