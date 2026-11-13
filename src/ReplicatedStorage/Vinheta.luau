-- ModuleScript: ReplicatedStorage > Vinheta
-- Vinhetas de tela cheia (só no cliente):
--   Vinheta.Abertura()                    -> ao abrir o jogo: logo SHINOBI LEGENDS com cortes, folhas e clarão (~3,5 s)
--   Vinheta.Revelar(titulo, sub, cor, raro) -> revelação de um resultado (Kekkei Genkai, natureza, clã) (~2,4 s)
-- As duas esperam terminar (chame dentro de task.spawn se não quiser esperar). Clique ou toque pula.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Vinheta = {}

local player = Players.LocalPlayer

local function new(cls, props)
	local o = Instance.new(cls)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function tween(o, t, props, estilo, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, estilo or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function som(nome)
	local s = SoundService:FindFirstChild("Sons") and SoundService.Sons:FindFirstChild(nome)
	if s then SoundService:PlayLocalSound(s) end
end

local function tela()
	local gui = new("ScreenGui", { Name = "VinhetaUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 60,
		Parent = player:WaitForChild("PlayerGui") })
	local fundo = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = gui })
	return gui, fundo
end

-- espera t segundos ou até o jogador clicar (pular)
local function esperar(t, estado)
	local fim = os.clock() + t
	while os.clock() < fim and not estado.pulou do
		task.wait()
	end
end
local function permitirPular(estado)
	return UserInputService.InputBegan:Connect(function(input)
		local tipo = input.UserInputType
		if tipo == Enum.UserInputType.MouseButton1 or tipo == Enum.UserInputType.Touch or input.KeyCode == Enum.KeyCode.Space then
			estado.pulou = true
		end
	end)
end

-- corte de pincel atravessando a tela
local function corte(pai, cor, y, angulo, atraso, espessura)
	local c = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, y), Size = UDim2.new(0, 0, 0, espessura or 10),
		Rotation = angulo, BackgroundColor3 = cor, BorderSizePixel = 0, ZIndex = 2, Parent = pai })
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = c })
	task.delay(atraso or 0, function()
		tween(c, 0.22, { Size = UDim2.new(1.6, 0, 0, espessura or 10) }, Enum.EasingStyle.Quart)
	end)
	return c
end

-- pedacinhos (folhas / faíscas) voando a partir do centro
local function particulas(pai, cor, qtd, raio)
	for _ = 1, qtd do
		local tam = math.random(6, 14)
		local p = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(tam, tam * 0.55),
			Rotation = math.random(0, 360), BackgroundColor3 = cor, BorderSizePixel = 0, ZIndex = 4, Parent = pai })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = p })
		local ang = math.random() * math.pi * 2
		local d = (raio or 0.45) * (0.4 + math.random() * 0.8)
		tween(p, 0.9 + math.random() * 0.5, { Position = UDim2.fromScale(0.5 + math.cos(ang) * d, 0.5 + math.sin(ang) * d * 1.4),
			Rotation = p.Rotation + math.random(-200, 200), BackgroundTransparency = 1 })
	end
end

local function clarao(pai)
	local f = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 8, Parent = pai })
	tween(f, 0.45, { BackgroundTransparency = 1 })
end

local function tremer(o, base, forca, dur)
	task.spawn(function()
		local fim = os.clock() + dur
		while os.clock() < fim and o.Parent do
			o.Position = base + UDim2.fromOffset(math.random(-forca, forca), math.random(-forca, forca))
			task.wait(0.03)
		end
		if o.Parent then o.Position = base end
	end)
end

