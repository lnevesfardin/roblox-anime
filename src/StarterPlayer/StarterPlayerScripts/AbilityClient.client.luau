-- LocalScript: StarterPlayerScripts > AbilityClient
-- Poderes do clã (Fase 4): Q e E (básicos) e R (forte). No celular aparecem 3 botões.
-- Mostra os 3 poderes do clã com a recarga, o cadeado dos que ainda não foram liberados,
-- a barra de chakra e o painel POWERS com o caminho do clã.
-- Estado vem do servidor nos atributos "PoderesEstado" (JSON), "Chakra" e "ChakraMax".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")

local ClanPowers = require(ReplicatedStorage:WaitForChild("ClanPowers"))
local useEvent = ReplicatedStorage:WaitForChild("UseAbility")
local feedbackEvent = ReplicatedStorage:WaitForChild("AbilityFeedback")

local player = Players.LocalPlayer
local KEYS = ClanPowers.KEYS
local readyAt = { 0, 0, 0 }
local total = { 1, 1, 1 }
local estado = { Cla = "", Ok = { false, false, false }, Motivo = { "", "", "" } }

---------------------------------------------------------------
-- HUD
---------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "HudPoderes"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true -- mesma referência do HUD (botões CLAN e STATS)
gui.Parent = player:WaitForChild("PlayerGui")

local barra = Instance.new("Frame")
barra.Size = UDim2.fromOffset(318, 84)
-- compacta: 75% do tamanho, presa pela base
barra.AnchorPoint = Vector2.new(0, 1)
barra.Position = UDim2.new(0.5, -119, 1, -12)
Instance.new("UIScale", barra).Scale = 0.75
barra.BackgroundTransparency = 1
barra.Visible = false
barra.Parent = gui

-- barra de chakra em cima dos poderes
local chakraFundo = Instance.new("Frame")
chakraFundo.Size = UDim2.new(1, 0, 0, 12)
chakraFundo.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
chakraFundo.BackgroundTransparency = 0.2
chakraFundo.BorderSizePixel = 0
chakraFundo.Parent = barra
Instance.new("UICorner", chakraFundo).CornerRadius = UDim.new(1, 0)
local chakraBarra = Instance.new("Frame")
chakraBarra.Size = UDim2.fromScale(1, 1)
chakraBarra.BackgroundColor3 = Color3.fromRGB(80, 170, 255)
chakraBarra.BorderSizePixel = 0
chakraBarra.Parent = chakraFundo
Instance.new("UICorner", chakraBarra).CornerRadius = UDim.new(1, 0)
local chakraTexto = Instance.new("TextLabel")
chakraTexto.Size = UDim2.fromScale(1, 1)
chakraTexto.BackgroundTransparency = 1
chakraTexto.Font = Enum.Font.GothamBlack
chakraTexto.TextSize = 10
chakraTexto.TextColor3 = Color3.new(1, 1, 1)
chakraTexto.TextStrokeTransparency = 0.5
chakraTexto.ZIndex = 2
chakraTexto.Parent = chakraFundo

local aviso = Instance.new("TextLabel")
aviso.Size = UDim2.fromOffset(460, 24)
aviso.Position = UDim2.new(0.5, -230, 1, -128)
aviso.BackgroundTransparency = 1
aviso.Font = Enum.Font.GothamBold
aviso.TextSize = 16
aviso.TextColor3 = Color3.fromRGB(255, 120, 120)
aviso.TextStrokeTransparency = 0.4
aviso.Text = ""
aviso.Parent = gui

