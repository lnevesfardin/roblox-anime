-- LocalScript: StarterPlayerScripts > CombatClient
-- Clique / toque / F = combo. X (segurar) = soco carregado, Y = soco aéreo, C = soco com investida. Também mostra o aviso das ondas e a barra do boss.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local player = Players.LocalPlayer
local attackEvent = ReplicatedStorage:WaitForChild("Attack")
local statusEvent = ReplicatedStorage:WaitForChild("RunStatus")

local gui = Instance.new("ScreenGui")
gui.Name = "HudOnda"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local texto = Instance.new("TextLabel")
texto.Size = UDim2.fromOffset(700, 40)
texto.Position = UDim2.new(0.5, -350, 0, 14)
texto.BackgroundTransparency = 1
texto.Font = Enum.Font.GothamBlack
texto.TextSize = 26
texto.TextColor3 = Color3.new(1, 1, 1)
texto.TextStrokeTransparency = 0.3
texto.Text = ""
texto.Parent = gui

local bossFrame = Instance.new("Frame")
bossFrame.Size = UDim2.fromOffset(420, 24)
bossFrame.Position = UDim2.new(0.5, -210, 0, 62)
bossFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
bossFrame.Visible = false
bossFrame.Parent = gui
Instance.new("UICorner", bossFrame).CornerRadius = UDim.new(0, 6)

local bossBar = Instance.new("Frame")
bossBar.Size = UDim2.new(1, 0, 1, 0)
bossBar.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
bossBar.BorderSizePixel = 0
bossBar.Parent = bossFrame
Instance.new("UICorner", bossBar).CornerRadius = UDim.new(0, 6)

local bossLabel = Instance.new("TextLabel")
bossLabel.Size = UDim2.new(1, 0, 1, 0)
bossLabel.BackgroundTransparency = 1
bossLabel.Font = Enum.Font.GothamBold
bossLabel.TextSize = 14
bossLabel.TextColor3 = Color3.new(1, 1, 1)
bossLabel.Parent = bossFrame

statusEvent.OnClientEvent:Connect(function(p)
	if p.clear then
		texto.Text = ""
		bossFrame.Visible = false
		return
	end
	texto.Text = p.text or ""
	if p.boss then
		bossFrame.Visible = true
		bossBar.Size = UDim2.new(math.clamp(p.boss.hp / p.boss.max, 0, 1), 0, 1, 0)
		bossLabel.Text = ("%s   %d / %d"):format(p.boss.name, math.ceil(p.boss.hp), p.boss.max)
	else
		bossFrame.Visible = false
	end
end)

---------------------------------------------------------------
-- Golpes: combo, soco carregado (X), soco aéreo (Y) e soco com investida (C)
---------------------------------------------------------------

-- valores do estilo de luta equipado (Fase 5: ReplicatedStorage > FightStyles)
local FightStyles = require(ReplicatedStorage:WaitForChild("FightStyles"))
local function estilo()
	return FightStyles.Get(player:GetAttribute("Estilo"))
end
local CD = { X = 3, Y = 3, C = 4 }
local readyAt = { X = 0, Y = 0, C = 0 }
-- tem chakra para o golpe especial? (o clã Lee paga menos)
local function temChakra(golpe)
	local c = player:GetAttribute("Chakra")
	if c == nil then return true end
	return c >= (golpe.Chakra or 0) * (1 - (player:GetAttribute("DescontoEnergia") or 0))
end

local function raiz()
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart"), char and char:FindFirstChildOfClass("Humanoid")
end

local function inimigoPerto(root, maxDist)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local best, bestScore
	for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and not m:GetAttribute("Sumido") then
			local dir = (r.Position - root.Position) * Vector3.new(1, 0, 1)
			if dir.Magnitude <= maxDist then
				local score = dir.Magnitude - (dir.Magnitude > 0.1 and dir.Unit:Dot(look) or 1) * 10
				if not bestScore or score < bestScore then
					best, bestScore = dir.Unit, score
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------
-- Animações dos golpes (feitas por código, mexendo nas juntas do corpo R15)
-- Funciona só em personagem R15 e só aparece para o próprio jogador.
---------------------------------------------------------------

