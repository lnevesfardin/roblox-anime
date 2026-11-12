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

local function hit(e, amount, from, force, up)
	if e.hum.Health <= 0 then
		return
	end
	e.hum:TakeDamage(amount)
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
	burst(e.root.Position, 3 + e.raio, Color3.fromRGB(255, 255, 255), 0.18)
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
	for _, e in ipairs(inFront(root, step.range, CONE)) do
		hit(e, dmg * step.mult, root.Position, step.force, step.up)
		if step.prender then prender(e, step.prender) end
		acertos += 1
	end
	ganharMaestria(plr, id, acertos)
	-- efeito do golpe: arco na cor do estilo; chute é maior e mais baixo
	local fx = Instance.new("Part")
	fx.Size = step.kick and Vector3.new(9, 0.4, 7) or Vector3.new(5, 0.3, 5)
	fx.Material = Enum.Material.Neon
	fx.Color = st.n == #est.Combo and Color3.fromRGB(255, 220, 140) or est.Color
	fx.Transparency = 0.35
	fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch, fx.CastShadow = true, false, false, false, false
	fx.CFrame = root.CFrame * CFrame.new(0, step.kick and -1.2 or 0.4, -4.5) * CFrame.Angles(0, 0, math.rad(st.n == 2 and 25 or -25))
	fx.Parent = workspace
	Debris:AddItem(fx, 0.15)
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
	local hum, root, dmg = context(plr)
	if not hum then
		return
	end
	local st = getState(plr)
	local id, est, nivel = estiloDe(plr)
	dmg *= 1 + (nivel - 1) * FightStyles.BONUS_MAESTRIA
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

Players.PlayerRemoving:Connect(function(plr)
	state[plr] = nil
end)