local slots = {}
for i = 1, 3 do
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(100, 62)
	f.Position = UDim2.fromOffset((i - 1) * 109, 20)
	f.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	f.BackgroundTransparency = 0.15
	f.ClipsDescendants = true
	f.Parent = barra
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 10)
	local stroke = Instance.new("UIStroke", f)
	stroke.Thickness = i == 3 and 3 or 2
	stroke.Color = Color3.fromRGB(80, 80, 100)

	local tecla = Instance.new("TextLabel")
	tecla.Size = UDim2.fromOffset(22, 18)
	tecla.Position = UDim2.fromOffset(6, 4)
	tecla.BackgroundTransparency = 1
	tecla.Font = Enum.Font.GothamBlack
	tecla.TextSize = 15
	tecla.TextColor3 = Color3.new(1, 1, 1)
	tecla.TextXAlignment = Enum.TextXAlignment.Left
	tecla.Text = KEYS[i]
	tecla.ZIndex = 3
	tecla.Parent = f

	local nome = Instance.new("TextLabel")
	nome.Size = UDim2.new(1, -10, 0, 30)
	nome.Position = UDim2.fromOffset(5, 22)
	nome.BackgroundTransparency = 1
	nome.Font = Enum.Font.GothamBold
	nome.TextSize = 12
	nome.TextWrapped = true
	nome.TextColor3 = Color3.new(1, 1, 1)
	nome.ZIndex = 3
	nome.Parent = f

	local custo = Instance.new("TextLabel")
	custo.Size = UDim2.new(1, -8, 0, 12)
	custo.Position = UDim2.new(0, 4, 1, -14)
	custo.BackgroundTransparency = 1
	custo.Font = Enum.Font.GothamBold
	custo.TextSize = 10
	custo.TextColor3 = Color3.fromRGB(120, 190, 255)
	custo.TextXAlignment = Enum.TextXAlignment.Right
	custo.ZIndex = 3
	custo.Parent = f

	local sombra = Instance.new("Frame")
	sombra.AnchorPoint = Vector2.new(0, 1)
	sombra.Position = UDim2.fromScale(0, 1)
	sombra.Size = UDim2.fromScale(1, 0)
	sombra.BackgroundColor3 = Color3.new(0, 0, 0)
	sombra.BackgroundTransparency = 0.35
	sombra.BorderSizePixel = 0
	sombra.ZIndex = 2
	sombra.Parent = f

	local tempo = Instance.new("TextLabel")
	tempo.Size = UDim2.fromOffset(40, 18)
	tempo.Position = UDim2.new(1, -44, 0, 4)
	tempo.BackgroundTransparency = 1
	tempo.Font = Enum.Font.GothamBlack
	tempo.TextSize = 14
	tempo.TextColor3 = Color3.fromRGB(255, 220, 120)
	tempo.TextXAlignment = Enum.TextXAlignment.Right
	tempo.ZIndex = 4
	tempo.Text = ""
	tempo.Parent = f

	local cadeado = Instance.new("TextLabel")
	cadeado.Size = UDim2.fromScale(1, 1)
	cadeado.BackgroundColor3 = Color3.new(0, 0, 0)
	cadeado.BackgroundTransparency = 0.45
	cadeado.Font = Enum.Font.GothamBlack
	cadeado.TextSize = 20
	cadeado.Text = "🔒"
	cadeado.TextColor3 = Color3.new(1, 1, 1)
	cadeado.ZIndex = 5
	cadeado.Visible = false
	cadeado.Parent = f

	slots[i] = { frame = f, stroke = stroke, nome = nome, custo = custo, sombra = sombra, tempo = tempo, cadeado = cadeado }
end

