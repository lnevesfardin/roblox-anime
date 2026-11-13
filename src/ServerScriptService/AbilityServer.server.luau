-- Script: ServerScriptService > AbilityServer
-- Poderes do clã (Q, E, R), Kekkei Genkai (V, posição 4) e jutsus de natureza (G e H, posições 5 e 6). O cliente só avisa qual posição usou;
-- o servidor confere o clã, se o poder está liberado, a recarga e o chakra, e calcula o dano.
-- Nomes, recargas, custos e requisitos ficam em ReplicatedStorage > ClanPowers.
-- Estado para o cliente: atributos do jogador "PoderesEstado" (JSON), "Chakra" e "ChakraMax".
-- Buffs temporários: atributos "BuffDano" (multiplicador extra) e "BuffVelocidade" (studs/s).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local HttpService = game:GetService("HttpService")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local ClanPowers = require(ReplicatedStorage:WaitForChild("ClanPowers"))
local KekkeiData = require(ReplicatedStorage:WaitForChild("KekkeiData"))
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))

local useEvent = Instance.new("RemoteEvent")
useEvent.Name = "UseAbility"
useEvent.Parent = ReplicatedStorage

local feedbackEvent = Instance.new("RemoteEvent")
feedbackEvent.Name = "AbilityFeedback"
feedbackEvent.Parent = ReplicatedStorage

local cooldowns = {} -- [player] = { [idDoPoder] = horaLiberada }
local conjurar -- efeito ao soltar um jutsu (definido antes da lista de poderes)

---------------------------------------------------------------
-- Auxiliares
---------------------------------------------------------------

local function fx(o)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = o.mat or Enum.Material.Neon
	if o.shape then p.Shape = o.shape end
	p.Size = o.size
	p.Color = o.color
	p.Transparency = o.trans or 0
	p.CFrame = o.cf or CFrame.new()
	p.Parent = o.parent or workspace
	return p
end

local function light(part, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range or 12
	l.Brightness = brightness or 2
	l.Parent = part
	return l
end

---------------------------------------------------------------
-- Camada de efeitos (usada por todos os jutsus): partículas, clarão de luz, tremor de tela, rastros
---------------------------------------------------------------
local TEX = {
	faisca = "rbxasset://textures/particles/sparkles_main.dds",
	fumaca = "rbxasset://textures/particles/smoke_main.dds",
	fogo = "rbxasset://textures/particles/fire_main.dds",
}
local tremorEv = Instance.new("RemoteEvent")
tremorEv.Name = "TremerTela"
tremorEv.Parent = ReplicatedStorage

-- solta uma rajada de partículas num ponto. o = { tex, tam, vida, vel, drag, acel, luz, cor2, spread }
local function emitir(pos, cor, qtd, o)
	o = o or {}
	local base = fx({ size = Vector3.one * 0.2, color = cor, trans = 1, cf = CFrame.new(pos) })
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX[o.tex or "faisca"]
	pe.Color = ColorSequence.new(cor, o.cor2 or cor)
	pe.LightEmission = o.luz or 1
	local tam = o.tam or 0.8
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, tam), NumberSequenceKeypoint.new(1, o.cresce and tam * 2.5 or 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, o.tex == "fumaca" and 0.4 or 0), NumberSequenceKeypoint.new(1, 1) })
	local vida = o.vida or 0.4
	pe.Lifetime = NumberRange.new(vida * 0.6, vida * 1.4)
	local vel = o.vel or 14
	pe.Speed = NumberRange.new(vel * 0.5, vel * 1.3)
	local spread = o.spread or 180
	pe.SpreadAngle = Vector2.new(spread, spread)
	pe.Drag = o.drag or 5
	pe.Acceleration = o.acel or Vector3.zero
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Rate = 0
	pe.Parent = base
	pe:Emit(math.clamp(math.floor(qtd), 1, 80))
	Debris:AddItem(base, vida * 1.5 + 0.3)
end

-- clarão de luz rápido
local function clarao(pos, cor, alcance, brilho)
	local p = fx({ size = Vector3.one * 0.2, color = cor, trans = 1, cf = CFrame.new(pos) })
	local l = light(p, cor, alcance or 18, brilho or 6)
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
	Debris:AddItem(p, 0.4)
end

-- tremor de tela para quem está perto (o cliente faz o efeito)
local function tremor(pos, forca)
	tremorEv:FireAllClients(pos, math.clamp(forca or 0.5, 0.1, 2))
end

local function burst(pos, diameter, color, time, trans)
	time = time or 0.4
	local b = fx({ shape = Enum.PartType.Ball, size = Vector3.one, color = color, cf = CFrame.new(pos), trans = trans or 0.2 })
	TweenService:Create(b, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * diameter, Transparency = 1 }):Play()
	Debris:AddItem(b, time + 0.1)
	-- núcleo branco que some rápido, faíscas e luz
	local nucleo = fx({ shape = Enum.PartType.Ball, size = Vector3.one * diameter * 0.35, color = Color3.new(1, 1, 1), cf = CFrame.new(pos), trans = 0.1 })
	TweenService:Create(nucleo, TweenInfo.new(time * 0.5, Enum.EasingStyle.Quad), { Size = Vector3.one * 0.2, Transparency = 1 }):Play()
	Debris:AddItem(nucleo, time * 0.5 + 0.1)
	emitir(pos, color, diameter * 1.4, { vel = diameter * 1.6, tam = math.clamp(diameter * 0.08, 0.35, 1.4), vida = 0.45, cor2 = Color3.new(1, 1, 1) })
	clarao(pos, color, diameter * 1.6, 5)
	if diameter >= 14 then
		emitir(pos, Color3.fromRGB(120, 115, 110), diameter * 0.5, { tex = "fumaca", vel = diameter * 0.5, tam = diameter * 0.12, vida = 0.9, luz = 0, cresce = true, drag = 3 })
		tremor(pos, diameter / 22)
	end
end

local function fadeOut(part, time)
	TweenService:Create(part, TweenInfo.new(time), { Transparency = 1 }):Play()
	Debris:AddItem(part, time + 0.1)
end

local function flat(a, b)
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end

local function flatLook(root)
	local l = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if l.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return l.Unit
end

local function handPos(char, root)
	local h = char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")
	return h and h.Position or (root.Position + root.CFrame.LookVector * 1.5)
end

local function getEnemies()
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

local function inRadius(pos, r)
	local out = {}
	for _, e in ipairs(getEnemies()) do
		if flat(e.root.Position, pos) <= r + e.raio and math.abs(e.root.Position.Y - pos.Y) < r + 8 then
			table.insert(out, e)
		end
	end
	return out
end

-- inimigo mais próximo, preferindo os que estão na frente
local function nearestEnemy(origin, look, maxDist)
	local best, bestScore
	for _, e in ipairs(getEnemies()) do
		local d = flat(e.root.Position, origin)
		if d <= maxDist + e.raio and math.abs(e.root.Position.Y - origin.Y) < 30 then
			local dir = (e.root.Position - origin) * Vector3.new(1, 0, 1)
			local dot = dir.Magnitude > 0.1 and dir.Unit:Dot(look) or 1
			local score = d - dot * 15
			if not bestScore or score < bestScore then
				best, bestScore = e, score
			end
		end
	end
	return best
end

-- numeros de dano flutuantes: so quem bateu ve (o cliente desenha em DanoNumeroClient); corJutsu = cor do ultimo jutsu de cada jogador
local numeroEvent = ReplicatedStorage:FindFirstChild("DanoNumero")
if not numeroEvent then
	numeroEvent = Instance.new("RemoteEvent")
	numeroEvent.Name = "DanoNumero"
	numeroEvent.Parent = ReplicatedStorage
end
local function numero(e, valor, userId, cor, tipo)
	local autor = userId and Players:GetPlayerByUserId(userId)
	if autor and valor >= 0.5 and e.root then
		numeroEvent:FireClient(autor, e.root.Position + Vector3.new(0, 1.5 + e.raio, 0), math.floor(valor + 0.5), cor, tipo)
	end
end

local corJutsu = {} -- [userId] = Color3

-- quem bateu por último (o chefe do mundo divide a recompensa pelo dano)
local atacanteAtual = nil

local function hit(e, amount, from, force)
	if e.hum.Health <= 0 then
		return
	end
	if atacanteAtual then e.hum:SetAttribute("UltimoAtacante", atacanteAtual) end
	e.model:SetAttribute("DanoJutsu", true) -- este inimigo já levou jutsu: a kill não vale como "só taijutsu"
	e.hum:TakeDamage(amount)
	numero(e, amount, atacanteAtual, corJutsu[atacanteAtual or 0] or Color3.fromRGB(120, 190, 255), "jutsu")
	-- o golpe "conecta": inimigo comum fica travado um instante e não revida no meio do combo (chefes não)
	if e.raio <= 2 then
		e.model:SetAttribute("Atordoado", math.max(e.model:GetAttribute("Atordoado") or 0, os.clock() + 0.7))
	end
	if from and force and force > 0 and not e.root.Anchored then
		if e.raio > 2 then
			force *= 0.2 -- o boss quase não é empurrado
		end
		local d = (e.root.Position - from) * Vector3.new(1, 0, 1)
		if d.Magnitude < 0.1 then
			d = Vector3.new(0, 0, 1)
		end
		e.root.AssemblyLinearVelocity = d.Unit * force + Vector3.new(0, force * 0.35, 0)
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.35
	hl.OutlineTransparency = 1
	hl.Parent = e.model
	Debris:AddItem(hl, 0.12)
	-- faíscas de impacto
	emitir(e.root.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(255, 235, 170), 8, { vel = 22, tam = 0.35, vida = 0.25, drag = 8 })
end

