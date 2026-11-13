-- Treino da Academia (Sensei Kaito): minigame de tempo nos alvos de madeira.
-- Treino de chakra: vira uma cutscene (barras de cinema, câmera em volta do personagem) com o minigame dentro das barras.
-- Acerte 6 socos quando o marcador estiver na faixa verde. A faixa diminui e o marcador acelera; 5 erros = falhou.
-- Modo "teclas" (Coach Gaien, estações que não são alvo de madeira): 8 níveis; em cada um aparece uma
-- sequência curta de teclas W A S D para apertar na ordem. Tecla errada não tira vida: só perde vida (5)
-- quando o tempo do nível acaba.
-- A mesma cena de cutscene serve para a prática das naturezas (cena = "natureza", com a cor da natureza).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local minigame = ReplicatedStorage:WaitForChild("TreinoMinigame")

local VIDAS = 5        -- minigame de socos
local VIDAS_TECLAS = 5 -- minigame de teclas
local function lerp(a, b, t) return a + (b - a) * t end

local function new(classe, props, filhos)
	local o = Instance.new(classe)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	for _, f in ipairs(filhos or {}) do f.Parent = o end
	o.Parent = props.Parent
	return o
end
local function canto(r) return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }) end

local gui = new("ScreenGui", { Name = "TreinoUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 14, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
local painel = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -120), Size = UDim2.fromOffset(540, 178),
	BackgroundColor3 = Color3.fromRGB(30, 24, 20), BackgroundTransparency = 0.05, Parent = gui },
	{ canto(14), new("UIStroke", { Color = Color3.fromRGB(170, 120, 70), Thickness = 2 }) })
local titulo = new("TextLabel", { Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -70, 0, 24), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 18, TextColor3 = Color3.fromRGB(255, 200, 120), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
local dica = new("TextLabel", { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 18), BackgroundTransparency = 1,
	Text = "Punch when the marker is inside the green zone!  [SPACE / CLICK HIT]", Font = Enum.Font.GothamMedium, TextSize = 13,
	TextColor3 = Color3.fromRGB(210, 200, 190), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
local bSair = new("TextButton", { Position = UDim2.new(1, -46, 0, 8), Size = UDim2.fromOffset(32, 28), BackgroundColor3 = Color3.fromRGB(170, 50, 50),
	Text = "X", Font = Enum.Font.GothamBlack, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Parent = painel }, { canto(6) })
local barra = new("Frame", { Position = UDim2.fromOffset(20, 60), Size = UDim2.new(1, -40, 0, 30), BackgroundColor3 = Color3.fromRGB(70, 55, 45),
	ClipsDescendants = true, Parent = painel }, { canto(6) })
local zona = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromScale(0.2, 1), BackgroundColor3 = Color3.fromRGB(70, 200, 90), Parent = barra })
local centroZona = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.3, 1),
	BackgroundColor3 = Color3.fromRGB(255, 220, 80), Parent = zona })
local marcador = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(0, 6, 1, 12),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = barra }, { canto(3) })
local placar = new("TextLabel", { Position = UDim2.fromOffset(20, 100), Size = UDim2.fromOffset(200, 28), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
local vidasTxt = new("TextLabel", { Position = UDim2.fromOffset(20, 130), Size = UDim2.fromOffset(200, 28), BackgroundTransparency = 1, Text = "",
	Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.fromRGB(230, 70, 70), TextXAlignment = Enum.TextXAlignment.Left, Parent = painel })
local feedback = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(180, 40),
	BackgroundTransparency = 1, Text = "", Font = Enum.Font.GothamBlack, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), Parent = painel })
local bHit = new("TextButton", { Position = UDim2.new(1, -170, 1, -66), Size = UDim2.fromOffset(150, 52), BackgroundColor3 = Color3.fromRGB(230, 120, 40),
	Text = "HIT!", Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), Parent = painel }, { canto(10) })

-- modo "teclas": fileira de teclas, barra de tempo e botões na tela (celular)
local TECLAS = { "W", "A", "S", "D" }
local SERIES = { "PUSH-UPS!", "KICKS!", "SPRINT!", "FINAL SET!" }
local fileira = new("Frame", { Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 0, 40), BackgroundTransparency = 1, Visible = false, Parent = painel },
	{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }) })
