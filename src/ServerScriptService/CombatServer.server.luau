-- Script: ServerScriptService > CombatServer
-- Golpes do jogador. O cliente só avisa qual golpe quer usar; o servidor decide recarga e dano.
-- Estilo de luta (igual para todos os personagens por enquanto):
--   clique / toque / F  = combo de 4 golpes (3 socos rápidos + chute final)
--   X (segurar e soltar) = soco carregado
--   Y                    = soco aéreo
--   C                    = soco com investida

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local attackEvent = Instance.new("RemoteEvent")
attackEvent.Name = "Attack"
attackEvent.Parent = ReplicatedStorage

-- combo: multiplicador de dano, alcance, empurrão e tempo até poder bater de novo
local COMBO = {
	{ mult = 1.0, range = 9, force = 12, wait = 0.28 },
	{ mult = 1.0, range = 9, force = 12, wait = 0.28 },
	{ mult = 1.3, range = 9, force = 20, wait = 0.34 },
	{ mult = 2.2, range = 11, force = 55, wait = 0.6, kick = true },
}
local COMBO_RESET = 1.1 -- sem bater por esse tempo e o combo volta ao primeiro golpe
local CONE = 0.2 -- quanto maior, mais estreito o golpe à frente
local COOLDOWN = { charged = 3, air = 3, dash = 4 }

local state = {} -- [player] = { n, last, nextHit, cd = { charged, air, dash } }

local function getState(plr)
	if not state[plr] then
		state[plr] = { n = 0, last = 0, nextHit = 0, cd = { charged = 0, air = 0, dash = 0 } }
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

local function onCombo(plr, st, hum, root, dmg)
	local now = os.clock()
	if now < st.nextHit then
		return
	end
	if now - st.last > COMBO_RESET then
		st.n = 0
	end
	st.n = st.n % #COMBO + 1
	st.last = now
	local step = COMBO[st.n]
	st.nextHit = now + step.wait
	for _, e in ipairs(inFront(root, step.range, CONE)) do
		hit(e, dmg * step.mult, root.Position, step.force, step.kick and 30 or nil)
	end
	-- efeito do golpe: arco branco; o chute final é maior e mais baixo
	local fx = Instance.new("Part")
	fx.Size = step.kick and Vector3.new(9, 0.4, 7) or Vector3.new(5, 0.3, 5)
	fx.Material = Enum.Material.Neon
	fx.Color = step.kick and Color3.fromRGB(255, 220, 140) or Color3.fromRGB(255, 255, 255)
	fx.Transparency = 0.35
	fx.Anchored, fx.CanCollide, fx.CanQuery, fx.CanTouch, fx.CastShadow = true, false, false, false, false
	fx.CFrame = root.CFrame * CFrame.new(0, step.kick and -1.2 or 0.4, -4.5) * CFrame.Angles(0, 0, math.rad(st.n == 2 and 25 or -25))
	fx.Parent = workspace
	Debris:AddItem(fx, 0.15)
end

-- X: soco carregado — quanto mais tempo segurou (até ~1,2s), mais forte e longe
local function onCharged(plr, st, hum, root, dmg, held)
	if os.clock() < st.cd.charged then
		return
	end
	st.cd.charged = os.clock() + COOLDOWN.charged
	held = math.clamp(tonumber(held) or 0, 0, 1.5)
	local ratio = math.min(held / 1.2, 1)
	local range = 11 + ratio * 6
	local look = root.CFrame.LookVector
	for _, e in ipairs(inFront(root, range, CONE)) do
		hit(e, dmg * (2 + 4 * ratio), root.Position, 40 + 60 * ratio, 15 + 20 * ratio)
	end
	local pos = root.Position + Vector3.new(look.X, 0, look.Z).Unit * (range * 0.55)
	burst(pos, 8 + ratio * 12, Color3.fromRGB(255, 255, 255), 0.35)
	burst(pos, 4 + ratio * 8, Color3.fromRGB(255, 200, 90), 0.25)
end

-- Y: soco aéreo — só funciona no ar (o cliente pula primeiro se estiver no chão)
local function onAir(plr, st, hum, root, dmg)
	if os.clock() < st.cd.air then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air then
		return
	end
	st.cd.air = os.clock() + COOLDOWN.air
	for _, e in ipairs(inFront(root, 13, nil)) do
		hit(e, dmg * 2.5, root.Position, 45, 25)
	end
	burst(root.Position - Vector3.new(0, 2, 0), 18, Color3.fromRGB(190, 230, 255), 0.35)
	burst(root.Position, 8, Color3.fromRGB(255, 255, 255), 0.25)
end

-- C: soco com investida — o cliente avança e o servidor acerta quem for tocado durante 0,4s
local function onDash(plr, st, hum, root, dmg)
	if os.clock() < st.cd.dash then
		return
	end
	st.cd.dash = os.clock() + COOLDOWN.dash
	task.spawn(function()
		local hitSet = {}
		local t0 = os.clock()
		while os.clock() - t0 < 0.4 and root.Parent and hum.Health > 0 do
			local look = root.CFrame.LookVector
			for _, e in ipairs(enemies()) do
				if not hitSet[e.model] then
					local off = e.root.Position - root.Position
					local flat = Vector3.new(off.X, 0, off.Z)
					if flat.Magnitude <= 6.5 + e.raio and math.abs(off.Y) < 14 + e.raio * 2
						and (flat.Magnitude < 1.5 or flat.Unit:Dot(look) > -0.2) then
						hitSet[e.model] = true
						hit(e, dmg * 2.2, root.Position, 50, 12)
						burst(e.root.Position, 10, Color3.fromRGB(255, 255, 255), 0.3)
					end
				end
			end
			task.wait()
		end
	end)
end

attackEvent.OnServerEvent:Connect(function(plr, kind, extra)
	local hum, root, dmg = context(plr)
	if not hum then
		return
	end
	local st = getState(plr)
	if kind == "charged" then
		onCharged(plr, st, hum, root, dmg, extra)
	elseif kind == "air" then
		onAir(plr, st, hum, root, dmg)
	elseif kind == "dash" then
		onDash(plr, st, hum, root, dmg)
	else
		onCombo(plr, st, hum, root, dmg)
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	state[plr] = nil
end)
