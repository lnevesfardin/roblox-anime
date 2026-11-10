-- Script: ServerScriptService > AbilityServer
-- Poderes dos personagens (Q, E, R). O cliente só avisa qual poder usou;
-- o servidor confere o personagem equipado, a recarga e calcula o dano.
-- Nomes e recargas ficam em ReplicatedStorage > CharacterData (campo Abilities).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local useEvent = Instance.new("RemoteEvent")
useEvent.Name = "UseAbility"
useEvent.Parent = ReplicatedStorage

local feedbackEvent = Instance.new("RemoteEvent")
feedbackEvent.Name = "AbilityFeedback"
feedbackEvent.Parent = ReplicatedStorage

local ANIM_IDLE = "rbxassetid://507766666"
local ANIM_RUN = "rbxassetid://507767714"

local cooldowns = {} -- [player] = { [idDoPersonagem .. slot] = horaLiberada }

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

local function burst(pos, diameter, color, time, trans)
	time = time or 0.4
	local b = fx({ shape = Enum.PartType.Ball, size = Vector3.one, color = color, cf = CFrame.new(pos), trans = trans or 0.2 })
	TweenService:Create(b, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * diameter, Transparency = 1 }):Play()
	Debris:AddItem(b, time + 0.1)
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

local function hit(e, amount, from, force)
	if e.hum.Health <= 0 then
		return
	end
	e.hum:TakeDamage(amount)
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
end

-- move peças ou um modelo em linha reta até bater num inimigo ou acabar o alcance
local function projectile(o)
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
			local part = fx({ size = Vector3.new(width, width, len), color = color, cf = CFrame.lookAt((p0 + p1) / 2, p1) })
			fadeOut(part, life or 0.25)
		end
	end
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

local function animate(hum)
	pcall(function()
		local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
		local idle, run = Instance.new("Animation"), Instance.new("Animation")
		idle.AnimationId = ANIM_IDLE
		run.AnimationId = ANIM_RUN
		local it, rt = animator:LoadAnimation(idle), animator:LoadAnimation(run)
		it.Looped, rt.Looped = true, true
		it:Play()
		hum.Running:Connect(function(speed)
			if speed > 1 and not rt.IsPlaying then
				it:Stop(0.1)
				rt:Play(0.1)
			elseif speed <= 1 and rt.IsPlaying then
				rt:Stop(0.1)
				it:Play(0.1)
			end
		end)
	end)
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
-- Poderes
---------------------------------------------------------------

local BLUE = Color3.fromRGB(70, 170, 255)
local BLUE_LIGHT = Color3.fromRGB(215, 240, 255)

local ABILITIES = {}