local tempoFundo = new("Frame", { Position = UDim2.fromOffset(20, 100), Size = UDim2.new(1, -40, 0, 6), BackgroundColor3 = Color3.fromRGB(70, 55, 45), Visible = false, Parent = painel }, { canto(3) })
local tempoBarra = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 200, 80), Parent = tempoFundo }, { canto(3) })
local botoesTecla = new("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10), Size = UDim2.fromOffset(196, 44), BackgroundTransparency = 1, Visible = false, Parent = painel },
	{ new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6) }) })
local caixas = {}

local ativo = false
local estado

local function som()
	local s = SoundService:FindFirstChild("Sons") and SoundService.Sons:FindFirstChild("Clique")
	if s then SoundService:PlayLocalSound(s) end
end

-- trava o personagem parado durante o minigame (usa o PlayerModule se existir, senão ancora o corpo)
local function controles(ligar)
	local ps = player:FindFirstChild("PlayerScripts")
	local mod = ps and ps:FindFirstChild("PlayerModule")
	if mod then
		pcall(function()
			local c = require(mod):GetControls()
			if ligar then c:Enable() else c:Disable() end
		end)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then root.Anchored = not ligar end
end

-- o alvo de madeira balança e solta lascas
local function bater(perfeito)
	local alvo = estado and estado.alvo
	if not alvo then return end
	local partes = {}
	if alvo:IsA("BasePart") then table.insert(partes, alvo) end
	for _, d in ipairs(alvo:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(partes, d) end
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local dir = root and (partes[1].Position - root.Position) * Vector3.new(1, 0, 1)
	dir = (dir and dir.Magnitude > 0.1) and dir.Unit or Vector3.new(0, 0, 1)
	for _, p in ipairs(partes) do
		local orig = p:GetAttribute("CFOriginal") or p.CFrame
		p:SetAttribute("CFOriginal", orig)
		p.CFrame = orig + dir * (perfeito and 0.35 or 0.2)
		TweenService:Create(p, TweenInfo.new(0.25, Enum.EasingStyle.Elastic), { CFrame = orig }):Play()
	end
	-- lascas
	local base = partes[1]
	for _ = 1, perfeito and 7 or 4 do
		local l = Instance.new("Part")
		l.Size = Vector3.new(0.25, 0.25, 0.5)
		l.Color = Color3.fromRGB(150, 105, 60)
		l.Material = Enum.Material.Wood
		l.CanCollide = false
		l.CanQuery = false
		l.CFrame = CFrame.new(base.Position - dir * 0.7 + Vector3.new(0, math.random() * 2 - 0.5, 0))
		l.AssemblyLinearVelocity = (-dir * 12 + Vector3.new(math.random(-6, 6), math.random(6, 14), math.random(-6, 6)))
		l.Parent = workspace
		game:GetService("Debris"):AddItem(l, 1.2)
	end
end

-- Treino de chakra (estação de atributo "Chakra"): o personagem se ajoelha em meditação com as mãos em selo,
-- um círculo de chakra aparece no chão e uma aura sobe dele, crescendo a cada série. No fim, o chakra explode.
local COR_PADRAO = Color3.fromRGB(90, 180, 255)
local CHAKRA_COR = COR_PADRAO -- muda para a cor da natureza na prática de natureza
local SERIES_CHAKRA = { "GATHER CHAKRA", "BUILD IT UP", "HOLD IT", "RELEASE!" }
local DESCE = 0.3 -- quanto o corpo desce na base de força (pernas abertas e joelhos dobrados)
local cena = nil
local cinema = nil -- modo cinema (cutscene) do treino de chakra, mais abaixo

-- a pose vai no Transform das juntas a cada quadro, depois da animação (o C0 do personagem não pode ser mudado).
-- O personagem pode ter juntas antigas (Motor6D) ou novas (AnimationConstraint): as duas têm Transform.
-- base = pose de esforço; extra = rotação (graus) somada quando o esforço (f) chega a 1: braços abrem e voltam, corpo arqueia
local function ehJunta(d)
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end

local function girarJunta(char, parte, nome, cf, extraGraus)
	local p = char:FindFirstChild(parte)
	local j = p and p:FindFirstChild(nome)
	if not (j and ehJunta(j)) then
		j = nil
		for _, d in ipairs(char:GetDescendants()) do
			if d.Name == nome and ehJunta(d) then
				j = d
				break
			end
		end
	end
	if j then
		cena.juntas[j] = { base = cf, extra = (extraGraus or Vector3.zero) * math.pi / 180 }
	end
end

local function emissor(pai, props)
	local pe = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do pe[k] = v end
	pe.Parent = pai
	return pe
end

local function iniciarCena()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end
	cena = { juntas = {}, objetos = {}, root = root }
	local chaoY = root.Position.Y - hum.HipHeight - root.Size.Y / 2
	local r = math.rad
	if hum.RigType == Enum.HumanoidRigType.R15 then
		-- fazendo força: braços abertos ao lado do corpo, cotovelos dobrados e punhos fechados para cima;
		-- no pico do esforço os braços abrem e vão para trás, o peito estufa e a cabeça sobe
		girarJunta(char, "RightUpperArm", "RightShoulder", CFrame.Angles(r(8), 0, r(24)), Vector3.new(-22, 0, 16))
		girarJunta(char, "LeftUpperArm", "LeftShoulder", CFrame.Angles(r(8), 0, r(-24)), Vector3.new(-22, 0, -16))
		girarJunta(char, "RightLowerArm", "RightElbow", CFrame.Angles(r(100), 0, 0), Vector3.new(18, 0, 0))
		girarJunta(char, "LeftLowerArm", "LeftElbow", CFrame.Angles(r(100), 0, 0), Vector3.new(18, 0, 0))
		-- base firme: pernas abertas e joelhos dobrados, tronco inclinado e cabeça baixa de esforço
		girarJunta(char, "RightUpperLeg", "RightHip", CFrame.Angles(r(16), 0, r(14)), Vector3.new(10, 0, 6))
		girarJunta(char, "LeftUpperLeg", "LeftHip", CFrame.Angles(r(16), 0, r(-14)), Vector3.new(10, 0, -6))
		girarJunta(char, "RightLowerLeg", "RightKnee", CFrame.Angles(r(-30), 0, 0), Vector3.new(-14, 0, 0))
		girarJunta(char, "LeftLowerLeg", "LeftKnee", CFrame.Angles(r(-30), 0, 0), Vector3.new(-14, 0, 0))
		girarJunta(char, "UpperTorso", "Waist", CFrame.Angles(r(-9), 0, 0), Vector3.new(-16, 0, 0))
		girarJunta(char, "Head", "Neck", CFrame.Angles(r(-10), 0, 0), Vector3.new(24, 0, 0))
		root.CFrame = root.CFrame - Vector3.new(0, DESCE, 0)
		cena.desceu = DESCE
	else
		local torso = char:FindFirstChild("Torso")
		if torso then
			local function g(nome, cf)
				local j = torso:FindFirstChild(nome)
				if j and j:IsA("Motor6D") then cena.juntas[j] = { base = cf, extra = Vector3.new(0, 0, 0) } end
			end
			g("Right Shoulder", CFrame.Angles(0, 0, r(80)))
			g("Left Shoulder", CFrame.Angles(0, 0, r(-80)))
		end
	end
	cena.puxa = 0 -- tranco de esforço: vai a 1 a cada tecla certa e volta a 0
	-- PreSimulation roda depois do Animator do Roblox: a pose vale nas juntas antigas e nas novas (AnimationConstraint)
	cena.pose = RunService.PreSimulation:Connect(function(dt)
		local c = cena
		if not c then return end
		local nv = cinema and cinema.nivel or 0
		c.puxa = math.max(0, c.puxa - dt * 2.4)
		-- o esforço vai e volta como quem prende e solta o ar: mais rápido e mais forte a cada série
		local ciclo = (math.sin(os.clock() * (3.2 + 3 * nv)) + 1) / 2
		local f = math.clamp(0.25 + (0.35 + 0.4 * nv) * ciclo + c.puxa, 0, 1.5)
		-- o corpo também treme de esforço
		local amp = 0.012 + 0.045 * nv + 0.05 * c.puxa
		for j, e in pairs(c.juntas) do
			if j.Parent then
				j.Transform = e.base * CFrame.Angles(e.extra.X * f, e.extra.Y * f, e.extra.Z * f)
					* CFrame.Angles((math.random() - 0.5) * amp, (math.random() - 0.5) * amp, (math.random() - 0.5) * amp)
			end
		end
	end)
	-- círculo de chakra no chão
	local anel = Instance.new("Part")
	anel.Shape = Enum.PartType.Cylinder
	anel.Anchored, anel.CanCollide, anel.CanQuery, anel.CanTouch, anel.CastShadow = true, false, false, false, false
	anel.Material = Enum.Material.Neon
	anel.Color = CHAKRA_COR
	anel.Transparency = 0.45
	anel.Size = Vector3.new(0.12, 5, 5)
	anel.CFrame = CFrame.new(root.Position.X, chaoY + 0.08, root.Position.Z) * CFrame.Angles(0, 0, r(90))
	anel.Parent = workspace
	local miolo = anel:Clone()
	miolo.Color = Color3.fromRGB(15, 25, 45)
	miolo.Transparency = 0.35
	miolo.Size = Vector3.new(0.14, 4.2, 4.2)
	miolo.Parent = workspace
	cena.anel, cena.miolo = anel, miolo
	table.insert(cena.objetos, anel)
	table.insert(cena.objetos, miolo)
	-- aura subindo do corpo
	local at = Instance.new("Attachment")
	at.Position = Vector3.new(0, -1, 0)
	at.Parent = root
	table.insert(cena.objetos, at)
	cena.aura = emissor(at, { Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(CHAKRA_COR, Color3.new(1, 1, 1)),
		LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.7, 1.2), Speed = NumberRange.new(2, 4), Acceleration = Vector3.new(0, 7, 0),
		SpreadAngle = Vector2.new(35, 35), Rate = 15, EmissionDirection = Enum.NormalId.Top, Rotation = NumberRange.new(0, 360) })
	cena.chama = emissor(at, { Texture = "rbxasset://textures/particles/fire_main.dds", Color = ColorSequence.new(CHAKRA_COR),
		LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 0.4) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(3, 5), SpreadAngle = Vector2.new(15, 15), Rate = 8,
		EmissionDirection = Enum.NormalId.Top })
	cena.luz = Instance.new("PointLight")
	cena.luz.Color = CHAKRA_COR
	cena.luz.Range = 10
	cena.luz.Brightness = 1
	cena.luz.Parent = root
	table.insert(cena.objetos, cena.luz)
	cena.contorno = Instance.new("Highlight")
	cena.contorno.FillTransparency = 1
	cena.contorno.OutlineColor = CHAKRA_COR
	cena.contorno.OutlineTransparency = 0.7
	cena.contorno.Parent = char
	table.insert(cena.objetos, cena.contorno)