-- painel POWERS: caminho do clã
local painel = Instance.new("Frame")
painel.AnchorPoint = Vector2.new(0.5, 0.5)
painel.Position = UDim2.fromScale(0.5, 0.5)
painel.Size = UDim2.fromOffset(460, 330)
painel.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
painel.Visible = false
painel.Parent = gui
Instance.new("UICorner", painel).CornerRadius = UDim.new(0, 14)
local painelBorda = Instance.new("UIStroke", painel)
painelBorda.Color = Color3.fromRGB(255, 140, 40)
painelBorda.Thickness = 2
local titulo = Instance.new("TextLabel")
titulo.Size = UDim2.new(1, -60, 0, 30)
titulo.Position = UDim2.fromOffset(16, 10)
titulo.BackgroundTransparency = 1
titulo.Font = Enum.Font.GothamBlack
titulo.TextSize = 20
titulo.TextColor3 = Color3.new(1, 1, 1)
titulo.TextXAlignment = Enum.TextXAlignment.Left
titulo.Parent = painel
local fechar = Instance.new("TextButton")
fechar.Size = UDim2.fromOffset(32, 28)
fechar.Position = UDim2.new(1, -44, 0, 10)
fechar.BackgroundColor3 = Color3.fromRGB(40, 40, 52)
fechar.Text = "✕"
fechar.Font = Enum.Font.GothamBlack
fechar.TextSize = 14
fechar.TextColor3 = Color3.new(1, 1, 1)
fechar.Parent = painel
Instance.new("UICorner", fechar).CornerRadius = UDim.new(0, 8)
fechar.MouseButton1Click:Connect(function() painel.Visible = false end)

local linhas = {}
for i = 1, 3 do
	local l = Instance.new("Frame")
	l.Size = UDim2.new(1, -32, 0, 82)
	l.Position = UDim2.fromOffset(16, 48 + (i - 1) * 92)
	l.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
	l.Parent = painel
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 10)
	local k = Instance.new("TextLabel")
	k.Size = UDim2.fromOffset(40, 40)
	k.Position = UDim2.fromOffset(10, 21)
	k.BackgroundColor3 = Color3.fromRGB(50, 50, 66)
	k.Font = Enum.Font.GothamBlack
	k.TextSize = 18
	k.Text = KEYS[i]
	k.TextColor3 = Color3.new(1, 1, 1)
	k.Parent = l
	Instance.new("UICorner", k).CornerRadius = UDim.new(0, 8)
	local n = Instance.new("TextLabel")
	n.Size = UDim2.new(1, -70, 0, 20)
	n.Position = UDim2.fromOffset(60, 8)
	n.BackgroundTransparency = 1
	n.Font = Enum.Font.GothamBlack
	n.TextSize = 15
	n.TextColor3 = Color3.new(1, 1, 1)
	n.TextXAlignment = Enum.TextXAlignment.Left
	n.Parent = l
	local d = Instance.new("TextLabel")
	d.Size = UDim2.new(1, -70, 0, 30)
	d.Position = UDim2.fromOffset(60, 28)
	d.BackgroundTransparency = 1
	d.Font = Enum.Font.Gotham
	d.TextSize = 12
	d.TextWrapped = true
	d.TextColor3 = Color3.fromRGB(200, 200, 210)
	d.TextXAlignment = Enum.TextXAlignment.Left
	d.TextYAlignment = Enum.TextYAlignment.Top
	d.Parent = l
	local s = Instance.new("TextLabel")
	s.Size = UDim2.new(1, -70, 0, 16)
	s.Position = UDim2.fromOffset(60, 60)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.GothamBold
	s.TextSize = 12
	s.TextXAlignment = Enum.TextXAlignment.Left
	s.Parent = l
	linhas[i] = { nome = n, desc = d, status = s }
end

-- botão POWERS (ao lado do STATS)
local botaoPoderes = Instance.new("TextButton")
botaoPoderes.Name = "BotaoPoderes"
botaoPoderes.Size = UDim2.fromOffset(89, 34)
botaoPoderes.Position = UDim2.fromOffset(232, 53)
botaoPoderes.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
botaoPoderes.BackgroundTransparency = 0.1
botaoPoderes.Font = Enum.Font.GothamBlack
botaoPoderes.TextSize = 12
botaoPoderes.Text = "POWERS"
botaoPoderes.TextColor3 = Color3.new(1, 1, 1)
botaoPoderes.Visible = false
botaoPoderes.Parent = gui
Instance.new("UICorner", botaoPoderes).CornerRadius = UDim.new(0, 8)
local bpBorda = Instance.new("UIStroke", botaoPoderes)
bpBorda.Color = Color3.fromRGB(80, 80, 100)
bpBorda.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
botaoPoderes.MouseButton1Click:Connect(function() painel.Visible = not painel.Visible end)