-- KARUTTO ----------------------------------------------------
ABILITIES.kenji_arashi = {
	-- Q: Spiral Orb — esfera de energia azul na mão, empurra e machuca na frente
	function(plr, char, root, dmg)
		local orb = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 1.2, color = BLUE, trans = 0.15 })
		local core = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 0.7, color = BLUE_LIGHT })
		light(orb, BLUE, 14, 3)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(140, 210, 255))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Lifetime = NumberRange.new(0.25, 0.45)
		pe.Rate = 70
		pe.Speed = NumberRange.new(2, 5)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = orb
		local t0 = os.clock()
		while os.clock() - t0 < 0.4 and root.Parent do
			local s = 1.2 + (os.clock() - t0) / 0.4 * 1.6
			local cf = CFrame.new(handPos(char, root) + root.CFrame.LookVector) * CFrame.Angles(0, os.clock() * 20, 0)
			orb.Size, orb.CFrame = Vector3.one * s, cf
			core.Size, core.CFrame = Vector3.one * s * 0.55, cf
			task.wait()
		end
		local function explode(pos)
			burst(pos, 15, BLUE, 0.45)
			burst(pos, 8, BLUE_LIGHT, 0.3)
			for _, e in ipairs(inRadius(pos, 7)) do
				hit(e, dmg * 3.5, pos, 60)
			end
		end
		local look = flatLook(root)
		local target = nearestEnemy(root.Position, look, 40)
		if not target then
			projectile({
				parts = { orb, core }, start = orb.Position, dir = look, speed = 80, range = 14, radius = 3.5,
				onEnd = explode,
			})
			return true
		end
		-- com alvo: o jogador corre (cliente) levando a bola na mão e acerta o inimigo de perto
		local pos = orb.Position
		local t1 = os.clock()
		while os.clock() - t1 < 1.1 and root.Parent do
			pos = handPos(char, root) + root.CFrame.LookVector * 1.6
			local cf = CFrame.new(pos) * CFrame.Angles(0, os.clock() * 20, 0)
			orb.CFrame, core.CFrame = cf, cf
			if target.hum.Health <= 0 or not target.model.Parent then
				break
			end
			if flat(target.root.Position, root.Position) <= 5 + target.raio then
				pos = target.root.Position
				break
			end
			task.wait()
		end
		orb:Destroy()
		core:Destroy()
		explode(pos)
		return true
	end,

	-- E: Leaf Clones — duas cópias do jogador que lutam por 8 segundos
	function(plr, char, root, dmg)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local okD, desc = pcall(function()
			return hum:GetAppliedDescription()
		end)
		for _, side in ipairs({ -1, 1 }) do
			task.spawn(function()
				local ok, clone = pcall(function()
					return Players:CreateHumanoidModelFromDescription(okD and desc or Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
				end)
				if not ok or not clone or not root.Parent then
					return
				end
				clone.Name = "Leaf Clone"
				local ch = clone:FindFirstChildOfClass("Humanoid")
				ch.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
				ch.WalkSpeed = 22
				local hl = Instance.new("Highlight")
				hl.FillColor = Color3.fromRGB(120, 220, 120)
				hl.FillTransparency = 0.8
				hl.OutlineColor = Color3.fromRGB(120, 255, 140)
				hl.Parent = clone
				local spawnCF = root.CFrame * CFrame.new(side * 4, 0, 0)
				clone:PivotTo(spawnCF)
				clone.Parent = workspace
				local cr = clone:FindFirstChild("HumanoidRootPart")
				pcall(function()
					cr:SetNetworkOwner(nil)
				end)
				animate(ch)
				smoke(spawnCF.Position, Color3.fromRGB(120, 200, 90))
				local t0, last = os.clock(), 0
				while os.clock() - t0 < 8 and clone.Parent and ch.Health > 0 do
					local target = nearestEnemy(cr.Position, cr.CFrame.LookVector, 70)
					if target then
						local d = flat(cr.Position, target.root.Position)
						if d <= 4.5 + target.raio then
							ch:MoveTo(cr.Position)
							if os.clock() - last >= 0.7 then
								last = os.clock()
								hit(target, dmg * 0.6, cr.Position, 15)
								burst(cr.Position + cr.CFrame.LookVector * 3, 3, Color3.fromRGB(150, 255, 160), 0.15)
							end
						else
							ch:MoveTo(target.root.Position)
						end
					elseif root.Parent then
						ch:MoveTo(root.Position + root.CFrame.RightVector * side * 4)
					end
					task.wait(0.2)
				end
				if clone.Parent then
					smoke(cr.Position, Color3.fromRGB(120, 200, 90))
					clone:Destroy()
				end
			end)
		end
		return true
	end,

	-- R: Storm Shuriken — shuriken gigante de energia que explode numa esfera
	function(plr, char, root, dmg)
		local m = Instance.new("Model")
		m.Name = "StormShuriken"
		local core = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 3.2, color = BLUE, parent = m })
		fx({ shape = Enum.PartType.Ball, size = Vector3.one * 1.8, color = BLUE_LIGHT, parent = m })
		for i = 0, 3 do
			fx({ size = Vector3.new(10, 0.25, 1.4), color = BLUE_LIGHT, trans = 0.2, cf = CFrame.Angles(0, math.rad(i * 45), 0), parent = m })
		end
		m.PrimaryPart = core
		light(core, BLUE, 24, 4)
		m.Parent = workspace
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 and root.Parent do
			local k = (os.clock() - t0) / 0.7
			m:ScaleTo(math.max(0.25 + k * 0.75, 0.25))
			m:PivotTo(CFrame.new(root.Position + Vector3.new(0, 5, 0) + root.CFrame.LookVector * 2) * CFrame.Angles(0, os.clock() * 18, 0))
			task.wait()
		end
		m:ScaleTo(1)
		projectile({
			model = m, start = root.Position + Vector3.new(0, 2, 0) + flatLook(root) * 4, dir = flatLook(root),
			speed = 55, range = 70, radius = 5, spin = 18,
			onEnd = function(pos)
				burst(pos, 30, BLUE_LIGHT, 0.6, 0.1)
				burst(pos, 22, BLUE, 0.8, 0.3)
				for _, e in ipairs(inRadius(pos, 14)) do
					hit(e, dmg * 4, pos, 30)
				end
				for _ = 1, 3 do
					task.wait(0.25)
					burst(pos, 20, BLUE, 0.25, 0.5)
					for _, e in ipairs(inRadius(pos, 14)) do
						hit(e, dmg, nil, 0)
					end
				end
			end,
		})
		return true
	end,
}