-- move peças ou um modelo em linha reta até bater num inimigo ou acabar o alcance
local function rastro(part, cor, largura)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, largura / 2, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -largura / 2, 0)
	a1.Parent = part
	local t = Instance.new("Trail")
	t.Attachment0, t.Attachment1 = a0, a1
	t.Color = ColorSequence.new(Color3.new(1, 1, 1), cor)
	t.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	t.Lifetime = 0.25
	t.LightEmission = 1
	t.FaceCamera = true
	t.Parent = part
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX.faisca
	pe.Color = ColorSequence.new(cor)
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, largura * 0.4), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.4)
	pe.Speed = NumberRange.new(1, 4)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Rate = 45
	pe.Parent = part
end

local function projectile(o)
	if o.parts then
		for _, p in ipairs(o.parts) do
			if p:IsA("BasePart") and p.Transparency < 0.9 then
				rastro(p, p.Color, math.max(p.Size.X, p.Size.Y) * 0.8)
				break
			end
		end
	elseif o.model and o.model.PrimaryPart then
		rastro(o.model.PrimaryPart, o.model.PrimaryPart.Color, 2)
	end
	task.spawn(function()
		local pos, travelled, ang = o.start, 0, 0
		while travelled < o.range do
			local dt = task.wait()
			local step = o.speed * dt
			pos += o.dir * step
			travelled += step
			ang += dt * (o.spin or 0)
			local cf = CFrame.lookAt(pos, pos + o.dir) * CFrame.Angles(0, 0, ang)
			if o.model then
				o.model:PivotTo(CFrame.new(pos) * CFrame.Angles(0, ang, 0))
			else
				for _, p in ipairs(o.parts) do
					p.CFrame = cf
				end
			end
			if #inRadius(pos, o.radius) > 0 then
				break
			end
		end
		if o.model then
			o.model:Destroy()
		else
			for _, p in ipairs(o.parts) do
				p:Destroy()
			end
		end
		o.onEnd(pos)
	end)
end

-- raio em zigue-zague entre dois pontos
local function zap(a, b, color, width, jitter, life)
	local dir = b - a
	local n = math.max(3, math.floor(dir.Magnitude / 3))
	local pts = { a }
	for i = 1, n - 1 do
		pts[#pts + 1] = a + dir * (i / n) + Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1) * jitter
	end
	pts[#pts + 1] = b
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local len = (p1 - p0).Magnitude
		if len > 0.05 then
			local cf = CFrame.lookAt((p0 + p1) / 2, p1)
			local part = fx({ size = Vector3.new(width * 0.6, width * 0.6, len), color = Color3.new(1, 1, 1), cf = cf })
			fadeOut(part, life or 0.25)
			local brilho = fx({ size = Vector3.new(width * 2.4, width * 2.4, len), color = color, trans = 0.55, cf = cf })
			fadeOut(brilho, (life or 0.25) * 0.8)
		end
	end
	emitir(b, color, 10, { vel = 18, tam = width * 0.5, vida = 0.3, cor2 = Color3.new(1, 1, 1) })
	clarao(b, color, 16, 4)
end

-- esfera escura no ar com linhas que são sugadas para o centro (ou saem dele, se outward)
local function vortex(center, maxSize, duration, outward, onStep)
	local shell = fx({ shape = Enum.PartType.Ball, size = Vector3.one, color = Color3.fromRGB(12, 6, 20), trans = 0.15, mat = Enum.Material.SmoothPlastic, cf = CFrame.new(center) })
	local core = fx({ shape = Enum.PartType.Ball, size = Vector3.one, color = Color3.fromRGB(240, 235, 255), cf = CFrame.new(center) })
	light(core, Color3.fromRGB(190, 150, 255), 40, 3)
	local streaks = {}
	for i = 1, 22 do
		local d = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
		if d.Magnitude < 0.2 then d = Vector3.new(1, 0.3, 0) end
		local st = fx({ size = Vector3.new(0.3, 0.3, 7), color = (i % 2 == 0) and Color3.fromRGB(235, 225, 255) or Color3.fromRGB(40, 20, 70), cf = CFrame.new(center) })
		streaks[i] = { part = st, dir = d.Unit, phase = math.random() }
	end
	local t0 = os.clock()
	while true do
		local k = (os.clock() - t0) / duration
		if k >= 1 then break end
		local grow = outward and (1 - k) or math.min(k * 1.6, 1)
		shell.Size = Vector3.one * maxSize * grow
		core.Size = Vector3.one * maxSize * grow * 0.55
		for _, st in ipairs(streaks) do
			local ph = (k * 1.8 + st.phase) % 1
			local r = outward and (ph * maxSize * 2.2) or ((1 - ph) * maxSize * 2.2)
			st.part.CFrame = CFrame.lookAt(center + st.dir * (r + maxSize * 0.4), center)
		end
		if onStep then onStep(k) end
		task.wait()
	end
	burst(center, maxSize * 1.6, Color3.fromRGB(215, 190, 255), 0.4, 0.3)
	shell:Destroy()
	core:Destroy()
	for _, st in ipairs(streaks) do st.part:Destroy() end
end

local function bezier(a, b, c, t)
	local u = 1 - t
	return a * u * u + b * 2 * u * t + c * t * t
end

-- corpo de dragão feito de esferas que segue uma curva
local function dragon(o)
	local segs = {}
	for i = 1, o.count do
		local s = o.headSize * (1 - (i - 1) / o.count * 0.65)
		local color = o.colorA:Lerp(o.colorB, (i - 1) / o.count)
		table.insert(segs, fx({ shape = Enum.PartType.Ball, size = Vector3.one * s, color = color, cf = CFrame.new(o.p0), trans = o.trans or 0 }))
	end
	local horns = {}
	for _, sx in ipairs({ -1, 1 }) do
		table.insert(horns, fx({ size = Vector3.new(0.4, 0.4, o.headSize * 0.9), color = o.colorB, cf = CFrame.new(o.p0) }))
	end
	light(segs[1], o.colorA, 20, 3)
	local lag = o.lag or 0.045
	local t0 = os.clock()
	local struck = false
	while true do
		local t = (os.clock() - t0) / o.duration
		for i, s in ipairs(segs) do
			local ti = math.clamp(t - (i - 1) * lag, 0, 1)
			s.CFrame = CFrame.new(bezier(o.p0, o.p1, o.p2, ti))
		end
		local th = math.clamp(t, 0, 1)
		local head = bezier(o.p0, o.p1, o.p2, th)
		local prev = bezier(o.p0, o.p1, o.p2, math.max(th - 0.03, 0))
		local dir = head - prev
		if dir.Magnitude > 0.01 then
			local hcf = CFrame.lookAt(head, head + dir)
			for k, hpart in ipairs(horns) do
				local sx = (k == 1) and -1 or 1
				hpart.CFrame = hcf * CFrame.new(sx * o.headSize * 0.35, o.headSize * 0.45, o.headSize * 0.3) * CFrame.Angles(math.rad(25), 0, 0)
			end
		end
		if o.onStep then
			o.onStep(head)
		end
		if t >= 1 and not struck then
			struck = true
			o.onArrive(head)
		end
		if t >= 1 + o.count * lag then
			break
		end
		task.wait()
	end
	for _, s in ipairs(segs) do
		fadeOut(s, 0.25)
	end
	for _, h in ipairs(horns) do
		fadeOut(h, 0.25)
	end
end

local function smoke(pos, color)
	burst(pos + Vector3.new(0, 2, 0), 9, Color3.fromRGB(235, 235, 235), 0.5, 0.3)
	if color then
		burst(pos + Vector3.new(0, 2, 0), 6, color, 0.4, 0.4)
	end
end

local function feedback(plr, payload)
	if plr.Parent then
		feedbackEvent:FireClient(plr, payload)
	end
end

---------------------------------------------------------------
-- Auxiliares dos poderes de clã
---------------------------------------------------------------

local GOLD = Color3.fromRGB(255, 205, 80)
local FIRE = Color3.fromRGB(255, 120, 30)
local FIRE_LIGHT = Color3.fromRGB(255, 220, 120)
local LIGHTNING = Color3.fromRGB(150, 210, 255)
local WHITE = Color3.fromRGB(240, 245, 255)
local WOOD = Color3.fromRGB(120, 80, 45)
local LEAF = Color3.fromRGB(90, 170, 80)
local CHAKRA_BLUE = Color3.fromRGB(120, 190, 255)
local ASH = Color3.fromRGB(90, 85, 85)

-- bate em cada inimigo só uma vez por uso
local function hitOnce(set, e, amount, from, force)
	if set[e.model] then
		return
	end
	set[e.model] = true
	hit(e, amount, from, force)
end

-- inimigos numa faixa reta (origem, direção já normalizada, comprimento, largura)
local function inLine(origin, dir, len, width)
	local out = {}
	for _, e in ipairs(getEnemies()) do
		local rel = (e.root.Position - origin) * Vector3.new(1, 0, 1)
		local along = rel:Dot(dir)
		if along >= -2 and along <= len + e.raio then
			local side = (rel - dir * along).Magnitude
			if side <= width / 2 + e.raio and math.abs(e.root.Position.Y - origin.Y) < 12 then
				table.insert(out, e)
			end
		end
	end
	return out
end

-- inimigos num cone na frente (alcance, metade do ângulo em graus)
local function inCone(origin, look, range, halfDeg)
	local out = {}
	local minDot = math.cos(math.rad(halfDeg))
	for _, e in ipairs(inRadius(origin, range)) do
		local d = (e.root.Position - origin) * Vector3.new(1, 0, 1)
		if d.Magnitude < 2 or d.Unit:Dot(look) >= minDot then
			table.insert(out, e)
		end
	end
	return out
end

-- segura o inimigo parado por alguns segundos
local function prender(e, dur)
	if e.raio > 2 then
		dur *= 0.4 -- o boss se solta mais rápido
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

-- buff de dano/velocidade com brilho no personagem
local function buff(plr, char, dano, vel, dur, color)
	local token = (plr:GetAttribute("BuffToken") or 0) + 1
	plr:SetAttribute("BuffToken", token)
	plr:SetAttribute("BuffDano", dano)
	plr:SetAttribute("BuffVelocidade", vel)
	local old = char:FindFirstChild("BuffBrilho")
	if old then old:Destroy() end
	local hl = Instance.new("Highlight")
	hl.Name = "BuffBrilho"
	hl.FillColor = color
	hl.FillTransparency = 0.75
	hl.OutlineColor = color
	hl.OutlineTransparency = 0.2
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	task.delay(dur, function()
		if plr:GetAttribute("BuffToken") == token then
			plr:SetAttribute("BuffDano", 0)
			plr:SetAttribute("BuffVelocidade", 0)
		end
		if hl.Parent then hl:Destroy() end
	end)
end

-- anel achatado no chão que cresce
local function ring(pos, diameter, color, time)
	local r = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 1, 1), color = color, trans = 0.2,
		cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(r, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, diameter, diameter), Transparency = 1 }):Play()
	Debris:AddItem(r, time + 0.1)
	emitir(pos + Vector3.new(0, 0.6, 0), Color3.fromRGB(150, 140, 125), diameter * 0.7, { tex = "fumaca", vel = diameter * 0.6, tam = math.clamp(diameter * 0.07, 0.6, 2.5), vida = 0.7, luz = 0, cresce = true, drag = 4, spread = 80 })
