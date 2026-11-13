-- Treino da Academia (Sensei Kaito): minigame de tempo nos alvos de madeira.
-- Acerte 10 socos quando o marcador estiver na faixa verde. A faixa diminui e o marcador acelera; 3 erros = falhou.
-- Modo "teclas" (Coach Gaien, estações que não são alvo de madeira): 4 séries de exercícios; em cada uma
-- aparece uma sequência de teclas W A S D para apertar na ordem antes do tempo acabar. 3 erros = falhou.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local minigame = ReplicatedStorage:WaitForChild("TreinoMinigame")

local VIDAS = 3
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

local gui = new("ScreenGui", { Name = "TreinoUI", ResetOnSpawn = false, DisplayOrder = 14, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
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
local CHAKRA_COR = Color3.fromRGB(90, 180, 255)
local SERIES_CHAKRA = { "GATHER CHAKRA", "HAND SIGNS", "FOCUS", "RELEASE!" }
local DESCE = 1.35 -- quanto o corpo desce para ficar ajoelhado
local cena = nil

-- a pose vai no Transform das juntas a cada quadro, depois da animação (o C0 do personagem não pode ser mudado)
local function girarJunta(char, parte, nome, cf)
	local p = char:FindFirstChild(parte)
	local j = p and p:FindFirstChild(nome)
	if j and j:IsA("Motor6D") then
		cena.juntas[j] = cf
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
		-- mãos juntas na frente do peito (selo)
		girarJunta(char, "RightUpperArm", "RightShoulder", CFrame.Angles(r(80), 0, r(-32)))
		girarJunta(char, "LeftUpperArm", "LeftShoulder", CFrame.Angles(r(80), 0, r(32)))
		girarJunta(char, "RightLowerArm", "RightElbow", CFrame.Angles(r(70), 0, 0))
		girarJunta(char, "LeftLowerArm", "LeftElbow", CFrame.Angles(r(70), 0, 0))
		-- ajoelhado (coxas para a frente, canelas para trás)
		girarJunta(char, "RightUpperLeg", "RightHip", CFrame.Angles(r(85), 0, 0))
		girarJunta(char, "LeftUpperLeg", "LeftHip", CFrame.Angles(r(85), 0, 0))
		girarJunta(char, "RightLowerLeg", "RightKnee", CFrame.Angles(r(-150), 0, 0))
		girarJunta(char, "LeftLowerLeg", "LeftKnee", CFrame.Angles(r(-150), 0, 0))
		root.CFrame = root.CFrame - Vector3.new(0, DESCE, 0)
		cena.desceu = DESCE
	else
		local torso = char:FindFirstChild("Torso")
		if torso then
			local function g(nome, cf)
				local j = torso:FindFirstChild(nome)
				if j and j:IsA("Motor6D") then cena.juntas[j] = cf end
			end
			g("Right Shoulder", CFrame.Angles(0, 0, r(80)))
			g("Left Shoulder", CFrame.Angles(0, 0, r(-80)))
		end
	end
	cena.pose = RunService.Stepped:Connect(function()
		for j, cf in pairs(cena and cena.juntas or {}) do
			if j.Parent then j.Transform = cf end
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
	cena.aura:Emit(8)
	local b = cena.luz.Brightness
	cena.luz.Brightness = b + 3
	TweenService:Create(cena.luz, TweenInfo.new(0.25), { Brightness = b }):Play()
end

local function falhaCena()
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

local teclaApertada
local function novaSerie()
	local n = 4 + estado.acertos -- 4, 5, 6 e 7 teclas
	estado.seq, estado.idx = {}, 1
	estado.limite = 1.6 + n * 0.75
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
	local nomes = estado.chakra and SERIES_CHAKRA or SERIES
	titulo.Text = estado.cabecalho .. "  ·  " .. nomes[math.min(estado.acertos + 1, #nomes)]
	if estado.chakra then nivelCena(estado.acertos / estado.total) end
	placar.Text = ("SETS  %d / %d"):format(estado.acertos, estado.total)
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", VIDAS - estado.vidas)
end

local function novaRodada()
	if estado.modo == "teclas" then return novaSerie() end
	local k = estado.acertos
	local t = math.clamp(k / (estado.total - 1), 0, 1)
	estado.largura = lerp(0.22, 0.065, t)
	estado.vel = lerp(0.85, 2.3, t)
	local m = estado.largura / 2 + 0.04
	local c
	repeat
		c = m + math.random() * (1 - 2 * m)
	until not estado.centro or math.abs(c - estado.centro) > 0.2
	estado.centro = c
	zona.Size = UDim2.fromScale(estado.largura, 1)
	zona.Position = UDim2.fromScale(c, 0)
	placar.Text = ("HITS  %d / %d"):format(estado.acertos, estado.total)
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", VIDAS - estado.vidas)
end

local function terminar(resultado)
	if not ativo then return end
	ativo = false
	ContextActionService:UnbindAction("TreinoHit")
	ContextActionService:UnbindAction("TreinoTeclas")
	fimCena(resultado == "ok")
	controles(true)
	minigame:FireServer(resultado, estado.acertos)
	feedback.Text = resultado == "ok" and "COMPLETE!" or "FAILED"
	feedback.TextColor3 = resultado == "ok" and Color3.fromRGB(90, 230, 110) or Color3.fromRGB(240, 80, 80)
	task.delay(1.2, function()
		if not ativo then gui.Enabled = false end
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
	vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", VIDAS - estado.vidas)
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
		caixa.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
		task.delay(0.2, function()
			if caixa.Parent and caixas[estado.idx] == caixa then caixa.BackgroundColor3 = Color3.fromRGB(230, 120, 40) end
		end)
		errou()
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
		vidasTxt.Text = string.rep("♥ ", estado.vidas) .. string.rep("♡ ", VIDAS - estado.vidas)
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
	estado = { total = info.acertos or 10, acertos = 0, vidas = VIDAS, pos = 0, dir = 1, tempo = 0, travaAte = 0, alvo = info.alvo,
		modo = teclas and "teclas" or "socos", hip = hum0 and hum0.HipHeight }
	estado.chakra = teclas and (info.cena == "chakra" or info.id == "Chakra")
	estado.cabecalho = (estado.chakra and "CHAKRA TRAINING") or (info.titulo or (teclas and "COACH GAIEN'S DRILL" or "SENSEI KAITO'S TRAINING")) .. "  ·  " .. string.upper(info.nome or "")
	titulo.Text = estado.cabecalho
	dica.Text = (estado.chakra and "Focus! Press the keys in order to gather chakra.  [W A S D]")
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
	if estado.chakra then
		iniciarCena()
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