-- KAKUSE -----------------------------------------------------
local FIRE = Color3.fromRGB(255, 120, 30)

ABILITIES.ren_kuroba = {
	-- Q: Fireball — bola de fogo que explode ao bater
	function(plr, char, root, dmg)
		local look = flatLook(root)
		local ball = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 7, color = FIRE, cf = CFrame.new(handPos(char, root) + look * 4) })
		local inner = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 4, color = Color3.fromRGB(255, 220, 120), cf = ball.CFrame })
		local fire = Instance.new("Fire")
		fire.Size = 14
		fire.Heat = 6
		fire.Parent = ball
		light(ball, FIRE, 28, 3)
		projectile({
			parts = { ball, inner }, start = ball.Position, dir = look, speed = 60, range = 60, radius = 6,
			onEnd = function(pos)
				burst(pos, 30, FIRE, 0.6)
				burst(pos, 18, Color3.fromRGB(255, 230, 140), 0.4)
				for _, e in ipairs(inRadius(pos, 14)) do
					hit(e, dmg * 2.5, pos, 40)
				end
			end,
		})
		return true
	end,

	-- E: Black Flame — chama preta que queima o alvo por 5 segundos
	function(plr, char, root, dmg)
		local look = flatLook(root)
		local target = nearestEnemy(root.Position, look, 45)
		burst(handPos(char, root), 4, Color3.fromRGB(20, 0, 30), 0.3, 0.1)
		if not target then
			local pos = root.Position + look * 10
			burst(pos, 12, Color3.fromRGB(15, 10, 20), 0.5, 0.1)
			for _, e in ipairs(inRadius(pos, 6)) do
				hit(e, dmg * 1.5, pos, 20)
			end
			return true
		end
		local a, b = handPos(char, root), target.root.Position
		local beam = fx({ size = Vector3.new(0.5, 0.5, (b - a).Magnitude), color = Color3.fromRGB(20, 0, 30), cf = CFrame.lookAt((a + b) / 2, b) })
		fadeOut(beam, 0.3)
		local fire = Instance.new("Fire")
		fire.Color = Color3.fromRGB(10, 10, 12)
		fire.SecondaryColor = Color3.fromRGB(70, 0, 90)
		fire.Size = 12 + target.raio * 2
		fire.Heat = 14
		fire.Parent = target.root
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.fromRGB(10, 0, 15)
		hl.FillTransparency = 0.45
		hl.OutlineColor = Color3.fromRGB(110, 0, 140)
		hl.Parent = target.model
		for _ = 1, 10 do
			task.wait(0.5)
			if target.hum.Health <= 0 or not target.model.Parent then
				break
			end
			hit(target, dmg * 0.5, nil, 0)
		end
		fire:Destroy()
		hl:Destroy()
		return true
	end,

	-- R: Thunder Dragon — dragão de raios desce do céu sobre os inimigos
	function(plr, char, root, dmg)
		local look = flatLook(root)
		local target = nearestEnemy(root.Position, look, 80)
		local tpos = target and target.root.Position or (root.Position + look * 25)
		local right = look:Cross(Vector3.new(0, 1, 0))
		local cloud = fx({ shape = Enum.PartType.Ball, size = Vector3.new(44, 10, 44), color = Color3.fromRGB(45, 45, 55),
			mat = Enum.Material.SmoothPlastic, trans = 0.15, cf = CFrame.new(tpos + Vector3.new(0, 58, 0)) })
		light(cloud, Color3.fromRGB(200, 220, 255), 40, 2)
		task.wait(0.25)
		dragon({
			p0 = tpos + Vector3.new(0, 56, 0) + right * 22,
			p1 = tpos + Vector3.new(0, 40, 0) - right * 26,
			p2 = tpos + Vector3.new(0, 1, 0),
			count = 22, headSize = 4, duration = 0.3, lag = 0.011,
			colorA = Color3.fromRGB(255, 245, 160), colorB = Color3.fromRGB(150, 200, 255),
			onArrive = function(pos)
				local bolt = fx({ size = Vector3.new(1.4, 60, 1.4), color = Color3.fromRGB(240, 245, 255), cf = CFrame.new(pos + Vector3.new(0, 30, 0)) })
				fadeOut(bolt, 0.35)
				for _ = 1, 4 do
					zap(pos + Vector3.new(0, 55, 0), pos + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)), Color3.fromRGB(235, 240, 255), 0.9, 5, 0.3)
				end
				burst(pos, 36, Color3.fromRGB(255, 240, 150), 0.6, 0.1)
				burst(pos, 20, Color3.fromRGB(180, 210, 255), 0.4, 0.2)
				for _, e in ipairs(inRadius(pos, 17)) do
					hit(e, dmg * 7, pos, 45)
				end
			end,
		})
		fadeOut(cloud, 0.6)
		return true
	end,
}