end

local function chao(root)
	return root.Position - Vector3.new(0, 2.6, 0)
end

-- durante "dur" segundos, bate em quem encostar no jogador (para poderes com investida)
local function contatoDurante(root, dur, raio, onHit)
	local set = {}
	local t0 = os.clock()
	while os.clock() - t0 < dur and root.Parent do
		for _, e in ipairs(inRadius(root.Position, raio)) do
			if not set[e.model] then
				set[e.model] = true
				onHit(e)
			end
		end
		task.wait()
	end
end

local function cao(plr)
	local pasta = workspace:FindFirstChild("Companheiros")
	return pasta and pasta:FindFirstChild("Cao_" .. plr.Name)
end

---------------------------------------------------------------
-- Poderes (função por id; recebem plr, char, root, dmg)
---------------------------------------------------------------

-- efeito ao soltar qualquer jutsu: selo de chakra girando no chão e brilho nas mãos
conjurar = function(char, root, cor)
	local base = root.Position - Vector3.new(0, 2.9, 0)
	local selo = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.15, 3, 3), color = cor, trans = 0.25,
		cf = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90)) })
	local miolo = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.18, 2.2, 2.2), color = Color3.new(0.08, 0.08, 0.1), trans = 0.3,
		cf = CFrame.new(base + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(selo, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.new(0.15, 9, 9), Transparency = 1 }):Play()
	TweenService:Create(miolo, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.new(0.18, 7.6, 7.6), Transparency = 1 }):Play()
	Debris:AddItem(selo, 0.5)
	Debris:AddItem(miolo, 0.5)
	for _, nome in ipairs({ "RightHand", "LeftHand", "Right Arm", "Left Arm" }) do
		local m = char:FindFirstChild(nome)
		if m then
			emitir(m.Position, cor, 7, { vel = 6, tam = 0.45, vida = 0.35, cor2 = Color3.new(1, 1, 1) })
		end
	end
	emitir(base + Vector3.new(0, 0.3, 0), cor, 14, { vel = 9, tam = 0.4, vida = 0.5, acel = Vector3.new(0, 18, 0), spread = 25 })
	clarao(root.Position, cor, 14, 3)
end

local P = {}

-- UZU ---------------------------------------------------------
P.uzu_correntes = function(plr, char, root, dmg)
	local look = flatLook(root)
	local from = handPos(char, root)
	local alvos = inLine(root.Position, look, 32, 7)
	local pontos = {}
	if #alvos == 0 then
		for k = -1, 1 do
			table.insert(pontos, root.Position + (CFrame.Angles(0, math.rad(k * 12), 0) * look) * 28)
		end
	end
	local set = {}
	for _, e in ipairs(alvos) do
		table.insert(pontos, e.root.Position)
		hitOnce(set, e, dmg * 2, nil, 0)
		prender(e, 2.5)
	end
	for _, pt in ipairs(pontos) do
		local len = (pt - from).Magnitude
		local c = fx({ size = Vector3.new(0.35, 0.35, 0.1), color = GOLD, mat = Enum.Material.Neon, cf = CFrame.lookAt(from, pt) })
		light(c, GOLD, 8, 2)
		TweenService:Create(c, TweenInfo.new(0.18), { Size = Vector3.new(0.35, 0.35, len), CFrame = CFrame.lookAt(from, pt) * CFrame.new(0, 0, -len / 2) }):Play()
		task.delay(1.6, function() fadeOut(c, 0.4) end)
		burst(pt, 4, GOLD, 0.3, 0.3)
	end
end

P.uzu_selamento = function(plr, char, root, dmg)
	local c = chao(root)
	local selo = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 4, 4), color = GOLD, trans = 0.35,
		cf = CFrame.new(c) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(selo, TweenInfo.new(0.45, Enum.EasingStyle.Quad), { Size = Vector3.new(0.2, 34, 34) }):Play()
	task.wait(0.5)
	ring(c, 40, Color3.fromRGB(255, 240, 180), 0.5)
	burst(root.Position, 22, GOLD, 0.45, 0.4)
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 17)) do
		hitOnce(set, e, dmg * 3, root.Position, 55)
	end
	fadeOut(selo, 0.4)
end

P.uzu_espiral = function(plr, char, root, dmg)
	local orb = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 0.6, color = CHAKRA_BLUE, trans = 0.15 })
	local core = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 0.4, color = WHITE })
	light(orb, CHAKRA_BLUE, 22, 4)
	local t0 = os.clock()
	local set = {}
	while os.clock() - t0 < 1.35 and root.Parent do
		local k = math.min((os.clock() - t0) / 0.5, 1)
		local pos = handPos(char, root) + root.CFrame.LookVector * (1 + k * 1.5)
		orb.Size = Vector3.one * (0.6 + k * 4.4)
		core.Size = orb.Size * 0.6
		orb.CFrame = CFrame.new(pos) * CFrame.Angles(os.clock() * 9, os.clock() * 7, 0)
		core.CFrame = CFrame.new(pos)
		-- encostou num inimigo durante a corrida: explode já
		if os.clock() - t0 > 0.45 and #inRadius(pos, 3) > 0 then
			break
		end
		task.wait()
	end
	local pos = orb.Position
	orb:Destroy()
	core:Destroy()
	task.spawn(vortex, pos, 9, 0.45, true)
	ring(pos - Vector3.new(0, 2, 0), 36, CHAKRA_BLUE, 0.5)
	for _, e in ipairs(inRadius(pos, 13)) do
		hitOnce(set, e, dmg * 7, pos, 75)
	end
end

-- UCHIWA ------------------------------------------------------
P.uchiwa_fogo = function(plr, char, root, dmg)
	local look = flatLook(root)
	local start = handPos(char, root) + look * 2
	local ball = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 4, color = FIRE, trans = 0.1 })
	local inner = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2.6, color = FIRE_LIGHT })
	light(ball, FIRE, 20, 4)
	local fire = Instance.new("Fire")
	fire.Size = 8
	fire.Heat = 12
	fire.Parent = ball
	projectile({ start = start, dir = look, speed = 75, range = 60, radius = 4, parts = { ball, inner },
		onEnd = function(pos)
			burst(pos, 16, FIRE, 0.45, 0.15)
			burst(pos, 10, FIRE_LIGHT, 0.3, 0.2)
			local set = {}
			for _, e in ipairs(inRadius(pos, 10)) do
				hitOnce(set, e, dmg * 3.5, pos, 40)
			end
		end })
end

P.uchiwa_sharingan = function(plr, char, root, dmg)
	local head = char:FindFirstChild("Head")
	if head then
		burst(head.Position, 5, Color3.fromRGB(220, 20, 30), 0.35, 0.3)
	end
	buff(plr, char, 0.35, 4, 8, Color3.fromRGB(220, 30, 40))
end

P.uchiwa_chidori = function(plr, char, root, dmg)
	local t0 = os.clock()
	while os.clock() - t0 < 0.35 and root.Parent do
		local h = handPos(char, root)
		zap(h, h + Vector3.new(math.random() * 4 - 2, math.random() * 3 - 1, math.random() * 4 - 2), LIGHTNING, 0.18, 0.8, 0.12)
		task.wait(0.04)
	end
	contatoDurante(root, 0.35, 6, function(e)
		hit(e, dmg * 6, root.Position, 65)
		zap(handPos(char, root), e.root.Position, LIGHTNING, 0.3, 1.2, 0.3)
		burst(e.root.Position, 8, LIGHTNING, 0.3, 0.3)
	end)
end

-- MOKUTON -----------------------------------------------------
P.moku_estacas = function(plr, char, root, dmg)
	local look = flatLook(root)
	local base = chao(root)
	for i = 1, 9 do
		local pos = base + look * (2 + i * 3)
		local spike = fx({ size = Vector3.new(1.4, 0.2, 1.4), color = WOOD, mat = Enum.Material.Wood,
			cf = CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-15, 15)), math.rad(math.random(0, 90)), 0) })
		TweenService:Create(spike, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = Vector3.new(1.4, 6, 1.4), CFrame = spike.CFrame * CFrame.new(0, 3, 0) }):Play()
		task.delay(1.4, function() fadeOut(spike, 0.4) end)
		task.wait(0.03)
	end
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 30, 6)) do
		hitOnce(set, e, dmg * 2.8, nil, 0)
		e.root.AssemblyLinearVelocity = Vector3.new(0, 45, 0)
	end
end

P.moku_muro = function(plr, char, root, dmg)
	local dome = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2, color = WOOD, mat = Enum.Material.Wood, trans = 0.35, cf = CFrame.new(root.Position) })
	TweenService:Create(dome, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = Vector3.one * 16 }):Play()
	local ff = Instance.new("ForceField")
	ff.Visible = false
	ff.Parent = char
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 12)) do
		hitOnce(set, e, dmg * 1.5, root.Position, 85)
	end
	task.wait(3)
	if ff.Parent then ff:Destroy() end
	fadeOut(dome, 0.4)