local avisoAte = 0
local function mostrarAviso(t)
	aviso.Text = t
	avisoAte = os.clock() + 2.8
end

local function claAtual()
	local c = ClanPowers.Clans[estado.Cla]
	return c, estado.Cla
end

local function atualizar()
	local c, clan = claAtual()
	local jogando = player:GetAttribute("Jogando") == true
	barra.Visible = c ~= nil and jogando
	botaoPoderes.Visible = c ~= nil and jogando
	if not c then
		painel.Visible = false
		return
	end
	titulo.Text = clan:upper() .. " CLAN PATH"
	painelBorda.Color = c.Color
	for i = 1, 3 do
		local p = c.Powers[i]
		local ok = estado.Ok[i] == true
		local s = slots[i]
		s.nome.Text = p.Name
		s.custo.Text = p.Chakra .. " CP"
		s.stroke.Color = ok and c.Color or Color3.fromRGB(70, 70, 85)
		s.cadeado.Visible = not ok
		local l = linhas[i]
		l.nome.Text = p.Name .. "   ·   " .. p.Chakra .. " chakra   ·   " .. p.Cooldown .. "s"
		l.desc.Text = p.Desc
		if ok then
			l.status.Text = "UNLOCKED"
			l.status.TextColor3 = Color3.fromRGB(120, 230, 130)
		else
			l.status.Text = "🔒 " .. (estado.Motivo[i] or "")
			l.status.TextColor3 = Color3.fromRGB(255, 190, 90)
		end
	end
end

local function lerEstado()
	local raw = player:GetAttribute("PoderesEstado")
	if type(raw) == "string" and raw ~= "" then
		local ok, t = pcall(HttpService.JSONDecode, HttpService, raw)
		if ok and type(t) == "table" then
			estado = t
		end
	end
	atualizar()
end
player:GetAttributeChangedSignal("PoderesEstado"):Connect(function()
	readyAt = { 0, 0, 0 }
	lerEstado()
end)
player:GetAttributeChangedSignal("Jogando"):Connect(atualizar)
lerEstado()

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for i = 1, 3 do
		local left = readyAt[i] - now
		if left > 0 then
			slots[i].sombra.Size = UDim2.fromScale(1, math.clamp(left / total[i], 0, 1))
			slots[i].tempo.Text = tostring(math.ceil(left))
		else
			slots[i].sombra.Size = UDim2.fromScale(1, 0)
			slots[i].tempo.Text = ""
		end
	end
	local mx = math.max(player:GetAttribute("ChakraMax") or 100, 1)
	local cp = player:GetAttribute("Chakra") or mx
	chakraBarra.Size = UDim2.fromScale(math.clamp(cp / mx, 0, 1), 1)
	chakraTexto.Text = ("CHAKRA  %d / %d"):format(cp, mx)
	if now > avisoAte then
		aviso.Text = ""
	end
end)

---------------------------------------------------------------
-- Movimento de alguns poderes (feito aqui no cliente)
---------------------------------------------------------------

local function frente(root)
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	return look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
end

