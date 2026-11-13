-- ModuleScript: ServerStorage > InimigoGolpe
-- Golpes dos inimigos humanoides (ondas, bandidos do acampamento e inimigos da floresta).
-- Mesmos efeitos dos socos do jogador (rastro em meia-lua, impacto, flash no alvo), em combo de 3 golpes
-- seguido de uma pausa: é a janela para o jogador revidar.
-- Uso:
--   local estado = InimigoGolpe.Novo()
--   if InimigoGolpe.Tentar(estado, model, root, alvoHum, dano, { Cor = Color3, Escala = 1 }) then ... end
--   InimigoGolpe.Interromper(estado)   -- quando o inimigo é atordoado por um golpe do jogador

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local InimigoGolpe = {}

-- cada golpe do combo: mult = parte do dano do inimigo, wait = tempo até o próximo golpe
InimigoGolpe.COMBO = {
	{ mult = 0.6, wait = 0.55 },
	{ mult = 0.6, wait = 0.55 },
	{ mult = 1.0, wait = 1.9 }, -- o último golpe é o mais forte; depois dele vem a pausa
}
InimigoGolpe.COR_PADRAO = Color3.fromRGB(255, 120, 90)
local COR_FINAL = Color3.fromRGB(255, 220, 140)

function InimigoGolpe.Novo()
	return { n = 0, proximo = 0, ultimo = 0 }
end

-- combo cortado: recomeça do primeiro golpe depois de um respiro curto
function InimigoGolpe.Interromper(estado, respiro)
	estado.n = 0
	estado.proximo = math.max(estado.proximo, os.clock() + (respiro or 0.6))
end

local function burst(pos, diametro, cor, tempo)
	local b = Instance.new("Part")
	b.Shape = Enum.PartType.Ball
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
	b.Material = Enum.Material.Neon
	b.Color = cor
	b.Transparency = 0.2
	b.Size = Vector3.one
	b.CFrame = CFrame.new(pos)
	b.Parent = workspace
	TweenService:Create(b, TweenInfo.new(tempo, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * diametro, Transparency = 1 }):Play()
	Debris:AddItem(b, tempo + 0.1)
end

-- rastro do golpe: meia-lua fina na frente do inimigo (n alterna o lado)
local function arco(root, n, final, cor, escala)
	local raio = (final and 4.2 or 3.3) * escala
	local altura = 0.7 * escala
	local inclin = math.rad((n % 2 == 0) and 32 or -32)
	local base = root.CFrame * CFrame.new(0, altura, -0.8) * CFrame.Angles(0, 0, inclin)
	local segs = 9
	for i = 0, segs - 1 do
		local a0 = math.rad(-75 + i * (150 / segs))
		local a1 = math.rad(-75 + (i + 1) * (150 / segs))
		local p0 = (base * CFrame.new(math.sin(a0) * raio, 0, -math.cos(a0) * raio)).Position
		local p1 = (base * CFrame.new(math.sin(a1) * raio, 0, -math.cos(a1) * raio)).Position
		local w = (0.1 + 0.32 * math.sin(math.pi * (i + 0.5) / segs)) * math.max(escala, 1)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
		p.Material = Enum.Material.Neon
		p.Color = cor
		p.Transparency = 0.3
		p.Size = Vector3.new(w, w * 0.5, (p1 - p0).Magnitude + 0.05)
		p.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
		p.Parent = workspace
		TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, i * 0.012),
			{ Transparency = 1, Size = p.Size * Vector3.new(0.4, 0.4, 1) }):Play()
		Debris:AddItem(p, 0.3)
	end
end

-- impacto no alvo: faísca + anel que abre + flash branco no personagem
local function impacto(pos, tamanho, cor, personagem)
	burst(pos, tamanho, cor, 0.16)
	local r = Instance.new("Part")
	r.Shape = Enum.PartType.Cylinder
	r.Anchored, r.CanCollide, r.CanQuery, r.CanTouch, r.CastShadow = true, false, false, false, false
	r.Material = Enum.Material.Neon
	r.Color = Color3.fromRGB(255, 255, 255)
	r.Transparency = 0.35
	r.Size = Vector3.new(0.15, 1, 1)
	r.CFrame = CFrame.new(pos) * CFrame.Angles(math.random() * 3, math.random() * 3, 0)
	r.Parent = workspace
	TweenService:Create(r, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, tamanho * 1.6, tamanho * 1.6), Transparency = 1 }):Play()
	Debris:AddItem(r, 0.3)
	if personagem then
		local hl = Instance.new("Highlight")
		hl.FillColor = Color3.new(1, 1, 1)
		hl.FillTransparency = 0.4
		hl.OutlineTransparency = 1
		hl.Parent = personagem
		Debris:AddItem(hl, 0.1)
	end
end

-- Dá o próximo golpe do combo se já passou o tempo. Devolve true se bateu.
-- opts.Cor = cor do rastro; opts.Escala = tamanho do inimigo (chefes são maiores).
function InimigoGolpe.Tentar(estado, model, root, alvoHum, dano, opts)
	local agora = os.clock()
	if agora < estado.proximo then return false end
	if not alvoHum or alvoHum.Health <= 0 then return false end
	opts = opts or {}
	local escala = opts.Escala or 1
	if agora - estado.ultimo > 1.6 then estado.n = 0 end -- ficou um tempo sem bater: combo recomeça
	estado.ultimo = agora
	estado.n += 1
	local passo = InimigoGolpe.COMBO[estado.n]
	local final = estado.n >= #InimigoGolpe.COMBO
	estado.proximo = agora + passo.wait
	if final then estado.n = 0 end

	local alvoRoot = alvoHum.Parent and alvoHum.Parent:FindFirstChild("HumanoidRootPart")
	if alvoRoot and root and root.Parent then
		-- vira de frente para o alvo antes de bater
		local dir = (alvoRoot.Position - root.Position) * Vector3.new(1, 0, 1)
		if dir.Magnitude > 0.1 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
		end
	end
	local cor = final and COR_FINAL or (opts.Cor or InimigoGolpe.COR_PADRAO)
	if root and root.Parent then arco(root, estado.n + 1, final, cor, escala) end
	alvoHum:TakeDamage(dano * passo.mult)
	if alvoRoot then
		impacto(alvoRoot.Position + Vector3.new(0, 0.5, 0), final and 3.2 or 2.4, Color3.fromRGB(255, 235, 180), alvoHum.Parent)
	end
	return true
end

return InimigoGolpe