end

P.moku_floresta = function(plr, char, root, dmg)
	local center = root.Position
	local base = chao(root)
	local trees = {}
	for i = 1, 10 do
		local a = (i / 10) * math.pi * 2 + math.random() * 0.4
		local r = 6 + math.random() * 12
		local pos = base + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local trunk = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.5, 2, 2), color = WOOD, mat = Enum.Material.Wood,
			cf = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)) })
		local top = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 0.5, color = LEAF, mat = Enum.Material.Grass, cf = CFrame.new(pos) })
		TweenService:Create(trunk, TweenInfo.new(0.5, Enum.EasingStyle.Back), { Size = Vector3.new(12, 2.2, 2.2), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)) * CFrame.Angles(0, 0, math.rad(90)) }):Play()
		TweenService:Create(top, TweenInfo.new(0.6, Enum.EasingStyle.Back), { Size = Vector3.one * 8, CFrame = CFrame.new(pos + Vector3.new(0, 12, 0)) }):Play()
		table.insert(trees, trunk)
		table.insert(trees, top)
	end
	for _, e in ipairs(inRadius(center, 19)) do
		prender(e, 3.2)
	end
	for _ = 1, 5 do
		task.wait(0.55)
		for _, e in ipairs(inRadius(center, 19)) do
			hit(e, dmg * 1.3, nil, 0)
		end
	end
	for _, t in ipairs(trees) do
		fadeOut(t, 0.6)
	end
end

-- Combo que conecta: o jogador gruda no inimigo, que fica preso e sem revidar até o último golpe.
-- golpes rápidos (dmgCada) com faíscas e, no fim, um golpe forte (dmgFinal) que joga o inimigo longe.
local function combo(root, e, golpes, intervalo, dmgCada, dmgFinal, cor, forca)
	local dur = golpes * intervalo + 0.35
	prender(e, dur)
	if e.raio <= 2 then e.model:SetAttribute("Atordoado", os.clock() + dur) end
	for i = 1, golpes do
		if e.hum.Health <= 0 or not e.root.Parent or not root.Parent then return end
		local alvo = e.root.Position
		local d = (alvo - root.Position) * Vector3.new(1, 0, 1)
		if d.Magnitude > 0.5 and not root.Anchored then
			-- fica de frente e colado no inimigo
			local perto = alvo - d.Unit * (3 + e.raio)
			root.CFrame = CFrame.lookAt(Vector3.new(perto.X, root.Position.Y, perto.Z), Vector3.new(alvo.X, root.Position.Y, alvo.Z))
		end
		if e.raio <= 2 then e.root.AssemblyLinearVelocity = Vector3.zero end
		local p = alvo + Vector3.new(math.random() * 2 - 1, math.random() * 2.4 - 0.6, math.random() * 2 - 1)
		burst(p, 2.2, cor, 0.12, 0.15)
		emitir(p, cor, 6, { vel = 14, vida = 0.25 })
		hit(e, dmgCada, nil, 0)
		task.wait(intervalo)
	end
	if e.hum.Health > 0 and e.root.Parent then
		local alvo = e.root.Position
		clarao(alvo, cor, 16, 4)
		ring(alvo - Vector3.new(0, 2, 0), 14, cor, 0.3)
		burst(alvo, 7, cor, 0.25, 0.3)
		tremor(alvo, 0.5)
		hit(e, dmgFinal, root.Position, forca)
	end
end

-- BYAKUGAN ----------------------------------------------------
P.byaku_punho = function(plr, char, root, dmg)
	task.wait(0.12)
	local look = flatLook(root)
	-- com um inimigo na frente, as palmas conectam nele (8 toques + empurrão final)
	local alvo = nearestEnemy(root.Position, look, 11)
	if alvo then
		combo(root, alvo, 8, 0.07, dmg * 0.4, dmg * 0.9, CHAKRA_BLUE, 55)
		return
	end
	for _ = 1, 6 do
		local alvos = inCone(root.Position, look, 9, 50)
		local pos = root.Position + look * 3 + Vector3.new(math.random() * 2 - 1, math.random() * 2, math.random() * 2 - 1)
		burst(pos, 2.5, CHAKRA_BLUE, 0.15, 0.2)
		for _, e in ipairs(alvos) do
			hit(e, dmg * 0.5, root.Position, 6)
		end
		task.wait(0.08)
	end
end

P.byaku_palma = function(plr, char, root, dmg)
	local look = flatLook(root)
	local start = root.Position + look * 2
	local wave = fx({ shape = Enum.PartType.Ball, size = Vector3.new(3, 3, 1), color = WHITE, trans = 0.55 })
	projectile({ start = start, dir = look, speed = 120, range = 36, radius = 0.1, parts = { wave },
		onEnd = function(pos) burst(pos, 8, WHITE, 0.3, 0.5) end })
	TweenService:Create(wave, TweenInfo.new(0.3), { Size = Vector3.new(9, 9, 2) }):Play()
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 36, 7)) do
		hitOnce(set, e, dmg * 2.5, root.Position, 115)
	end
end

P.byaku_rotacao = function(plr, char, root, dmg)
	local center = root.Position
	local dome = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2, color = CHAKRA_BLUE, trans = 0.45, cf = CFrame.new(center) })
	light(dome, CHAKRA_BLUE, 30, 3)
	TweenService:Create(dome, TweenInfo.new(0.55, Enum.EasingStyle.Quad), { Size = Vector3.one * 26 }):Play()
	for i = 1, 3 do
		task.delay(i * 0.12, function() ring(chao(root), 30, WHITE, 0.4) end)
	end
	task.wait(0.4)
	local set = {}
	for _, e in ipairs(inRadius(center, 14)) do
		hitOnce(set, e, dmg * 6, center, 95)
	end
	fadeOut(dome, 0.35)
end

-- LEE ---------------------------------------------------------
P.lee_furacao = function(plr, char, root, dmg)
	ring(chao(root) + Vector3.new(0, 1.5, 0), 20, LEAF, 0.35)
	burst(root.Position, 12, Color3.fromRGB(200, 255, 200), 0.3, 0.5)
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 9)) do
		hitOnce(set, e, dmg * 2.5, root.Position, 45)
	end
end

P.lee_lotus = function(plr, char, root, dmg)
	task.wait(0.9) -- o cliente corre até o inimigo
	local e = nearestEnemy(root.Position, flatLook(root), 9)
	if not e then
		burst(root.Position + flatLook(root) * 3, 5, LEAF, 0.3, 0.4)
		return
	end
	hit(e, dmg * 1.5, nil, 0)
	if e.raio <= 2 then
		e.root.AssemblyLinearVelocity = Vector3.new(0, 85, 0)
	end
	burst(e.root.Position, 6, LEAF, 0.3, 0.3)
	task.wait(0.65)
	if e.hum.Health > 0 and e.root.Parent then
		if e.raio <= 2 then
			e.root.AssemblyLinearVelocity = Vector3.new(0, -140, 0)
			task.wait(0.15)
		end
		hit(e, dmg * 3, nil, 0)
		local p = e.root.Position - Vector3.new(0, 2.5, 0)
		ring(p, 18, Color3.fromRGB(170, 140, 100), 0.4)
		burst(p, 9, Color3.fromRGB(200, 180, 140), 0.35, 0.35)
	end
end

P.lee_portoes = function(plr, char, root, dmg)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Health = math.max(1, hum.Health - hum.MaxHealth * 0.1)
	end
	burst(root.Position, 14, Color3.fromRGB(120, 255, 140), 0.4, 0.3)
	ring(chao(root), 24, Color3.fromRGB(120, 255, 140), 0.4)
	buff(plr, char, 0.7, 8, 9, Color3.fromRGB(110, 255, 130))
end

-- SHIROKIBA ---------------------------------------------------
P.shiro_presa = function(plr, char, root, dmg)
	local look = flatLook(root)
	local slash = fx({ size = Vector3.new(9, 0.3, 1.2), color = WHITE, trans = 0.1,
		cf = CFrame.lookAt(root.Position + look * 4, root.Position + look * 5) * CFrame.Angles(0, 0, math.rad(-20)) })
	light(slash, WHITE, 12, 3)
	TweenService:Create(slash, TweenInfo.new(0.2), { CFrame = slash.CFrame * CFrame.new(0, 0, -3), Size = Vector3.new(12, 0.2, 0.6) }):Play()
	fadeOut(slash, 0.25)
	-- com um inimigo na frente, três cortes conectam nele antes do golpe final
	local alvo = nearestEnemy(root.Position, look, 10)
	if alvo then
		combo(root, alvo, 3, 0.09, dmg * 0.5, dmg * 1.3, WHITE, 35)
		return
	end
	local set = {}
	for _, e in ipairs(inCone(root.Position, look, 10, 60)) do
		hitOnce(set, e, dmg * 2.6, root.Position, 30)
	end
end

P.shiro_passo = function(plr, char, root, dmg)
	local last = root.Position
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.3 and root.Parent do
			zap(last, root.Position, LIGHTNING, 0.25, 0.6, 0.25)
			last = root.Position
			task.wait(0.04)
		end
	end)
	contatoDurante(root, 0.3, 6, function(e)
		hit(e, dmg * 2.4, root.Position, 35)
		burst(e.root.Position, 5, LIGHTNING, 0.25, 0.3)
	end)
end

P.shiro_trovao = function(plr, char, root, dmg)
	local look = flatLook(root)
	local from = handPos(char, root)
	local to = from + look * 42
	local blade = fx({ size = Vector3.new(0.6, 0.6, 1), color = WHITE, cf = CFrame.lookAt(from, to) })
	light(blade, LIGHTNING, 16, 4)
	TweenService:Create(blade, TweenInfo.new(0.15), { Size = Vector3.new(0.8, 0.8, 42), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -21) }):Play()
	for _ = 1, 4 do
		zap(from, to, LIGHTNING, 0.25, 1.5, 0.3)
		task.wait(0.05)
	end
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 42, 6)) do
		hitOnce(set, e, dmg * 6.5, root.Position, 40)
		burst(e.root.Position, 6, LIGHTNING, 0.3, 0.3)
	end
	task.delay(0.3, function() fadeOut(blade, 0.3) end)