-- avança para a frente (Chidori, Passo Relâmpago, Presa sobre Presa...)
local function investida(dash)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	task.delay(dash.Delay or 0, function()
		local look = frente(root)
		local t0 = os.clock()
		while os.clock() - t0 < dash.Time and root.Parent do
			root.AssemblyLinearVelocity = look * dash.Speed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

local function nearestEnemy(root, maxDist)
	local look = frente(root)
	local best, bestScore
	for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
		local h = m:FindFirstChildOfClass("Humanoid")
		local r = m:FindFirstChild("HumanoidRootPart")
		if h and r and h.Health > 0 and not m:GetAttribute("Sumido") then
			local raio = math.max(m:GetAttribute("Raio") or 0, 0)
			local dir = (r.Position - root.Position) * Vector3.new(1, 0, 1)
			local d = dir.Magnitude
			if d <= maxDist + raio and math.abs(r.Position.Y - root.Position.Y) < 30 then
				local score = d - (d > 0.1 and dir.Unit:Dot(look) or 1) * 15
				if not bestScore or score < bestScore then
					best, bestScore = { root = r, raio = raio }, score
				end
			end
		end
	end
	return best
end

-- corre até o inimigo mais próximo (Esfera Espiral Gigante, Lótus)
local function irAteInimigo()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	task.delay(0.4, function()
		local alvo = nearestEnemy(root, 40)
		local dirBase = frente(root)
		local t0 = os.clock()
		while os.clock() - t0 < (alvo and 0.9 or 0.5) and root.Parent do
			local dir = dirBase
			if alvo then
				if not alvo.root.Parent then
					break
				end
				local to = (alvo.root.Position - root.Position) * Vector3.new(1, 0, 1)
				if to.Magnitude <= 4 + alvo.raio then
					break
				end
				dir = to.Unit
			end
			root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
			root.AssemblyLinearVelocity = dir * 75 + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

---------------------------------------------------------------
-- Usar poder
---------------------------------------------------------------

local function usar(slot)
	local c = claAtual()
	if not c then
		mostrarAviso("Spin the roulette to get a clan first.")
		return
	end
	local p = c.Powers[slot]
	if estado.Ok[slot] ~= true then
		mostrarAviso(p.Name .. " is locked. " .. (estado.Motivo[slot] or ""))
		return
	end
	if os.clock() < readyAt[slot] then
		return
	end
	if (player:GetAttribute("Chakra") or 0) < p.Chakra then
		mostrarAviso("Not enough chakra.")
		return
	end
	readyAt[slot] = os.clock() + p.Cooldown
	total[slot] = p.Cooldown
	useEvent:FireServer(slot)
	if p.Dash then
		investida(p.Dash)
	elseif p.Seek then
		irAteInimigo()
	end
end

local POS_TOQUE = {
	UDim2.new(1, -255, 1, -120),
	UDim2.new(1, -215, 1, -195),
	UDim2.new(1, -140, 1, -230),
}
-- Quando um botão de interação (ProximityPrompt) com a mesma tecla está na tela,
-- a tecla vai para ele (falar, treinar, coletar) e o poder não é usado.
local promptsNaTela = {}
local PPS = game:GetService("ProximityPromptService")
PPS.PromptShown:Connect(function(p) promptsNaTela[p] = true end)
PPS.PromptHidden:Connect(function(p) promptsNaTela[p] = nil end)
local function promptComTecla(tecla)
	for p in pairs(promptsNaTela) do
		if p.Parent and p.Enabled and p.KeyboardKeyCode == tecla then return true end
	end
	return false
end
for i = 1, 3 do
	ContextActionService:BindAction("Poder" .. i, function(_, state, input)
		if input and input.UserInputType == Enum.UserInputType.Keyboard and promptComTecla(input.KeyCode) then
			return Enum.ContextActionResult.Pass
		end
		if state == Enum.UserInputState.Begin then
			usar(i)
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode[KEYS[i]])
	ContextActionService:SetTitle("Poder" .. i, KEYS[i])
	ContextActionService:SetPosition("Poder" .. i, POS_TOQUE[i])
end

feedbackEvent.OnClientEvent:Connect(function(p)
	if p.msg then
		mostrarAviso(p.msg)
	end
	if p.slot then
		readyAt[p.slot] = os.clock() + p.cooldown
		if p.cooldown > 0 then
			total[p.slot] = p.cooldown
		end
	end
end)