end

-- a aura cresce conforme as séries (k de 0 a 1)
local function nivelCena(k)
	if cinema then cinema.nivel = k end
	if not cena or not cena.aura then return end
	cena.aura.Rate = 15 + 70 * k
	cena.chama.Rate = 8 + 30 * k
	cena.luz.Brightness = 1 + 3 * k
	cena.luz.Range = 10 + 10 * k
	cena.contorno.OutlineTransparency = 0.7 - 0.6 * k
	local d = 5 + 5 * k
	TweenService:Create(cena.anel, TweenInfo.new(0.3), { Size = Vector3.new(0.12, d, d) }):Play()
	TweenService:Create(cena.miolo, TweenInfo.new(0.3), { Size = Vector3.new(0.14, d - 0.8, d - 0.8) }):Play()
end

local function pulsoCena()
	if not cena or not cena.aura then return end
	cena.puxa = 1 -- o corpo dá um tranco de esforço ao acertar a tecla
	cena.aura:Emit(8)
	local b = cena.luz.Brightness
	cena.luz.Brightness = b + 3
	TweenService:Create(cena.luz, TweenInfo.new(0.25), { Brightness = b }):Play()
end

local function falhaCena()
	if cinema then cinema.tremor = 0.35 end
	if not cena or not cena.aura then return end
	cena.aura.Enabled, cena.chama.Enabled = false, false
	task.delay(0.25, function()
		if cena and cena.aura then cena.aura.Enabled, cena.chama.Enabled = true, true end
	end)