end

-- ENMA --------------------------------------------------------
local function bastao(comprimento, espessura)
	local s = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(comprimento, espessura, espessura), color = Color3.fromRGB(170, 40, 30), mat = Enum.Material.SmoothPlastic })
	local ponta1 = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(espessura * 0.6, espessura * 1.15, espessura * 1.15), color = GOLD, mat = Enum.Material.Metal })
	local ponta2 = ponta1:Clone()
	ponta2.Parent = workspace
	return s, ponta1, ponta2
end

P.enma_bastao = function(plr, char, root, dmg)
	local s, a, b = bastao(9, 0.5)
	local t0 = os.clock()
	while os.clock() - t0 < 0.3 and root.Parent do
		local k = (os.clock() - t0) / 0.3
		local ang = math.rad(-80 + k * 160)
		local cf = root.CFrame * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -4.5) * CFrame.Angles(0, math.rad(90), 0)
		s.CFrame = cf
		a.CFrame = cf * CFrame.new(4.5, 0, 0)
		b.CFrame = cf * CFrame.new(-4.5, 0, 0)
		task.wait()
	end
	local set = {}
	for _, e in ipairs(inCone(root.Position, flatLook(root), 10, 90)) do
		hitOnce(set, e, dmg * 2.6, root.Position, 40)
	end
	for _, p in ipairs({ s, a, b }) do fadeOut(p, 0.2) end
end

P.enma_cinzas = function(plr, char, root, dmg)
	local look = flatLook(root)
	local center = root.Position + look * 12
	local balls = {}
	for _ = 1, 9 do
		local off = Vector3.new(math.random() * 10 - 5, math.random() * 3, math.random() * 10 - 5)
		local b = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2, color = ASH, mat = Enum.Material.SmoothPlastic, trans = 0.35, cf = CFrame.new(root.Position + look * 2) })
		TweenService:Create(b, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.one * (5 + math.random() * 3), CFrame = CFrame.new(center + off) }):Play()
		table.insert(balls, b)
	end
	task.wait(0.4)
	for _ = 1, 6 do
		for _, e in ipairs(inRadius(center, 9)) do
			hit(e, dmg * 0.5, nil, 0)
		end
		burst(center + Vector3.new(math.random() * 6 - 3, 1, math.random() * 6 - 3), 3, FIRE, 0.25, 0.3)
		task.wait(0.5)
	end
	for _, b in ipairs(balls) do fadeOut(b, 0.6) end
end

P.enma_gigante = function(plr, char, root, dmg)
	local look = flatLook(root)
	local base = chao(root) + look * 2
	local s, a, b = bastao(38, 3)
	local pivo = CFrame.lookAt(base, base + look)
	local t0 = os.clock()
	while true do
		local k = math.min((os.clock() - t0) / 0.55, 1)
		k = k * k
		-- começa em pé e cai para a frente
		local up = pivo * CFrame.Angles(math.rad(90) * (1 - k), 0, 0)
		local stick = up * CFrame.new(0, 0, -19) * CFrame.Angles(0, math.rad(90), 0)
		s.CFrame = stick
		a.CFrame = stick * CFrame.new(19, 0, 0)
		b.CFrame = stick * CFrame.new(-19, 0, 0)
		if k >= 1 then break end
		task.wait()
	end
	local impact = base + look * 20
	ring(impact, 40, Color3.fromRGB(170, 140, 100), 0.5)
	burst(impact, 18, Color3.fromRGB(200, 180, 140), 0.45, 0.35)
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 40, 10)) do
		hitOnce(set, e, dmg * 7, impact, 60)
	end
	task.wait(0.4)
	for _, p in ipairs({ s, a, b }) do fadeOut(p, 0.4) end
end

-- INU ---------------------------------------------------------
P.inu_presa = function(plr, char, root, dmg)
	local drill = fx({ shape = Enum.PartType.Ball, size = Vector3.new(5, 5, 7), color = Color3.fromRGB(150, 140, 130), trans = 0.45 })
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < 0.5 and root.Parent do
			drill.CFrame = root.CFrame * CFrame.Angles(0, 0, os.clock() * 25)
			task.wait()
		end
		fadeOut(drill, 0.2)
	end)
	local vezes = {}
	local t1 = os.clock()
	while os.clock() - t1 < 0.5 and root.Parent do
		for _, e in ipairs(inRadius(root.Position, 7)) do
			local n = vezes[e.model] or 0
			if n < 2 and (n == 0 or os.clock() - t1 > 0.25) then
				vezes[e.model] = n + 1
				hit(e, dmg * 1.6, root.Position, 35)
			end
		end
		task.wait()
	end
end

P.inu_mordida = function(plr, char, root, dmg)
	local e = nearestEnemy(root.Position, flatLook(root), 32)
	local original = cao(plr)
	local salto
	if original then
		salto = original:Clone()
		salto.Name = "CaoSalto"
		salto.Parent = workspace
	else
		salto = Instance.new("Model")
		local b = fx({ shape = Enum.PartType.Ball, size = Vector3.new(1.4, 1.2, 2.2), color = Color3.fromRGB(236, 232, 222), mat = Enum.Material.SmoothPlastic })
		b.Parent = salto
		salto.PrimaryPart = b
		salto.Parent = workspace
	end
	local from = root.Position + root.CFrame.RightVector * 2
	local alvo = e and e.root.Position or (root.Position + flatLook(root) * 14)
	local t0 = os.clock()
	while true do
		local k = math.min((os.clock() - t0) / 0.35, 1)
		local pos = from:Lerp(alvo, k) + Vector3.new(0, math.sin(k * math.pi) * 5, 0)
		salto:PivotTo(CFrame.lookAt(pos, alvo + Vector3.new(0, 0.01, 0)))
		if k >= 1 then break end
		task.wait()
	end
	if e then
		hit(e, dmg * 3, from, 25)
		burst(alvo, 5, Color3.fromRGB(200, 40, 40), 0.25, 0.35)
	else
		burst(alvo, 4, Color3.fromRGB(236, 232, 222), 0.25, 0.4)
	end
	task.wait(0.25)
	salto:Destroy()
end

P.inu_fera = function(plr, char, root, dmg)
	burst(root.Position, 10, Color3.fromRGB(190, 120, 80), 0.35, 0.35)
	buff(plr, char, 0.3, 5, 10, Color3.fromRGB(200, 120, 70))
end

-- KEKKEI GENKAI (tecla V) -------------------------------------
local ICE = Color3.fromRGB(170, 225, 255)
local LAVA = Color3.fromRGB(255, 100, 30)

local function queimarPoder(e, porTick, ticks, cor)
	task.spawn(function()
		for _ = 1, ticks do
			task.wait(0.5)
			if e.hum.Health <= 0 or not e.root.Parent then break end
			e.hum:TakeDamage(porTick)
			numero(e, porTick, e.hum:GetAttribute("UltimoAtacante"), cor, "queima")
			burst(e.root.Position + Vector3.new(0, 1, 0), 3, cor, 0.25, 0.3)
		end
	end)
end

P.kg_gelo = function(plr, char, root, dmg)
	local look = flatLook(root)
	local base = chao(root)
	for i = 1, 8 do
		local pos = base + look * (2 + i * 3.2) + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
		local sp = fx({ size = Vector3.new(1.2, 0.2, 1.2), color = ICE, mat = Enum.Material.Glass, trans = 0.15,
			cf = CFrame.new(pos) * CFrame.Angles(math.rad(math.random(-20, 20)), math.rad(math.random(0, 90)), math.rad(math.random(-20, 20))) })
		TweenService:Create(sp, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Size = Vector3.new(1.2, 7, 1.2), CFrame = sp.CFrame * CFrame.new(0, 3.5, 0) }):Play()
		task.delay(1.8, function() fadeOut(sp, 0.4) end)
		task.wait(0.025)
	end
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 30, 7)) do
		hitOnce(set, e, dmg * 3, nil, 0)
		prender(e, 1.8)
		local hl = Instance.new("Highlight")
		hl.FillColor = ICE
		hl.FillTransparency = 0.4
		hl.OutlineTransparency = 1
		hl.Parent = e.model
		Debris:AddItem(hl, 1.8)
	end
end

P.kg_lava = function(plr, char, root, dmg)
	local look = flatLook(root)
	for k = -1, 1 do
		local dir = CFrame.Angles(0, math.rad(k * 14), 0) * look
		local glob = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2.4, color = LAVA, mat = Enum.Material.Neon })
		light(glob, LAVA, 12, 3)
		projectile({ start = handPos(char, root) + dir * 2, dir = dir, speed = 55, range = 40, radius = 3, parts = { glob },
			onEnd = function(pos)
				burst(pos, 10, LAVA, 0.4, 0.2)
				local poca = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 7, 7), color = LAVA, trans = 0.2,
					cf = CFrame.new(pos - Vector3.new(0, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
				task.delay(2, function() fadeOut(poca, 0.5) end)
				local set = {}
				for _, e in ipairs(inRadius(pos, 7)) do
					hitOnce(set, e, dmg * 1.6, pos, 20)
					queimarPoder(e, dmg * 0.4, 4, LAVA)
				end
			end })
	end
end

P.kg_fervura = function(plr, char, root, dmg)
	local center = root.Position
	local balls = {}
	for _ = 1, 10 do
		local off = Vector3.new(math.random() * 20 - 10, math.random() * 4, math.random() * 20 - 10)
		local b = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2, color = Color3.fromRGB(245, 245, 235), mat = Enum.Material.SmoothPlastic, trans = 0.5, cf = CFrame.new(center) })
		TweenService:Create(b, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { Size = Vector3.one * (6 + math.random() * 4), CFrame = CFrame.new(center + off) }):Play()
		table.insert(balls, b)
	end
	for _ = 1, 6 do
		task.wait(0.5)
		for _, e in ipairs(inRadius(center, 13)) do
			hit(e, dmg * 0.7, nil, 0)
		end
	end
	for _, b in ipairs(balls) do fadeOut(b, 0.6) end