-- TATASHI ----------------------------------------------------
local WATER = Color3.fromRGB(60, 150, 255)
local SPARK = Color3.fromRGB(190, 230, 255)

ABILITIES.hana_midori = {
	-- Q: Lightning Hand — relâmpago na mão + investida (o movimento é feito no cliente)
	function(plr, char, root, dmg)
		local spark = fx({ shape = Enum.PartType.Ball, size = Vector3.one * 1.4, color = SPARK })
		light(spark, SPARK, 16, 4)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(200, 235, 255))
		pe.LightEmission = 1
		pe.Size = NumberSequence.new(0.3, 0)
		pe.Lifetime = NumberRange.new(0.1, 0.25)
		pe.Rate = 120
		pe.Speed = NumberRange.new(8, 14)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Parent = spark
		-- zona de dano fixa à frente de onde o jogador estava ao ativar (não depende da investida no cliente)
		local look = flatLook(root)
		local startPos = root.Position
		local endPos = startPos + look * 22
		local t0 = os.clock()
		local lastZap = 0
		while os.clock() - t0 < 0.45 and root.Parent do
			local hp = handPos(char, root)
			spark.CFrame = CFrame.new(hp)
			if os.clock() - lastZap > 0.04 then
				lastZap = os.clock()
				for _ = 1, 2 do
					local off = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1).Unit * (4 + math.random() * 4)
					zap(hp, hp + off, SPARK, 0.25, 1.2, 0.15)
				end
			end
			task.wait()
		end
		spark:Destroy()
		local trail = fx({ size = Vector3.new(0.6, 0.6, 22), color = SPARK, cf = CFrame.lookAt((startPos + endPos) / 2, endPos) })
		fadeOut(trail, 0.3)
		burst(endPos, 10, SPARK, 0.3)
		zap(startPos, endPos, Color3.fromRGB(255, 255, 255), 0.9, 2, 0.35)
		for _ = 1, 8 do
			local f1, f2 = math.random(), math.random()
			local base1, base2 = startPos + look * (22 * f1), startPos + look * (22 * f2)
			local o = Vector3.new(math.random(-5, 5), math.random(-2, 4), math.random(-5, 5))
			zap(base1 + o, base2 - o, SPARK, 0.35, 2.5, 0.3)
		end
		local a, b = Vector2.new(startPos.X, startPos.Z), Vector2.new(endPos.X, endPos.Z)
		for _, e in ipairs(getEnemies()) do
			local p = Vector2.new(e.root.Position.X, e.root.Position.Z)
			local ab = b - a
			local t = ab.Magnitude > 0.01 and math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1) or 1
			local d = (p - (a + ab * t)).Magnitude
			if d <= 5 + e.raio and math.abs(e.root.Position.Y - endPos.Y) < 12 then
				hit(e, dmg * 3.5, startPos, 45)
				for _ = 1, 3 do
					zap(e.root.Position + Vector3.new(0, 6, 0), e.root.Position + Vector3.new(math.random(-3, 3), -1, math.random(-3, 3)), SPARK, 0.4, 1.5, 0.3)
				end
			end
		end
		return true
	end,

	-- E: Water Dragon — dragão de água que sai do chão e avança
	function(plr, char, root, dmg)
		local look = flatLook(root)
		local base = root.Position
		local hitSet = {}
		dragon({
			p0 = base + look * 3 - Vector3.new(0, 3, 0),
			p1 = base + look * 20 + Vector3.new(0, 6, 0),
			p2 = base + look * 70,
			count = 24, headSize = 4.2, duration = 1.2, trans = 0.15,
			colorA = WATER, colorB = Color3.fromRGB(200, 235, 255),
			onStep = function(head)
				for _, e in ipairs(inRadius(head, 9)) do
					if not hitSet[e.model] then
						hitSet[e.model] = true
						hit(e, dmg * 3, head, 55)
					end
				end
			end,
			onArrive = function(pos)
				burst(pos, 16, WATER, 0.5, 0.2)
			end,
		})
		return true
	end,

	-- R: Vanish — o inimigo some num portal e volta depois de 5 segundos com menos vida
	function(plr, char, root, dmg)
		local target = nearestEnemy(root.Position, flatLook(root), 45)
		if not target then
			feedback(plr, { msg = "No target nearby." })
			return false
		end
		task.spawn(function()
			local e = target
			local orig = e.root.CFrame
			local sky = orig.Position + Vector3.new(0, 20 + e.raio * 3, 0)
			local size = 12 + e.raio * 3
			-- esfera escura abre no ar e puxa o inimigo para cima
			e.root.Anchored = true
			vortex(sky, size, 0.9, false, function(k)
				if e.model.Parent then
					local y = orig.Position:Lerp(sky, k * k)
					e.model:PivotTo(CFrame.new(y) * CFrame.Angles(0, k * 14, 0))
				end
			end)
			if e.hum.Health <= 0 or not e.model.Parent then
				e.root.Anchored = false
				return
			end
			e.model:SetAttribute("Sumido", true)
			e.model:PivotTo(orig + Vector3.new(0, 3000, 0))
			task.wait(5)
			if not e.model.Parent then
				return
			end
			-- a esfera reabre no ar e o inimigo cai dela
			e.model:PivotTo(CFrame.new(sky))
			vortex(sky, size, 0.6, true)
			e.model:PivotTo(CFrame.new(sky) * (orig - orig.Position))
			e.root.Anchored = false
			e.root.AssemblyLinearVelocity = Vector3.zero
			e.model:SetAttribute("Sumido", nil)
			local extra = (e.raio <= 2) and e.hum.MaxHealth * 0.3 or 0
			hit(e, dmg * 6 + extra, nil, 0)
		end)
		return true
	end,
}