end

local function fimCena(ok)
	if not cena then return end
	local c = cena
	cena = nil
	if c.pose then c.pose:Disconnect() end
	if c.desceu and c.root.Parent then
		c.root.CFrame = c.root.CFrame + Vector3.new(0, c.desceu, 0)
	end
	if ok and c.aura then
		-- o chakra explode para fora
		c.aura.Speed = NumberRange.new(18, 30)
		c.aura.SpreadAngle = Vector2.new(180, 180)
		c.aura.Acceleration = Vector3.zero
		c.aura:Emit(70)
		TweenService:Create(c.anel, TweenInfo.new(0.5), { Size = Vector3.new(0.12, 18, 18), Transparency = 1 }):Play()
		TweenService:Create(c.luz, TweenInfo.new(0.5), { Brightness = 8, Range = 24 }):Play()
	end
	if c.aura then c.aura.Rate, c.chama.Rate = 0, 0 end
	task.delay(ok and 0.9 or 0.2, function()
		for _, o in ipairs(c.objetos) do
			if o.Parent then o:Destroy() end
		end
	end)
end


---------------------------------------------------------------
-- Modo cinema do treino de chakra: barras pretas em cima e embaixo (11% da tela cada), câmera de cutscene
-- girando devagar em volta do personagem e a interface do minigame DENTRO das barras, sem cobrir o boneco.
---------------------------------------------------------------
local FAIXA = 0.11
local barraTopo = new("Frame", { Name = "BarraTopo", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0), Size = UDim2.fromScale(1, FAIXA),
	BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, Parent = gui })