end

P.kg_tempestade = function(plr, char, root, dmg)
	local alvos = inRadius(root.Position, 32)
	table.sort(alvos, function(a, b) return (a.root.Position - root.Position).Magnitude < (b.root.Position - root.Position).Magnitude end)
	local from = root.Position + Vector3.new(0, 8, 0)
	local orbe = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2.5, color = LIGHTNING, cf = CFrame.new(from) })
	light(orbe, LIGHTNING, 25, 4)
	task.wait(0.3)
	if #alvos == 0 then
		for k = 1, 4 do
			zap(from, root.Position + Vector3.new(math.cos(k) * 12, -2, math.sin(k) * 12), LIGHTNING, 0.35, 1.5, 0.3)
		end
	end
	for i = 1, math.min(6, #alvos) do
		local e = alvos[i]
		for _ = 1, 2 do zap(from, e.root.Position, LIGHTNING, 0.35, 1.5, 0.3) end
		hit(e, dmg * 3, from, 25)
		burst(e.root.Position, 6, LIGHTNING, 0.3, 0.3)
		task.wait(0.06)
	end
	fadeOut(orbe, 0.3)
end

P.kg_explosao = function(plr, char, root, dmg)
	local alvos = inRadius(root.Position, 26)
	local pontos = {}
	for i = 1, 4 do
		local e = alvos[i]
		table.insert(pontos, e and e.root.Position or (root.Position + Vector3.new(math.random(-12, 12), 0, math.random(-12, 12))))
	end
	for _, alvo in ipairs(pontos) do
		task.spawn(function()
			local bomba = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 1.3, color = Color3.fromRGB(245, 240, 225), mat = Enum.Material.SmoothPlastic })
			local from = handPos(char, root)
			local t0 = os.clock()
			while true do
				local k = math.min((os.clock() - t0) / 0.55, 1)
				bomba.CFrame = CFrame.new(from:Lerp(alvo, k) + Vector3.new(0, math.sin(k * math.pi) * 6, 0))
				if k >= 1 then break end
				task.wait()
			end
			bomba:Destroy()
			burst(alvo, 14, Color3.fromRGB(255, 220, 140), 0.4, 0.15)
			burst(alvo, 8, Color3.fromRGB(255, 255, 255), 0.25, 0.2)
			local set = {}
			for _, e in ipairs(inRadius(alvo, 7)) do
				hitOnce(set, e, dmg * 2.5, alvo, 45)
			end
		end)
		task.wait(0.08)
	end
end

P.kg_osso = function(plr, char, root, dmg)
	local base = chao(root)
	for i = 1, 14 do
		local a = (i / 14) * math.pi * 2
		local pos = base + Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
		local sp = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 1, 1), color = Color3.fromRGB(240, 235, 220), mat = Enum.Material.SmoothPlastic,
			cf = CFrame.lookAt(pos, pos + Vector3.new(math.cos(a), 2.5, math.sin(a))) * CFrame.Angles(0, math.rad(90), 0) })
		TweenService:Create(sp, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Size = Vector3.new(7, 1, 1), CFrame = sp.CFrame * CFrame.new(3.5, 0, 0) }):Play()
		task.delay(1.5, function() fadeOut(sp, 0.4) end)
	end
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 11)) do
		hitOnce(set, e, dmg * 3.5, root.Position, 30)
		e.root.AssemblyLinearVelocity += Vector3.new(0, 40, 0)
	end
end

P.kg_calor = function(plr, char, root, dmg)
	local orbs = {}
	for i = 1, 3 do
		local o = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2.2, color = Color3.fromRGB(255, 150, 60) })
		light(o, Color3.fromRGB(255, 150, 60), 12, 3)
		orbs[i] = o
	end
	local t0 = os.clock()
	local proximo = 0
	while os.clock() - t0 < 4 and root.Parent do
		local t = os.clock() - t0
		for i, o in ipairs(orbs) do
			local a = t * 5 + i * (math.pi * 2 / 3)
			o.CFrame = CFrame.new(root.Position + Vector3.new(math.cos(a) * 5, 0.5, math.sin(a) * 5))
		end
		if t >= proximo then
			proximo = t + 0.5
			for _, e in ipairs(inRadius(root.Position, 7)) do
				hit(e, dmg * 0.6, root.Position, 8)
			end
		end
		task.wait()
	end
	for _, o in ipairs(orbs) do fadeOut(o, 0.3) end
end

P.kg_poeira = function(plr, char, root, dmg)
	local center = root.Position + flatLook(root) * 18
	local cubo = fx({ size = Vector3.one * 0.5, color = Color3.fromRGB(255, 255, 255), trans = 0.55, cf = CFrame.new(center) })
	light(cubo, Color3.fromRGB(255, 255, 255), 30, 4)
	local linha = fx({ size = Vector3.new(0.2, 0.2, 18), color = Color3.fromRGB(255, 255, 255), cf = CFrame.lookAt((root.Position + center) / 2, center) })
	fadeOut(linha, 0.4)
	TweenService:Create(cubo, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Size = Vector3.one * 16 }):Play()
	task.wait(0.55)
	local set = {}
	for _, e in ipairs(inRadius(center, 9)) do
		hitOnce(set, e, dmg * 8, nil, 0)
	end
	burst(center, 20, Color3.fromRGB(255, 255, 255), 0.35, 0.3)
	TweenService:Create(cubo, TweenInfo.new(0.25), { Size = Vector3.one * 0.5, Transparency = 1 }):Play()
	Debris:AddItem(cubo, 0.3)
end

-- NATUREZAS DE CHAKRA (teclas G, H, J e K) ---------------------------
-- Aprendidos por missao com o mestre de cada natureza (NatureData / MissionData N1_ e N2_).
local FIRE = Color3.fromRGB(255, 120, 40)
local WIND = Color3.fromRGB(190, 245, 215)
local STONE = Color3.fromRGB(125, 105, 85)
local WATER = Color3.fromRGB(70, 150, 255)

P.nat_fogo1 = function(plr, char, root, dmg)
	local look = flatLook(root)
	for k = -1, 1 do
		local dir = CFrame.Angles(0, math.rad(k * 10), 0) * look
		local bola = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 1.8, color = FIRE })
		light(bola, FIRE, 10, 3)
		projectile({ start = handPos(char, root) + dir * 2, dir = dir, speed = 70, range = 45, radius = 2.5, parts = { bola },
			onEnd = function(pos)
				burst(pos, 8, FIRE, 0.35, 0.2)
				local set = {}
				for _, e in ipairs(inRadius(pos, 5)) do
					hitOnce(set, e, dmg * 1.3, pos, 15)
					queimarPoder(e, dmg * 0.25, 3, FIRE)
				end
			end })
		task.wait(0.08)
	end
end

P.nat_fogo2 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local origem = root.Position
	for i = 1, 11 do
		local pos = origem + look * (i * 3.2)
		local chama = fx({ shape = Enum.PartType.Ball, size = Vector3.one * (2 + i * 0.45), color = i % 2 == 0 and FIRE or Color3.fromRGB(255, 200, 80), trans = 0.15, cf = CFrame.new(pos) })
		if i % 3 == 0 then light(chama, FIRE, 14, 3) end
		fadeOut(chama, 0.55)
		task.wait(0.02)
	end
	local set = {}
	for _, e in ipairs(inLine(origem, look, 36, 9)) do
		hitOnce(set, e, dmg * 3.2, origem, 20)
		queimarPoder(e, dmg * 0.4, 4, FIRE)
	end
end

P.nat_vento1 = function(plr, char, root, dmg)
	local look = flatLook(root)
	for i = 1, 4 do
		ring(root.Position + look * (i * 4), 6 + i * 2, WIND, 0.35)
		local aro = fx({ size = Vector3.new(5 + i * 1.5, 5 + i * 1.5, 0.3), color = WIND, trans = 0.55, cf = CFrame.lookAt(root.Position + look * (i * 4), root.Position + look * 40) })
		fadeOut(aro, 0.3)
	end
	local set = {}
	for _, e in ipairs(inCone(root.Position, look, 18, 50)) do
		hitOnce(set, e, dmg * 2, root.Position, 60)
	end
end

P.nat_vento2 = function(plr, char, root, dmg)
	local centro = root.Position
	local laminas = {}
	for i = 1, 6 do
		laminas[i] = fx({ size = Vector3.new(0.25, 2.2, 7), color = WIND, trans = 0.25, cf = CFrame.new(centro) })
	end
	local t0 = os.clock()
	while os.clock() - t0 < 0.7 do
		local k = (os.clock() - t0) / 0.7
		for i, l in ipairs(laminas) do
			local ang = k * math.pi * 4 + i * math.pi / 3
			l.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, ang, 0) * CFrame.new(0, 0, -(4 + k * 9))
		end
		task.wait()
	end
	for _, l in ipairs(laminas) do fadeOut(l, 0.2) end
	ring(chao(root), 30, WIND, 0.4)
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 15)) do
		hitOnce(set, e, dmg * 3.4, root.Position, 30)
	end
end