---------------------------------------------------------------
-- Entrada
---------------------------------------------------------------

useEvent.OnServerEvent:Connect(function(plr, slot)
	if typeof(slot) ~= "number" then
		return
	end
	slot = math.floor(slot)
	if slot < 1 or slot > 3 then
		return
	end
	local data = PlayerData.Get(plr)
	local id = data and data.Equipped
	local c = id and CharacterData.GetCharacter(id)
	if not c or not c.Abilities or not ABILITIES[id] then
		feedback(plr, { msg = "Equip a character first (Collection)." })
		return
	end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	cooldowns[plr] = cooldowns[plr] or {}
	local key = id .. slot
	local now = os.clock()
	if (cooldowns[plr][key] or 0) > now then
		return
	end
	local info = c.Abilities[slot]
	cooldowns[plr][key] = now + info.Cooldown
	feedback(plr, { slot = slot, cooldown = info.Cooldown })
	local dmg = PlayerData.GetCombatStats(plr).Damage
	task.spawn(function()
		local ok, res = pcall(ABILITIES[id][slot], plr, char, root, dmg)
		if not ok then
			warn("[AbilityServer] Erro em " .. info.Name .. ": " .. tostring(res))
		elseif res == false then
			cooldowns[plr][key] = 0
			feedback(plr, { slot = slot, cooldown = 0 })
		end
	end)
end)

Players.PlayerRemoving:Connect(function(plr)
	cooldowns[plr] = nil
end)