function Vinheta.Abertura()
	local estado = {}
	local gui, fundo = tela()
	local pular = permitirPular(estado)
	local LARANJA = Color3.fromRGB(255, 140, 40)
	local VERMELHO = Color3.fromRGB(215, 45, 45)

	-- faixas de cinema
	local cima = new("Frame", { Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, -0.12), BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BorderSizePixel = 0, ZIndex = 6, Parent = fundo })
	local baixo = new("Frame", { Size = UDim2.new(1, 0, 0.12, 0), Position = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BorderSizePixel = 0, ZIndex = 6, Parent = fundo })
	tween(cima, 0.4, { Position = UDim2.fromScale(0, 0) })
	tween(baixo, 0.4, { Position = UDim2.fromScale(0, 0.88) })

	-- emblema: círculo girando atrás do nome
	local emblema = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(0, 0),
		BackgroundTransparency = 1, ZIndex = 1, Parent = fundo })
	new("UIAspectRatioConstraint", { Parent = emblema })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = emblema })
	local anel = new("UIStroke", { Color = LARANJA, Thickness = 6, Transparency = 0.2, Parent = emblema })
	local anel2 = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78),
		BackgroundTransparency = 1, ZIndex = 1, Parent = emblema })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = anel2 })
	new("UIStroke", { Color = VERMELHO, Thickness = 3, Transparency = 0.35, Parent = anel2 })

	esperar(0.35, estado)
	som("Giro")
	corte(fundo, VERMELHO, 0.40, -9, 0, 12)
	corte(fundo, LARANJA, 0.55, 7, 0.12, 8)
	tween(emblema, 0.6, { Size = UDim2.fromScale(0.42, 0.42) }, Enum.EasingStyle.Back)
	task.spawn(function()
		while emblema.Parent do
			emblema.Rotation += 1.2
			task.wait()
		end
	end)
	esperar(0.45, estado)

	-- nome: SHINOBI entra pela esquerda, LEGENDS pela direita
	local s1 = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.3, 0.42), Size = UDim2.fromScale(0.8, 0.14),
		BackgroundTransparency = 1, Text = "SHINOBI", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = 5, Parent = fundo })
	new("UIStroke", { Color = VERMELHO, Thickness = 3, Parent = s1 })
	local s2 = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1.3, 0.56), Size = UDim2.fromScale(0.8, 0.14),
		BackgroundTransparency = 1, Text = "LEGENDS", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = LARANJA, ZIndex = 5, Parent = fundo })
	new("UIStroke", { Color = Color3.fromRGB(60, 20, 10), Thickness = 3, Parent = s2 })
	tween(s1, 0.35, { Position = UDim2.fromScale(0.5, 0.42) }, Enum.EasingStyle.Back)
	tween(s2, 0.35, { Position = UDim2.fromScale(0.5, 0.56) }, Enum.EasingStyle.Back)
	esperar(0.35, estado)
	som("Revelar")
	clarao(fundo)
	particulas(fundo, Color3.fromRGB(110, 190, 80), 18, 0.5)
	particulas(fundo, LARANJA, 14, 0.45)
	tremer(s1, UDim2.fromScale(0.5, 0.42), 6, 0.3)
	tremer(s2, UDim2.fromScale(0.5, 0.56), 6, 0.3)
	local sub = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.67), Size = UDim2.fromScale(0.6, 0.04),
		BackgroundTransparency = 1, Text = "THE PATH OF THE NINJA", Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(220, 210, 200),
		TextTransparency = 1, ZIndex = 5, Parent = fundo })
	tween(sub, 0.6, { TextTransparency = 0 })
	esperar(1.6, estado)

	-- some tudo
	for _, d in ipairs(fundo:GetDescendants()) do
		if d:IsA("TextLabel") then tween(d, 0.5, { TextTransparency = 1 }) end
		if d:IsA("UIStroke") then tween(d, 0.5, { Transparency = 1 }) end
		if d:IsA("Frame") then tween(d, 0.5, { BackgroundTransparency = 1 }) end
	end
	tween(fundo, 0.6, { BackgroundTransparency = 1 })
	task.wait(0.6)
	pular:Disconnect()
	gui:Destroy()
end

-- revelação de um resultado: cortes na cor, título que bate na tela, clarão e partículas
function Vinheta.Revelar(titulo, sub, cor, raro)
	local estado = {}
	cor = cor or Color3.fromRGB(255, 140, 40)
	local gui, fundo = tela()
	fundo.BackgroundTransparency = 1
	tween(fundo, 0.25, { BackgroundTransparency = 0.15 })
	local pular = permitirPular(estado)

	local faixa = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14), BorderSizePixel = 0, ZIndex = 1, Parent = fundo })
	new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(10, 10, 14), cor:Lerp(Color3.new(0, 0, 0), 0.6)), Rotation = 90, Parent = faixa })
	tween(faixa, 0.3, { Size = UDim2.new(1, 0, 0.34, 0) }, Enum.EasingStyle.Quart)
	esperar(0.2, estado)
	som("Giro")
	corte(fundo, cor, 0.36, -6, 0, 6)
	corte(fundo, Color3.new(1, 1, 1), 0.64, -6, 0.08, 4)
	esperar(0.25, estado)

	local t = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromScale(0.85, 0.15),
		BackgroundTransparency = 1, Text = string.upper(titulo or ""), Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = cor,
		TextTransparency = 1, ZIndex = 5, Parent = fundo })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, Parent = t })
	local escala = new("UIScale", { Scale = 2.6, Parent = t })
	tween(t, 0.18, { TextTransparency = 0 })
	tween(escala, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	esperar(0.26, estado)
	som(raro and "RevelarRaro" or "Revelar")
	clarao(fundo)
	particulas(fundo, cor, raro and 30 or 18, 0.5)
	if raro then particulas(fundo, Color3.new(1, 1, 1), 14, 0.4) end
	tremer(t, UDim2.fromScale(0.5, 0.47), raro and 9 or 5, 0.3)
	if sub and sub ~= "" then
		local s = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.585), Size = UDim2.fromScale(0.6, 0.045),
			BackgroundTransparency = 1, Text = string.upper(sub), Font = Enum.Font.GothamBold, TextScaled = true, TextColor3 = Color3.fromRGB(235, 230, 225),
			TextTransparency = 1, ZIndex = 5, Parent = fundo })
		tween(s, 0.4, { TextTransparency = 0 })
	end
	esperar(raro and 1.5 or 1.15, estado)

	for _, d in ipairs(fundo:GetDescendants()) do
		if d:IsA("TextLabel") then tween(d, 0.35, { TextTransparency = 1 }) end
		if d:IsA("UIStroke") then tween(d, 0.35, { Transparency = 1 }) end
		if d:IsA("Frame") then tween(d, 0.35, { BackgroundTransparency = 1 }) end
	end
	tween(fundo, 0.4, { BackgroundTransparency = 1 })
	task.wait(0.4)
	pular:Disconnect()
	gui:Destroy()
end

return Vinheta