local barraBaixo = new("Frame", { Name = "BarraBaixo", AnchorPoint = Vector2.new(0, 0), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, FAIXA),
	BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false, Parent = gui })
-- fio de chakra na borda das barras
local fiosBarra = {}
for _, b in ipairs({ barraTopo, barraBaixo }) do
	fiosBarra[#fiosBarra + 1] = new("Frame", { AnchorPoint = Vector2.new(0, b == barraTopo and 1 or 0), Position = UDim2.fromScale(0, b == barraTopo and 1 or 0), Size = UDim2.new(1, 0, 0, 2),
		BackgroundColor3 = CHAKRA_COR, BackgroundTransparency = 0.3, BorderSizePixel = 0, Parent = b })
end

-- onde cada peça do painel fica no modo cinema
local LAYOUT_CINEMA = {
	{ "titulo", barraTopo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -10), Size = UDim2.new(0.6, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22 } },
	{ "dica", barraTopo, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 14), Size = UDim2.new(0.6, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center } },
	{ "bSair", barraTopo, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0) } },
	{ "feedback", barraTopo, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0) } },
	{ "fileira", barraBaixo, { Position = UDim2.new(0.5, -220, 0.5, -26), Size = UDim2.fromOffset(440, 40) } },
	{ "tempoFundo", barraBaixo, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, 20), Size = UDim2.fromOffset(380, 5) } },
	{ "placar", barraBaixo, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, -14), Size = UDim2.fromOffset(200, 26) } },
	{ "vidasTxt", barraBaixo, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 24, 0.5, 14), Size = UDim2.fromOffset(200, 26) } },
	{ "botoesTecla", barraBaixo, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -20, 0.5, 0) } },
}
local PECAS = { titulo = titulo, dica = dica, bSair = bSair, feedback = feedback, fileira = fileira, tempoFundo = tempoFundo,
	placar = placar, vidasTxt = vidasTxt, botoesTecla = botoesTecla }
local guardado = {}
-- telas que somem durante a cutscene (voltam como estavam)
local OUTRAS_TELAS = { "HUD", "HudOnda", "HudPoderes", "HudNatureza", "ViagemUI", "AtributosUI", "MissaoUI", "ClaUI", "Extras", "TutorialBotao" }
local telasDesligadas = {}

local function cameraCinema(root)
	local cam = workspace.CurrentCamera
	local t0 = os.clock()
	local frente = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if frente.Magnitude < 0.01 then frente = Vector3.new(0, 0, -1) end
	frente = frente.Unit
	cinema.fov = cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("CameraChakra", Enum.RenderPriority.Camera.Value + 2, function()
		if not root.Parent then return end
		local t = os.clock() - t0
		-- entra afastada e chega perto; depois balança devagar de um lado para o outro na frente do personagem
		local entrada = 1 - (1 - math.min(t / 1.4, 1)) ^ 3
		local nivel = cinema and cinema.nivel or 0
		-- termina bem perto, focada no personagem (do peito para cima cabe entre as barras)
		local dist = 14 - (7 + 1.5 * nivel) * entrada
		local ang = math.sin(t * 0.35) * 0.5 + 0.3
		local dir = CFrame.Angles(0, ang, 0):VectorToWorldSpace(frente)
		local foco = root.Position + Vector3.new(0, 0.9, 0)
		local pos = foco + dir * dist + Vector3.new(0, 1.4 - 1.0 * entrada + math.sin(t * 0.6) * 0.12, 0)
		local tremor = cinema and cinema.tremor or 0
		if tremor > 0 then
			pos += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * tremor
			cinema.tremor = math.max(0, tremor - 0.03)
		end
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.lookAt(pos, foco)
		cam.Focus = CFrame.new(foco) -- o jogo carrega e mostra o que está em volta do personagem
		cam.FieldOfView = 60
	end)
end