-- Lightning Bolt: carrega na mão, um raio grosso cai do céu (no inimigo mais próximo ou à frente)
P.nat_raio1 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local e = nearestEnemy(root.Position, look, 45)
	local alvo = e and e.root.Position or (chao(root) + look * 20 + Vector3.new(0, 2.6, 0))
	local chaoAlvo = Vector3.new(alvo.X, chao(root).Y, alvo.Z)
	-- carga: faíscas na mão
	local mao = handPos(char, root)
	for _ = 1, 3 do
		zap(mao, mao + Vector3.new(math.random() * 3 - 1.5, math.random() * 3, math.random() * 3 - 1.5), LIGHTNING, 0.18, 0.6, 0.12)
		task.wait(0.04)
	end
	-- aviso no chão
	local marca = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.12, 2, 2), color = LIGHTNING, trans = 0.3,
		cf = CFrame.new(chaoAlvo + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	TweenService:Create(marca, TweenInfo.new(0.12), { Size = Vector3.new(0.12, 9, 9) }):Play()
	task.wait(0.12)
	marca:Destroy()
	-- o raio: tronco grosso + 3 ramos
	local topo = chaoAlvo + Vector3.new(math.random(-4, 4), 60, math.random(-4, 4))
	zap(topo, chaoAlvo, LIGHTNING, 1.5, 3, 0.35)
	for _ = 1, 3 do
		local meio = topo:Lerp(chaoAlvo, 0.35 + math.random() * 0.4)
		zap(meio, meio + Vector3.new(math.random(-9, 9), -math.random(6, 14), math.random(-9, 9)), LIGHTNING, 0.5, 1.5, 0.25)
	end
	zap(mao, alvo, WHITE, 0.35, 1.2, 0.18)
	burst(chaoAlvo + Vector3.new(0, 1, 0), 14, LIGHTNING, 0.35, 0.15)
	ring(chaoAlvo + Vector3.new(0, 0.2, 0), 22, WHITE, 0.4)
	clarao(chaoAlvo + Vector3.new(0, 6, 0), LIGHTNING, 60, 12)
	tremor(chaoAlvo, 0.9)
	-- marca queimada no chão
	local queimado = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.1, 7, 7), color = Color3.fromRGB(25, 25, 30), trans = 0.2,
		mat = Enum.Material.Slate, cf = CFrame.new(chaoAlvo + Vector3.new(0, 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	task.delay(2.5, function() fadeOut(queimado, 1) end)
	-- dano: alvo principal forte e respingo em volta
	local set = {}
	if e then
		hitOnce(set, e, dmg * 2.6, nil, 0)
		prender(e, 1.2)
	end
	for _, o in ipairs(inRadius(chaoAlvo, 7)) do
		hitOnce(set, o, dmg * 1.3, chaoAlvo, 25)
	end
end

-- Thunder Chain: corrente de raios que pula entre até 5 inimigos (sem alvo, um raio corre à frente)
P.nat_raio2 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local atual = nearestEnemy(root.Position, look, 40)
	local set = {}
	local de = handPos(char, root)
	clarao(de, LIGHTNING, 20, 6)
	if not atual then
		local fim = de + look * 32
		zap(de, fim, LIGHTNING, 0.9, 2, 0.3)
		zap(de, fim, WHITE, 0.4, 1.2, 0.2)
		burst(fim, 9, LIGHTNING, 0.3, 0.2)
		for _, e in ipairs(inLine(root.Position, look, 32, 6)) do
			hitOnce(set, e, dmg * 2.2, nil, 0)
			prender(e, 0.8)
		end
		return
	end
	for _ = 1, 5 do
		zap(de, atual.root.Position, LIGHTNING, 0.8, 1.8, 0.3)
		zap(de, atual.root.Position, WHITE, 0.3, 1, 0.2)
		burst(atual.root.Position, 7, LIGHTNING, 0.25, 0.3)
		hitOnce(set, atual, dmg * 2.2, nil, 0)
		prender(atual, 0.8)
		de = atual.root.Position
		local prox, dist = nil, 26
		for _, e in ipairs(inRadius(de, 26)) do
			local d = flat(e.root.Position, de)
			if not set[e.model] and d < dist then prox, dist = e, d end
		end
		if not prox then break end
		atual = prox
		task.wait(0.09)
	end
	tremor(de, 0.5)
end

P.nat_terra1 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local base = chao(root)
	for i = 1, 5 do
		local pos = base + look * (3 + i * 4)
		local pilar = fx({ size = Vector3.new(3, 0.3, 3), color = STONE, mat = Enum.Material.Slate, cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(i * 25), 0) })
		TweenService:Create(pilar, TweenInfo.new(0.14, Enum.EasingStyle.Back), { Size = Vector3.new(3, 8, 3), CFrame = pilar.CFrame * CFrame.new(0, 4, 0) }):Play()
		task.delay(1.4, function() fadeOut(pilar, 0.4) end)
		task.wait(0.05)
	end
	local set = {}
	for _, e in ipairs(inLine(root.Position, look, 25, 7)) do
		hitOnce(set, e, dmg * 2.4, e.root.Position - Vector3.new(0, 6, 0), 45)
	end
end

P.nat_terra2 = function(plr, char, root, dmg)
	local base = chao(root)
	ring(base, 34, STONE, 0.5)
	for i = 1, 10 do
		local ang = i / 10 * math.pi * 2
		local dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local racha = fx({ size = Vector3.new(1.4, 0.4, 14), color = Color3.fromRGB(60, 45, 35), mat = Enum.Material.Slate, cf = CFrame.lookAt(base + dir * 8, base + dir * 30) })
		local pedra = fx({ size = Vector3.new(2.2, 2.2, 2.2), color = STONE, mat = Enum.Material.Slate, cf = CFrame.new(base + dir * (6 + (i % 3) * 3)) * CFrame.Angles(i, i * 2, 0) })
		TweenService:Create(pedra, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = pedra.CFrame + Vector3.new(0, 4, 0) }):Play()
		task.delay(0.9, function() fadeOut(racha, 0.5) fadeOut(pedra, 0.4) end)
	end
	local set = {}
	for _, e in ipairs(inRadius(root.Position, 16)) do
		hitOnce(set, e, dmg * 3, nil, 0)
		prender(e, 2)
	end
end

P.nat_agua1 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local bola = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 2.6, color = WATER, mat = Enum.Material.Glass, trans = 0.2 })
	light(bola, WATER, 10, 2)
	projectile({ start = handPos(char, root) + look * 2, dir = look, speed = 95, range = 55, radius = 3, parts = { bola },
		onEnd = function(pos)
			burst(pos, 11, WATER, 0.35, 0.3)
			ring(pos - Vector3.new(0, 2, 0), 14, WATER, 0.4)
			local set = {}
			for _, e in ipairs(inRadius(pos, 6)) do
				hitOnce(set, e, dmg * 2.4, pos, 25)
			end
		end })
end

P.nat_agua2 = function(plr, char, root, dmg)
	local look = flatLook(root)
	local origem = root.Position
	local onda = fx({ size = Vector3.new(15, 7, 3), color = WATER, mat = Enum.Material.Glass, trans = 0.3, cf = CFrame.lookAt(origem + look * 3, origem + look * 40) })
	local crista = fx({ size = Vector3.new(15, 1.2, 4), color = Color3.fromRGB(225, 240, 255), trans = 0.2, cf = onda.CFrame * CFrame.new(0, 3.8, 0) })
	local set = {}
	local t0 = os.clock()
	while os.clock() - t0 < 0.75 do
		local d = 3 + (os.clock() - t0) / 0.75 * 36
		onda.CFrame = CFrame.lookAt(origem + look * d, origem + look * 80)
		crista.CFrame = onda.CFrame * CFrame.new(0, 3.8, 0)
		for _, e in ipairs(inRadius(origem + look * d, 8)) do
			hitOnce(set, e, dmg * 3.2, origem + look * (d - 6), 50)
		end
		task.wait()
	end
	fadeOut(onda, 0.3)
	fadeOut(crista, 0.3)
end

---------------------------------------------------------------
-- Jutsus de natureza novos (opcoes B da etapa 1 e 2, e todas as da etapa 3 e 4): efeitos genericos descritos
-- no campo Ef de cada jutsu em NatureData (tipos proj, area, cone, line, target e rain).
---------------------------------------------------------------
local function efeitoNat(cor, ef, e, set, dmg, from)
	hitOnce(set, e, dmg * ef.mult, from, ef.force or 0)
	if ef.burn then queimarPoder(e, dmg * ef.burn, ef.burnT or 3, cor) end
	if ef.stun then prender(e, ef.stun) end
end