local ANIMS = {
	combo1 = { -- soco direito
		{ t = 0, p = {} },
		{ t = 0.06, p = { RightShoulder = { x = 20 }, RightElbow = { x = 120 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, Waist = { y = -12 } } },
		{ t = 0.13, p = { RightShoulder = { x = 95 }, RightElbow = { x = 5 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, Waist = { y = 30 }, Root = { y = 8 } } },
		{ t = 0.30, p = {} },
	},
	combo2 = { -- soco esquerdo
		{ t = 0, p = {} },
		{ t = 0.06, p = { LeftShoulder = { x = 20 }, LeftElbow = { x = 120 }, RightShoulder = { x = 40 }, RightElbow = { x = 100 }, Waist = { y = 12 } } },
		{ t = 0.13, p = { LeftShoulder = { x = 95 }, LeftElbow = { x = 5 }, RightShoulder = { x = 40 }, RightElbow = { x = 100 }, Waist = { y = -30 }, Root = { y = -8 } } },
		{ t = 0.30, p = {} },
	},
	combo3 = { -- gancho direito
		{ t = 0, p = {} },
		{ t = 0.10, p = { RightShoulder = { x = 0, z = 95 }, RightElbow = { x = 70 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, Waist = { y = -28 } } },
		{ t = 0.20, p = { RightShoulder = { x = 75, z = 40 }, RightElbow = { x = 50 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, Waist = { y = 45 }, Root = { y = 12 } } },
		{ t = 0.36, p = {} },
	},
	combo4 = { -- chute
		{ t = 0, p = {} },
		{ t = 0.16, p = { Waist = { x = 8 }, RightHip = { x = -25 }, RightKnee = { x = -70 }, RightShoulder = { x = 30 }, LeftShoulder = { x = 40 } } },
		{ t = 0.30, p = { Waist = { x = 16 }, RightHip = { x = 88 }, RightKnee = { x = -8 }, RightShoulder = { x = 20, z = 25 }, LeftShoulder = { x = 50, z = -20 } } },
		{ t = 0.60, p = {} },
	},
	charge = { -- segurando o soco carregado
		{ t = 0, p = {} },
		{ t = 0.25, p = { RightShoulder = { x = -35 }, RightElbow = { x = 120 }, LeftShoulder = { x = 55 }, LeftElbow = { x = 90 }, Waist = { y = -30 }, Root = { x = -12 }, RightHip = { x = 28 }, LeftHip = { x = 28 }, RightKnee = { x = -45 }, LeftKnee = { x = -45 } } },
	},
	release = { -- solta o soco carregado
		{ t = 0, p = { RightShoulder = { x = -35 }, RightElbow = { x = 120 }, LeftShoulder = { x = 55 }, LeftElbow = { x = 90 }, Waist = { y = -30 }, Root = { x = -12 }, RightHip = { x = 28 }, LeftHip = { x = 28 }, RightKnee = { x = -45 }, LeftKnee = { x = -45 } } },
		{ t = 0.12, p = { RightShoulder = { x = 100 }, RightElbow = { x = 0 }, LeftShoulder = { x = 45 }, LeftElbow = { x = 100 }, Waist = { y = 50 }, Root = { x = -8 }, RightHip = { x = 45 }, RightKnee = { x = -35 }, LeftHip = { x = -28 }, LeftKnee = { x = -10 } } },
		{ t = 0.45, p = {} },
	},
	air = { -- soco aéreo: braço lá em cima e desce batendo, pernas encolhidas
		{ t = 0, p = {} },
		{ t = 0.12, p = { RightShoulder = { x = 165 }, RightElbow = { x = 15 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, RightHip = { x = 65 }, LeftHip = { x = 45 }, RightKnee = { x = -75 }, LeftKnee = { x = -60 }, Waist = { x = 8 } } },
		{ t = 0.28, p = { RightShoulder = { x = 75 }, RightElbow = { x = 0 }, LeftShoulder = { x = 40 }, LeftElbow = { x = 100 }, Waist = { x = -30 }, RightHip = { x = 60 }, LeftHip = { x = 40 }, RightKnee = { x = -70 }, LeftKnee = { x = -55 } } },
		{ t = 0.60, p = {} },
	},
	dash = { -- soco com investida: corpo inclinado e punho na frente
		{ t = 0, p = {} },
		{ t = 0.10, p = { Root = { x = -28 }, RightShoulder = { x = 95 }, RightElbow = { x = 0 }, LeftShoulder = { x = -35 }, LeftElbow = { x = 70 }, Waist = { y = 30 }, RightHip = { x = -40 }, LeftHip = { x = 45 }, LeftKnee = { x = -55 } } },
		{ t = 0.32, p = { Root = { x = -28 }, RightShoulder = { x = 95 }, RightElbow = { x = 0 }, LeftShoulder = { x = -35 }, LeftElbow = { x = 70 }, Waist = { y = 30 }, RightHip = { x = -40 }, LeftHip = { x = 45 }, LeftKnee = { x = -55 } } },
		{ t = 0.45, p = {} },
	},
}

local motores, base, escrito = {}, {}, {}
local anim -- { keys, t0, hold }

local function ligarMotores(char)
	for m, b in pairs(base) do
		if m.Parent and escrito[m] then
			m.Transform = b
		end
	end
	motores, base, escrito = {}, {}, {}
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("AnimationConstraint") then
			motores[d.Name] = d
		end
	end
end
if player.Character then
	ligarMotores(player.Character)
end
player.CharacterAdded:Connect(function(char)
	anim = nil
	task.wait(0.5)
	ligarMotores(char)
end)

local function amostra(keys, t)
	if t <= keys[1].t then
		return keys[1].p, 1
	end
	for i = 2, #keys do
		if t <= keys[i].t then
			local a, b = keys[i - 1], keys[i]
			local f = (t - a.t) / (b.t - a.t)
			return a.p, f * f * (3 - 2 * f), b.p
		end
	end
	return keys[#keys].p, 1
end

local function playAnim(nome, segurar)
	anim = { keys = ANIMS[nome], t0 = os.clock(), hold = segurar }
end

-- estilo de corrida (Shift): tronco bem inclinado para a frente, cabeça olhando adiante e braços retos e firmes para trás.
-- fixo = true: o braço fica parado nessa posição (ignora o balanço da corrida padrão do Roblox)
local POSE_CORRIDA = {
	Root = { x = -30 },
	Waist = { x = -12 },
	Neck = { x = 26 },
	RightShoulder = { x = -58, z = 4, fixo = true },
	LeftShoulder = { x = -58, z = -4, fixo = true },
	RightElbow = { x = 0, fixo = true },
	LeftElbow = { x = 0, fixo = true },
}
local pesoCorrida = 0
local ultimoBind = 0
-- PreSimulation roda depois do Animator do Roblox e antes da física: é o único momento em que a pose vale
-- tanto nas juntas antigas (Motor6D) quanto nas novas (AnimationConstraint)
RunService.PreSimulation:Connect(function(dt)
	-- o corpo pode ainda estar sendo montado quando o script começa: liga as juntas de novo se precisar
	local char = player.Character
	local junta = motores.RightShoulder
	if char and (not junta or not junta:IsDescendantOf(char)) and os.clock() - ultimoBind > 0.5 then
		ultimoBind = os.clock()
		ligarMotores(char)
	end
	local a = anim
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local correndo = player:GetAttribute("Correndo") and hum and hum.MoveDirection.Magnitude > 0.1
	local alvoCorrida = (correndo and not a) and 1 or 0
	pesoCorrida += (alvoCorrida - pesoCorrida) * math.min(dt * 10, 1)
	local fim = a and a.keys[#a.keys].t
	local el = a and (os.clock() - a.t0)
	if a and not a.hold and el > fim then
		anim = nil
		a = nil
	end
	for nome, m in pairs(motores) do
		if m.Parent then
			-- o Animator do Roblox reescreve Transform a cada quadro; guardamos o valor dele e somamos o nosso golpe por cima
			local atual = m.Transform
			if atual ~= escrito[m] then
				base[m] = atual
			end
			local rx, ry, rz = 0, 0, 0
			local mexeu = false
			if a then
				local t = a.hold and math.min(el, fim) or el
				local pa, f, pb = amostra(a.keys, t)
				local w = math.min(el / 0.06, 1) -- entrada suave
				local ja = pa[nome]
				local jb
				if pb then
					jb = pb[nome]
				else
					jb = ja
				end
				if ja or jb then
					ja, jb = ja or {}, jb or {}
					rx = ((ja.x or 0) + ((jb.x or 0) - (ja.x or 0)) * f) * w
					ry = ((ja.y or 0) + ((jb.y or 0) - (ja.y or 0)) * f) * w
					rz = ((ja.z or 0) + ((jb.z or 0) - (ja.z or 0)) * f) * w
					mexeu = true
				end
			end
			local pc = POSE_CORRIDA[nome]
			local fixa = pc and pc.fixo and pesoCorrida > 0.01
			if pc and not pc.fixo and pesoCorrida > 0.01 then
				rx += (pc.x or 0) * pesoCorrida
				ry += (pc.y or 0) * pesoCorrida
				rz += (pc.z or 0) * pesoCorrida
				mexeu = true
			end
			if fixa then
				mexeu = true
			end
			if mexeu then
				local cf = (base[m] or atual) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
				if fixa then
					-- mistura o balanço do Roblox com a pose firme de corrida conforme o peso (0 a 1)
					local alvo = CFrame.Angles(math.rad(pc.x or 0), math.rad(pc.y or 0), math.rad(pc.z or 0))
					cf = cf:Lerp(alvo, pesoCorrida)
				end
				m.Transform = cf
				escrito[m] = m.Transform
			else
				if escrito[m] then
					m.Transform = base[m] or atual
				end
				escrito[m] = nil
			end
		end
	end
end)

-- combo (o cliente repete a conta do servidor só para saber qual animação tocar)
local comboN, comboLast, comboNext = 0, 0, 0
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.F then
		attackEvent:FireServer("combo")
		local agora = os.clock()
		if agora >= comboNext then
			if agora - comboLast > 1.1 then
				comboN = 0
			end
			local combo = estilo().Combo
			comboN = comboN % #combo + 1
			comboLast = agora
			comboNext = agora + combo[comboN].wait
			playAnim("combo" .. comboN)
		end
	end
end)

-- barra de recarga dos golpes extras
local barra = Instance.new("Frame")
barra.Size = UDim2.fromOffset(168, 66)
-- compacta: 75% do tamanho, à esquerda da barra de poderes
barra.AnchorPoint = Vector2.new(0, 1)
barra.Position = UDim2.new(0.5, -119 - 8 - 126, 1, -12)
Instance.new("UIScale", barra).Scale = 0.75
barra.BackgroundTransparency = 1
barra.Parent = gui

local slots = {}
for i, info in ipairs({ { "X", "Charge" }, { "Y", "Air" }, { "C", "Dash" } }) do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(52, 52)
	f.Position = UDim2.fromOffset((i - 1) * 58, 7)
	f.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	f.BackgroundTransparency = 0.2
	f.Parent = barra
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
	local shade = Instance.new("Frame")
	shade.AnchorPoint = Vector2.new(0, 1)
	shade.Position = UDim2.fromScale(0, 1)
	shade.Size = UDim2.fromScale(1, 0)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.45
	shade.BorderSizePixel = 0
	shade.Parent = f
	Instance.new("UICorner", shade).CornerRadius = UDim.new(0, 8)
	local key = Instance.new("TextLabel")
	key.Size = UDim2.new(1, 0, 0, 24)
	key.BackgroundTransparency = 1
	key.Font = Enum.Font.GothamBlack
	key.TextSize = 18
	key.TextColor3 = Color3.new(1, 1, 1)
	key.Text = info[1]
	key.Parent = f
	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 0, 1, -18)
	name.Size = UDim2.new(1, 0, 0, 16)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 11
	name.TextColor3 = Color3.fromRGB(220, 220, 230)
	name.Text = info[2]
	name.Parent = f
	local secs = Instance.new("TextLabel")
	secs.Size = UDim2.fromScale(1, 1)
	secs.BackgroundTransparency = 1
	secs.Font = Enum.Font.GothamBlack
	secs.TextSize = 18
	secs.TextColor3 = Color3.new(1, 1, 1)
	secs.TextStrokeTransparency = 0.4
	secs.Text = ""
	secs.Parent = f
	slots[info[1]] = { shade = shade, secs = secs, name = name }
end

-- nomes e recargas dos golpes X, Y e C mudam com o estilo
local function aplicarEstilo()
	local est = estilo()
	for _, k in ipairs({ "X", "Y", "C" }) do
		CD[k] = est[k].Cd
		slots[k].name.Text = est[k].Name
	end
end
player:GetAttributeChangedSignal("Estilo"):Connect(aplicarEstilo)
aplicarEstilo()

RunService.RenderStepped:Connect(function()
	for k, s in pairs(slots) do
		local left = readyAt[k] - os.clock()
		if left > 0 then
			s.shade.Size = UDim2.fromScale(1, math.clamp(left / CD[k], 0, 1))
			s.secs.Text = ("%.1f"):format(left)
		else
			s.shade.Size = UDim2.fromScale(1, 0)
			s.secs.Text = ""
		end
	end
end)

-- X: segurar para carregar, soltar para bater
local charging, chargeStart, chargeBall, chargeConn
local function pararCarga()
	charging = false
	if chargeConn then
		chargeConn:Disconnect()
		chargeConn = nil
	end
	if chargeBall then
		chargeBall:Destroy()
		chargeBall = nil
	end
end

local function acaoCarregado(_, estado)
	if estado == Enum.UserInputState.Begin then
		if os.clock() < readyAt.X or charging or not temChakra(estilo().X) then
			return Enum.ContextActionResult.Sink
		end
		charging, chargeStart = true, os.clock()
		playAnim("charge", true)
		chargeBall = Instance.new("Part")
		chargeBall.Shape = Enum.PartType.Ball
		chargeBall.Material = Enum.Material.Neon
		chargeBall.Color = Color3.fromRGB(255, 230, 160)
		chargeBall.Transparency = 0.3
		chargeBall.Anchored, chargeBall.CanCollide, chargeBall.CanQuery, chargeBall.CanTouch = true, false, false, false
		chargeBall.Parent = workspace
		chargeConn = RunService.RenderStepped:Connect(function()
			local char = player.Character
			local mao = char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm") or char:FindFirstChild("HumanoidRootPart"))
			if mao and chargeBall then
				chargeBall.Size = Vector3.one * (0.6 + math.min((os.clock() - chargeStart) / 1.2, 1) * 2.4)
				chargeBall.CFrame = mao.CFrame
			end
		end)
	elseif charging then
		local t = os.clock() - chargeStart
		pararCarga()
		readyAt.X = os.clock() + CD.X
		attackEvent:FireServer("charged", t)
		playAnim("release")
	end
	return Enum.ContextActionResult.Sink
end

-- Y: se estiver no chão, pula e bate no ar
local function acaoAereo(_, estado)
	if estado ~= Enum.UserInputState.Begin or os.clock() < readyAt.Y or not temChakra(estilo().Y) then
		return Enum.ContextActionResult.Sink
	end
	local root, hum = raiz()
	if not root or not hum or hum.Health <= 0 then
		return Enum.ContextActionResult.Sink
	end
	readyAt.Y = os.clock() + CD.Y
	playAnim("air")
	if estilo().Y.Tipo ~= "aereo" then
		-- uppercut / arremesso: no chão mesmo
		attackEvent:FireServer("air")
	elseif hum.FloorMaterial ~= Enum.Material.Air then
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 55, root.AssemblyLinearVelocity.Z)
		task.delay(0.3, function()
			attackEvent:FireServer("air")
		end)
	else
		attackEvent:FireServer("air")
	end
	return Enum.ContextActionResult.Sink
end

-- C: avança na direção do inimigo mais próximo (ou para a frente) batendo em quem tocar
local function acaoInvestida(_, estado)
	if estado ~= Enum.UserInputState.Begin or os.clock() < readyAt.C or not temChakra(estilo().C) then
		return Enum.ContextActionResult.Sink
	end
	local root, hum = raiz()
	if not root or not hum or hum.Health <= 0 then
		return Enum.ContextActionResult.Sink
	end
	readyAt.C = os.clock() + CD.C
	local dir = inimigoPerto(root, 28)
	if not dir then
		local l = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		dir = l.Magnitude > 0.01 and l.Unit or Vector3.new(0, 0, -1)
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	attackEvent:FireServer("dash")
	playAnim("dash")
	local c = estilo().C
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < c.Time and root.Parent do
			root.AssemblyLinearVelocity = dir * c.Speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			RunService.Heartbeat:Wait()
		end
	end)
	return Enum.ContextActionResult.Sink
end

local acoes = {
	{ "SocoCarregado", acaoCarregado, Enum.KeyCode.X, "X", UDim2.new(1, -75, 1, -110) },
	{ "SocoAereo", acaoAereo, Enum.KeyCode.Y, "Y", UDim2.new(1, -75, 1, -190) },
	{ "SocoInvestida", acaoInvestida, Enum.KeyCode.C, "C", UDim2.new(1, -75, 1, -270) },
}
for _, a in ipairs(acoes) do
	ContextActionService:BindAction(a[1], a[2], true, a[3])
	ContextActionService:SetTitle(a[1], a[4])
	ContextActionService:SetPosition(a[1], a[5])
end