local function ligarCinema()
	if cinema then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	cinema = { nivel = 0, tremor = 0 }
	-- tira as outras telas do caminho
	table.clear(telasDesligadas)
	for _, n in ipairs(OUTRAS_TELAS) do
		local g = player.PlayerGui:FindFirstChild(n)
		if g and g:IsA("ScreenGui") and g.Enabled then
			g.Enabled = false
			table.insert(telasDesligadas, g)
		end
	end
	-- leva as peças do painel para as barras
	table.clear(guardado)
	for _, item in ipairs(LAYOUT_CINEMA) do
		local o = PECAS[item[1]]
		local g = { Parent = o.Parent }
		for k in pairs(item[3]) do g[k] = o[k] end
		guardado[o] = g
		for k, v in pairs(item[3]) do o[k] = v end
		o.Parent = item[2]
	end
	painel.Visible = false
	for _, f in ipairs(fiosBarra) do f.BackgroundColor3 = CHAKRA_COR end
	barraTopo.Visible, barraBaixo.Visible = true, true
	barraTopo.Position, barraBaixo.Position = UDim2.fromScale(0, 0), UDim2.fromScale(0, 1)
	barraTopo.AnchorPoint, barraBaixo.AnchorPoint = Vector2.new(0, 1), Vector2.new(0, 0)
	local ti = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	TweenService:Create(barraTopo, ti, { AnchorPoint = Vector2.new(0, 0) }):Play()
	TweenService:Create(barraBaixo, ti, { AnchorPoint = Vector2.new(0, 1) }):Play()
	cameraCinema(root)
end

local function desligarCinema()
	if not cinema then return end
	local c = cinema
	cinema = nil
	RunService:UnbindFromRenderStep("CameraChakra")
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Custom
	cam.FieldOfView = player:GetAttribute("FOVBase") or c.fov or 70
	for o, g in pairs(guardado) do
		for k, v in pairs(g) do o[k] = v end
	end
	table.clear(guardado)
	painel.Visible = true
	barraTopo.Visible, barraBaixo.Visible = false, false
	for _, g in ipairs(telasDesligadas) do
		if g.Parent then g.Enabled = true end
	end
	table.clear(telasDesligadas)
end