-- coluna vertical que cai do ceu (usada por target e rain)
local function coluna(pos, cor, largura)
	local col = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(34, largura, largura), color = cor, trans = 0.2,
		cf = CFrame.new(pos + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
	fadeOut(col, 0.35)
end

local EF = {}

EF.proj = function(cor, ef, plr, char, root, dmg)
	local look = flatLook(root)
	local n = ef.n or 1
	for k = 1, n do
		local dir = CFrame.Angles(0, math.rad((k - (n + 1) / 2) * (ef.spread or 0)), 0) * look
		local bola = fx({ shape = Enum.PartType.Ball, size = Vector3.one * (ef.size or 2), color = cor })
		light(bola, cor, 10, 3)
		projectile({ start = handPos(char, root) + dir * 2, dir = dir, speed = ef.speed or 70, range = ef.range or 45, radius = ef.hit or 2.5, parts = { bola },
			onEnd = function(pos)
				burst(pos, (ef.blast or 5) * 1.6, cor, 0.35, 0.2)
				local set = {}
				for _, e in ipairs(inRadius(pos, ef.blast or 5)) do efeitoNat(cor, ef, e, set, dmg, pos) end
			end })
		if n > 1 then task.wait(ef.gap or 0.08) end
	end
end

EF.area = function(cor, ef, plr, char, root, dmg)
	local c = root.Position
	for i = 1, 3 do
		ring(chao(root), ef.r * 2 * (0.5 + i * 0.25), cor, 0.35 + i * 0.05)
		task.wait(0.08)
	end
	burst(c, ef.r * 1.2, cor, 0.45, 0.35)
	local set = {}
	for _, e in ipairs(inRadius(c, ef.r)) do efeitoNat(cor, ef, e, set, dmg, c) end
end

EF.cone = function(cor, ef, plr, char, root, dmg)
	local look = flatLook(root)
	for i = 1, 5 do
		burst(root.Position + look * (ef.range * i / 5), 4 + i * 2, cor, 0.35, 0.3)
		task.wait(0.04)
	end
	local set = {}
	for _, e in ipairs(inCone(root.Position, look, ef.range, ef.deg)) do efeitoNat(cor, ef, e, set, dmg, root.Position) end
end

EF.line = function(cor, ef, plr, char, root, dmg)
	local look = flatLook(root)
	local origem = root.Position
	for i = 1, math.floor(ef.len / 4) do
		local b = fx({ shape = Enum.PartType.Ball, size = Vector3.one * math.max(ef.width * 0.5, 3), color = cor, trans = 0.2, cf = CFrame.new(origem + look * (i * 4)) })
		fadeOut(b, 0.5)
		task.wait(0.02)
	end
	local set = {}
	for _, e in ipairs(inLine(origem, look, ef.len, ef.width)) do efeitoNat(cor, ef, e, set, dmg, origem) end
end

EF.target = function(cor, ef, plr, char, root, dmg)
	local alvos = inRadius(root.Position, ef.range)
	if #alvos == 0 then return false end -- sem alvo: o chakra volta
	table.sort(alvos, function(a, b) return flat(a.root.Position, root.Position) < flat(b.root.Position, root.Position) end)
	local set = {}
	for i = 1, math.min(ef.count, #alvos) do
		local e = alvos[i]
		coluna(e.root.Position, cor, 4)
		burst(e.root.Position, 8, cor, 0.35, 0.25)
		efeitoNat(cor, ef, e, set, dmg, root.Position)
		task.wait(0.1)
	end
end

EF.rain = function(cor, ef, plr, char, root, dmg)
	local centro = root.Position + flatLook(root) * ef.ahead
	ring(centro - Vector3.new(0, 2.6, 0), ef.r * 2, cor, ef.delay)
	for _ = 1, ef.n do
		local a, d = math.random() * math.pi * 2, math.sqrt(math.random()) * ef.r
		local pos = Vector3.new(centro.X + math.cos(a) * d, root.Position.Y, centro.Z + math.sin(a) * d)
		task.spawn(function()
			local marca = fx({ shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, ef.blast * 2, ef.blast * 2), color = cor, trans = 0.6,
				cf = CFrame.new(pos - Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
			fadeOut(marca, 0.6)
			task.wait(0.5)
			coluna(pos, cor, ef.blast * 0.5)
			burst(pos, ef.blast * 1.6, cor, 0.35, 0.2)
			local set = {}
			for _, e in ipairs(inRadius(pos, ef.blast)) do efeitoNat(cor, ef, e, set, dmg, pos) end
		end)
		task.wait(ef.delay / ef.n)
	end
	task.wait(0.6)
end

for _, t in pairs(NatureData.Tipos) do
	for _, j in ipairs(t.Jutsus) do
		local ef = j.Ef
		if ef and EF[ef.t] then
			P[j.Id] = function(plr, char, root, dmg)
				return EF[ef.t](ef.cor or t.Color, ef, plr, char, root, dmg)
			end
		end
	end
end

---------------------------------------------------------------
-- Estado dos poderes e chakra
---------------------------------------------------------------

local function maxChakra(plr)
	return math.max(plr:GetAttribute("ChakraMax") or 100, 1)
end

local function enviarEstado(plr)
	local data = PlayerData.Get(plr)
	if not data then return end
	local clan = ClanPowers.Sincronizar(data)
	local ok, motivo = {}, {}
	for slot = 1, 3 do
		local o, m = ClanPowers.Liberado(data, slot)
		ok[slot] = o
		motivo[slot] = m or ""
	end
	-- Kekkei Genkai: poder da tecla V (só depois da missão KekkeiData.MISSAO, da Lady Tsuna)
	local k = KekkeiData.DoSave(data)
	local feitas = type(data.Missoes) == "table" and type(data.Missoes.Feitas) == "table" and data.Missoes.Feitas or {}
	local kOk = k ~= nil and feitas[KekkeiData.MISSAO] == true
	plr:SetAttribute("PoderesEstado", HttpService:JSONEncode({ Cla = clan or "", Ok = ok, Motivo = motivo,
		K = k or "", KOk = kOk, KMotivo = (k and not kOk) and "Learn it in Lady Tsuna's mission 'Bloodline Awakening'" or "" }))
end

local atualizarEv = Instance.new("BindableEvent")
atualizarEv.Name = "AtualizarPoderes"
atualizarEv.Parent = ServerStorage
atualizarEv.Event:Connect(enviarEstado)

local function prepararJogador(plr)
	plr:SetAttribute("BuffDano", 0)
	plr:SetAttribute("BuffVelocidade", 0)
	for _ = 1, 60 do
		if PlayerData.Get(plr) then break end
		task.wait(0.25)
	end
	if not plr.Parent then return end
	plr:SetAttribute("Chakra", maxChakra(plr))
	enviarEstado(plr)
	plr:GetAttributeChangedSignal("Cla"):Connect(function() enviarEstado(plr) end)
	plr:GetAttributeChangedSignal("Rank"):Connect(function() enviarEstado(plr) end)
	local ls = plr:WaitForChild("leaderstats", 10)
	local lv = ls and ls:WaitForChild("Level", 10)
	if lv then
		lv.Changed:Connect(function() enviarEstado(plr) end)
	end
	plr.CharacterAdded:Connect(function()
		plr:SetAttribute("BuffDano", 0)
		plr:SetAttribute("BuffVelocidade", 0)
		plr:SetAttribute("Chakra", maxChakra(plr))
	end)
end
Players.PlayerAdded:Connect(prepararJogador)
for _, plr in ipairs(Players:GetPlayers()) do
	task.spawn(prepararJogador, plr)
end

-- chakra volta sozinho
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, plr in ipairs(Players:GetPlayers()) do
			local mx = maxChakra(plr)
			local c = plr:GetAttribute("Chakra")
			if c and c < mx then
				-- Fervura (Kekkei Genkai): chakra volta 50% mais rápido
				local mult = plr:GetAttribute("Kekkei") == "Fervura" and 1.5 or 1
				plr:SetAttribute("Chakra", math.min(mx, c + mx * ClanPowers.CHAKRA_REGEN * 0.5 * mult))
			elseif c and c > mx then
				plr:SetAttribute("Chakra", mx)
			end
		end
	end
end)

---------------------------------------------------------------
-- Entrada
---------------------------------------------------------------

useEvent.OnServerEvent:Connect(function(plr, slot)
	atacanteAtual = plr.UserId
	if typeof(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	if slot < 1 or slot > 4 + NatureData.SLOTS then
		return
	end
	local data = PlayerData.Get(plr)
	if not data then return end
	local info
	local afinidade = false
	if slot >= 5 then
		-- teclas G, H, J e K: jutsu de natureza equipado
		local n = NatureData.Garantir(data)
		local id = n.Equip[slot - 4]
		info = id and NatureData.Jutsu(id)
		if not info then
			feedback(plr, { msg = "No nature jutsu equipped. Learn one from a nature master.", slot = slot, cooldown = 0 })
			return
		end
		afinidade = n.Afinidade == info.Natureza
	elseif slot == 4 then
		-- tecla V: poder da Kekkei Genkai
		local k = KekkeiData.DoSave(data)
		if not k then return end
		info = KekkeiData.Tipos[k].Poder
		local feitas = type(data.Missoes) == "table" and type(data.Missoes.Feitas) == "table" and data.Missoes.Feitas or {}
		if not feitas[KekkeiData.MISSAO] then
			feedback(plr, { msg = "You have not learned this jutsu yet. Lady Tsuna can awaken your bloodline.", slot = slot, cooldown = 0 })
			return
		end
	else
		local clan = ClanPowers.Sincronizar(data)
		local c = clan and ClanPowers.Clans[clan]
		if not c then
			feedback(plr, { msg = "Spin the roulette to get a clan first.", slot = slot, cooldown = 0 })
			return
		end
		info = c.Powers[slot]
		local ok, motivo = ClanPowers.Liberado(data, slot)
		if not ok then
			feedback(plr, { msg = info.Name .. " is locked. " .. (motivo or ""), slot = slot, cooldown = 0 })
			return
		end
	end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 or not P[info.Id] then
		return
	end
	cooldowns[plr] = cooldowns[plr] or {}
	local now = os.clock()
	if (cooldowns[plr][info.Id] or 0) > now + 0.15 then
		return
	end
	local chakra = plr:GetAttribute("Chakra") or 0
	local custo = afinidade and math.floor(info.Chakra * NatureData.AFIN_CHAKRA + 0.5) or info.Chakra
	if chakra < custo then
		feedback(plr, { msg = "Not enough chakra.", slot = slot, cooldown = 0 })
		return
	end
	plr:SetAttribute("Chakra", chakra - custo)
	cooldowns[plr][info.Id] = now + info.Cooldown
	feedback(plr, { slot = slot, cooldown = info.Cooldown })
	local dmg = PlayerData.GetCombatStats(plr).PowerDamage * (1 + (plr:GetAttribute("BuffDano") or 0))
	if afinidade then dmg *= NatureData.AFIN_DANO end
	-- cor do jutsu para o efeito de conjurar
	local cor
	if info.Natureza then
		cor = NatureData.Tipos[info.Natureza].Color
	elseif slot == 4 then
		local k = KekkeiData.DoSave(data)
		cor = k and KekkeiData.Tipos[k].Color
	else
		local c = ClanPowers.Clans[info.Clan or ""]
		cor = c and c.Color
	end
	corJutsu[plr.UserId] = cor or CHAKRA_BLUE
	conjurar(char, root, cor or CHAKRA_BLUE)
	task.spawn(function()
		local okRun, res = pcall(P[info.Id], plr, char, root, dmg)
		if not okRun then
			warn("[AbilityServer] Erro em " .. info.Name .. ": " .. tostring(res))
		elseif res == false then
			cooldowns[plr][info.Id] = 0
			plr:SetAttribute("Chakra", (plr:GetAttribute("Chakra") or 0) + custo)
			feedback(plr, { slot = slot, cooldown = 0 })
		end
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	cooldowns[plr] = nil
	corJutsu[plr.UserId] = nil
end)
