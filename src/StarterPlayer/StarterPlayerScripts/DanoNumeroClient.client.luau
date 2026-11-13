-- LocalScript: StarterPlayerScripts > DanoNumeroClient
-- Numeros de dano flutuantes. O servidor (CombatServer / AbilityServer) avisa so quem bateu: posicao, valor, cor e tipo.
--   tipo "soco" = branco, "jutsu" = cor do elemento (maior), "queima" = dano de queimadura (menor).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local evento = ReplicatedStorage:WaitForChild("DanoNumero")
local ativos = 0
local MAX_ATIVOS = 36 -- nao enche a tela quando um jutsu acerta muita gente

local TAMANHO = { soco = 30, jutsu = 38, queima = 24 }

evento.OnClientEvent:Connect(function(pos, valor, cor, tipo)
	if typeof(pos) ~= "Vector3" or type(valor) ~= "number" then return end
	if ativos >= MAX_ATIVOS then return end
	ativos += 1
	tipo = TAMANHO[tipo] and tipo or "soco"
	cor = typeof(cor) == "Color3" and cor or Color3.new(1, 1, 1)

	local ponto = Instance.new("Part")
	ponto.Anchored, ponto.CanCollide, ponto.CanQuery, ponto.CanTouch = true, false, false, false
	ponto.Transparency = 1
	ponto.Size = Vector3.new(0.2, 0.2, 0.2)
	ponto.Position = pos + Vector3.new((math.random() - 0.5) * 2.4, (math.random() - 0.5) * 0.8, (math.random() - 0.5) * 2.4)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 80)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 220
	bb.StudsOffsetWorldSpace = Vector3.new(0, 0, 0)
	bb.Parent = ponto

	local escala = Instance.new("UIScale")
	escala.Scale = 0.3
	escala.Parent = bb

	local tam = TAMANHO[tipo] + math.clamp(math.floor(math.log10(math.max(valor, 1)) * 7), 0, 20)
	local txt = Instance.new("TextLabel")
	txt.BackgroundTransparency = 1
	txt.Size = UDim2.fromScale(1, 1)
	txt.Font = Enum.Font.GothamBlack
	txt.TextSize = tam
	txt.Text = tostring(math.floor(valor + 0.5))
	-- jutsu e queimadura ficam na cor do elemento, um pouco mais clara para ler bem
	txt.TextColor3 = tipo == "soco" and Color3.new(1, 1, 1) or cor:Lerp(Color3.new(1, 1, 1), 0.25)
	txt.Parent = bb

	local borda = Instance.new("UIStroke")
	borda.Thickness = 3
	borda.Color = Color3.fromRGB(20, 12, 8)
	borda.Parent = txt

	ponto.Parent = workspace

	local sobe = tipo == "queima" and 3 or 5
	local dur = tipo == "queima" and 0.7 or 0.95
	TweenService:Create(escala, TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = tipo == "jutsu" and 1.25 or 1 }):Play()
	TweenService:Create(bb, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, sobe, 0) }):Play()
	task.delay(dur * 0.55, function()
		local fim = TweenInfo.new(dur * 0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(txt, fim, { TextTransparency = 1 }):Play()
		TweenService:Create(borda, fim, { Transparency = 1 }):Play()
	end)
	Debris:AddItem(ponto, dur + 0.1)
	task.delay(dur + 0.1, function() ativos -= 1 end)
end)