local teclaApertada
local function novaSerie()
	local n = 3 + math.floor(estado.acertos / 2) -- 3, 3, 4, 4, 5, 5, 6 e 6 teclas
	estado.seq, estado.idx = {}, 1
	estado.limite = 2.6 + n * 0.9
	estado.resta = estado.limite
	for _, c in ipairs(caixas) do c:Destroy() end
	caixas = {}
	for i = 1, n do
		local t = TECLAS[math.random(1, #TECLAS)]
		estado.seq[i] = t
		caixas[i] = new("TextLabel", { Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(70, 55, 45), Text = t, Font = Enum.Font.GothamBlack,
			TextSize = 22, TextColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = fileira }, { canto(8), new("UIStroke", { Color = Color3.fromRGB(170, 120, 70), Thickness = 2 }) })
	end
	caixas[1].BackgroundColor3 = Color3.fromRGB(230, 120, 40)
	local nomes = estado.chakra and (estado.series or SERIES_CHAKRA) or SERIES
	titulo.Text = estado.cabecalho .. "  ·  " .. nomes[math.min(math.floor(estado.acertos * #nomes / estado.total) + 1, #nomes)]
	if estado.chakra then nivelCena(estado.acertos / estado.total) end
	placar.Text = ("SETS  %d / %d"):format(estado.acertos, estado.total)
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", estado.maxVidas - estado.vidas)
end

local function novaRodada()
	if estado.modo == "teclas" then return novaSerie() end
	local k = estado.acertos
	local t = math.clamp(k / (estado.total - 1), 0, 1)
	estado.largura = lerp(0.32, 0.15, t)
	estado.vel = lerp(0.7, 1.5, t)
	local m = estado.largura / 2 + 0.04
	local c
	repeat
		c = m + math.random() * (1 - 2 * m)
	until not estado.centro or math.abs(c - estado.centro) > 0.2
	estado.centro = c
	zona.Size = UDim2.fromScale(estado.largura, 1)
	zona.Position = UDim2.fromScale(c, 0)
	placar.Text = ("HITS  %d / %d"):format(estado.acertos, estado.total)
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", estado.maxVidas - estado.vidas)
end

local function terminar(resultado)
	if not ativo then return end
	ativo = false
	ContextActionService:UnbindAction("TreinoHit")
	ContextActionService:UnbindAction("TreinoTeclas")
	local eraCinema = cinema ~= nil
	if eraCinema and resultado == "ok" then cinema.tremor = 0.7 end -- o chakra explode: a câmera treme
	fimCena(resultado == "ok")
	-- na cutscene o personagem só volta a andar quando a câmera volta ao normal
	if not eraCinema then controles(true) end
	minigame:FireServer(resultado, estado.acertos)
	feedback.Text = resultado == "ok" and "COMPLETE!" or "FAILED"
	feedback.TextColor3 = resultado == "ok" and Color3.fromRGB(90, 230, 110) or Color3.fromRGB(240, 80, 80)
	feedback.TextTransparency = 0
	task.delay(1.2, function()
		if not ativo then
			gui.Enabled = false
			if eraCinema then
				desligarCinema()
				controles(true)
			end
		end
	end)
end

local function mostrar(texto, cor)
	feedback.Text = texto
	feedback.TextColor3 = cor
	feedback.TextTransparency = 0
	TweenService:Create(feedback, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
end

local function errou()
	estado.vidas -= 1
	if estado.chakra then falhaCena() end
	mostrar("MISS!", Color3.fromRGB(240, 80, 80))
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", estado.maxVidas - estado.vidas)
	if estado.vidas <= 0 then terminar("falhou") return true end
	return false
end

-- pulinho do personagem a cada tecla certa (só visual)
local function pulinho()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local orig = hum.HipHeight
	TweenService:Create(hum, TweenInfo.new(0.08), { HipHeight = orig + 0.5 }):Play()
	task.delay(0.09, function() TweenService:Create(hum, TweenInfo.new(0.1), { HipHeight = estado and estado.hip or orig }):Play() end)
end

teclaApertada = function(t)
	if not ativo or estado.modo ~= "teclas" then return end
	local caixa = caixas[estado.idx]
	if estado.seq[estado.idx] == t then
		som()
		if estado.chakra then pulsoCena() else pulinho() end
		caixa.BackgroundColor3 = Color3.fromRGB(70, 200, 90)
		estado.idx += 1
		if estado.idx > #estado.seq then
			estado.acertos += 1
			local rapido = estado.resta > estado.limite * 0.5
			mostrar(rapido and "PERFECT!" or "GOOD!", rapido and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(110, 230, 120))
			if estado.acertos >= estado.total then
				placar.Text = ("SETS  %d / %d"):format(estado.acertos, estado.total)
				terminar("ok")
				return
			end
			novaSerie()
		else
			caixas[estado.idx].BackgroundColor3 = Color3.fromRGB(230, 120, 40)
		end
	else
		-- tecla errada: só pisca vermelho (não tira vida; quem tira vida é o tempo acabando)
		caixa.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		task.delay(0.2, function()
			if caixa.Parent and caixas[estado.idx] == caixa then caixa.BackgroundColor3 = Color3.fromRGB(230, 120, 40) end
		end)
	end
end
for i, t in ipairs(TECLAS) do
	local b = new("TextButton", { Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Color3.fromRGB(230, 120, 40), Text = t, Font = Enum.Font.GothamBlack,
		TextSize = 22, TextColor3 = Color3.new(1, 1, 1), LayoutOrder = i, Parent = botoesTecla }, { canto(8) })
	b.MouseButton1Click:Connect(function() teclaApertada(t) end)
end

local function golpe()
	if not ativo or estado.modo == "teclas" or os.clock() < estado.travaAte then return end
	estado.travaAte = os.clock() + 0.25
	local d = math.abs(estado.pos - estado.centro)
	if d <= estado.largura / 2 then
		local perfeito = d <= estado.largura * 0.15
		estado.acertos += 1
		som()
		bater(perfeito)
		mostrar(perfeito and "PERFECT!" or "HIT!", perfeito and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(110, 230, 120))
		if estado.acertos >= estado.total then
			placar.Text = ("HITS  %d / %d"):format(estado.acertos, estado.total)
			terminar("ok")
			return
		end
		novaRodada()
	else
		estado.vidas -= 1
		mostrar("MISS!", Color3.fromRGB(240, 80, 80))
		barra.BackgroundColor3 = Color3.fromRGB(140, 40, 40)
		TweenService:Create(barra, TweenInfo.new(0.3), { BackgroundColor3 = Color3.fromRGB(70, 55, 45) }):Play()
		vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", estado.maxVidas - estado.vidas)
		if estado.vidas <= 0 then terminar("falhou") end
	end
end

bHit.MouseButton1Click:Connect(golpe)
bSair.MouseButton1Click:Connect(function() terminar("falhou") end)

RunService.RenderStepped:Connect(function(dt)
	if not ativo then return end
	if estado.modo == "teclas" then
		estado.resta -= dt
		tempoBarra.Size = UDim2.fromScale(math.clamp(estado.resta / estado.limite, 0, 1), 1)
		if estado.resta <= 0 then
			-- o tempo acabou: perde uma vida e vem outra sequência
			if not errou() then novaSerie() end
		end
		return
	end
	estado.tempo += dt
	local v = estado.vel
	-- na segunda metade o marcador muda de ritmo para não dar para decorar o tempo
	if estado.acertos >= 5 then
		v *= 1 + 0.35 * math.sin(estado.tempo * 5.3)
	end
	estado.pos += estado.dir * v * dt
	if estado.pos >= 1 then estado.pos, estado.dir = 1, -1 end
	if estado.pos <= 0 then estado.pos, estado.dir = 0, 1 end
	marcador.Position = UDim2.fromScale(estado.pos, 0.5)
end)

minigame.OnClientEvent:Connect(function(info)
	if info.acao ~= "comecar" or ativo then return end
	local teclas = info.modo == "teclas"
	local hum0 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local maxVidas = teclas and VIDAS_TECLAS or VIDAS
	estado = { total = info.acertos or 10, acertos = 0, vidas = maxVidas, maxVidas = maxVidas, pos = 0, dir = 1, tempo = 0, travaAte = 0, alvo = info.alvo,
		modo = teclas and "teclas" or "socos", hip = hum0 and hum0.HipHeight }
	estado.chakra = teclas and (info.cena == "chakra" or info.cena == "natureza" or info.id == "Chakra")
	-- prática de natureza: a cena usa a cor e o nome da natureza
	CHAKRA_COR = (info.cena == "natureza" and info.cor) or COR_PADRAO
	estado.series = info.cena == "natureza" and info.series or nil
	estado.cabecalho = (info.cena == "natureza" and string.upper(info.nome or "NATURE") .. " PRACTICE") or (estado.chakra and "CHAKRA TRAINING") or (info.titulo or (teclas and "COACH GAIEN'S DRILL" or "SENSEI KAITO'S TRAINING")) .. "  ·  " .. string.upper(info.nome or "")
	titulo.Text = estado.cabecalho
	dica.Text = (info.cena == "natureza" and (info.dica or "Press the keys in order.") .. "  [W A S D]")
		or (estado.chakra and "Focus! Press the keys in order to gather chakra.  [W A S D]")
		or teclas and "Press the keys in order before the time runs out!  [W A S D]"
		or ((info.dica or "Punch when the marker is inside the green zone!") .. "  [SPACE / CLICK HIT]")
	barra.Visible, bHit.Visible = not teclas, not teclas
	fileira.Visible, tempoFundo.Visible, botoesTecla.Visible = teclas, teclas, teclas
	placar.Position = UDim2.fromOffset(20, teclas and 112 or 100)
	vidasTxt.Position = UDim2.fromOffset(20, teclas and 140 or 130)
	feedback.Text = ""
	novaRodada()
	-- vira o personagem para o alvo
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local alvoPart = info.alvo and (info.alvo:IsA("BasePart") and info.alvo or info.alvo:FindFirstChildWhichIsA("BasePart", true))
	if root and alvoPart then
		local alvoPos = Vector3.new(alvoPart.Position.X, root.Position.Y, alvoPart.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, alvoPos)
	end
	controles(false)
	if cinema and not estado.chakra then desligarCinema() end -- sobrou de um treino de chakra que acabou agora
	if estado.chakra then
		iniciarCena()
		ligarCinema()
		nivelCena(0)
	end
	ContextActionService:BindActionAtPriority("TreinoHit", function(_, st)
		if st == Enum.UserInputState.Begin then golpe() end
		return Enum.ContextActionResult.Sink
	end, false, 3000, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	if teclas then
		ContextActionService:BindActionAtPriority("TreinoTeclas", function(_, st, input)
			if st == Enum.UserInputState.Begin then teclaApertada(input.KeyCode.Name) end
			return Enum.ContextActionResult.Sink
		end, false, 3000, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D)
	end
	ativo = true
	gui.Enabled = true
end)

player.CharacterRemoving:Connect(function()
	if ativo then terminar("falhou") end
end)
