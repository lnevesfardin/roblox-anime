-- Script: ServerScriptService > MundoExtras
-- Monta, quando o servidor abre, as coisas do mundo que as missões usam:
--   * pontos de prática das naturezas (tag "Pratica", atributo "Natureza") na floresta de fora;
--   * o cemitério antigo na floresta de dentro, com o túmulo do Primeiro (mestre do clã Mokuton);
--   * o mestre de clã que não tem boneco no mapa: Kiro com o cachorro Aka (Inu). (O mestre Lee, Rokuro, é o Villager do mercado, já no mapa.)
-- Os lugares vêm de MissionData.Lugares; cada peça procura um pedaço de chão livre perto do ponto pedido.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")

local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local NatureData = require(ReplicatedStorage:WaitForChild("NatureData"))

local pasta = Instance.new("Folder")
pasta.Name = "MundoExtras"
pasta.Parent = workspace

local function peca(pai, nome, size, cf, cor, mat, forma)
	local p = Instance.new("Part")
	p.Name = nome
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = cor
	p.Material = mat or Enum.Material.Slate
	if forma then p.Shape = forma end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = pai
	return p
end
local function texto(p, face, txt, cor)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = txt
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextColor3 = cor or Color3.fromRGB(240, 225, 200)
	t.Parent = sg
end
local function luz(p, cor, alcance, brilho)
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness = cor, alcance, brilho
	l.Parent = p
end
local function disco(pai, nome, pos, diametro, altura, cor, mat)
	return peca(pai, nome, Vector3.new(altura, diametro, diametro), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), cor, mat, Enum.PartType.Cylinder)
end

-- chão livre mais perto de (x, z): sem tronco, pedra ou parede no caminho. Devolve a posição no chão
local function chaoLivre(x, z, folga)
	folga = folga or 5
	local function testa(px, pz)
		local hit = workspace:Raycast(Vector3.new(px, 7, pz), Vector3.new(0, -12, 0))
		if not hit or hit.Position.Y > 1.5 then return nil end
		if #workspace:GetPartBoundsInBox(CFrame.new(px, hit.Position.Y + 3.5, pz), Vector3.new(folga, 5, folga)) > 0 then return nil end
		return hit.Position
	end
	local p = testa(x, z)
	if p then return p end
	for raio = 5, 40, 5 do
		for a = 0, 315, 45 do
			p = testa(x + math.cos(math.rad(a)) * raio, z + math.sin(math.rad(a)) * raio)
			if p then return p end
		end
	end
	return Vector3.new(x, 0, z)
end

---------------------------------------------------------------
-- Pontos de prática das naturezas
---------------------------------------------------------------
local function pontoPratica(nat, lugarPos, nomeLugar)
	local t = NatureData.Tipos[nat]
	local chao = chaoLivre(lugarPos.X, lugarPos.Z, 12)
	local m = Instance.new("Model")
	m.Name = "Pratica_" .. nat
	local cor = t.Color
	local base = disco(m, "Base", chao + Vector3.new(0, 0.2, 0), 12, 0.4, Color3.fromRGB(70, 70, 75), Enum.Material.Slate)
	local anel = disco(m, "Anel", chao + Vector3.new(0, 0.42, 0), 9, 0.1, cor, Enum.Material.Neon)
	anel.Transparency = 0.35
	anel.CanCollide = false
	disco(m, "Miolo", chao + Vector3.new(0, 0.44, 0), 8, 0.1, Color3.fromRGB(45, 45, 50), Enum.Material.Slate).CanCollide = false
	luz(anel, cor, 14, 1.2)
	-- enfeite de cada natureza, atrás do ponto
	local c = CFrame.new(chao)
	if nat == "Fogo" then
		for a = 0, 300, 60 do
			peca(m, "PedraFogo", Vector3.new(1.4, 1, 1.4), c * CFrame.Angles(0, math.rad(a), 0) * CFrame.new(0, 0.6, -8), Color3.fromRGB(80, 75, 70))
		end
		local fogo = peca(m, "Fogo", Vector3.new(2.2, 3, 2.2), c * CFrame.new(0, 1.8, -8), Color3.fromRGB(255, 130, 40), Enum.Material.Neon)
		fogo.CanCollide = false
		luz(fogo, Color3.fromRGB(255, 150, 70), 22, 2)
		local pe = Instance.new("Fire")
		pe.Size, pe.Heat = 8, 12
		pe.Parent = fogo
	elseif nat == "Agua" then
		for i = -1, 1 do
			local gota = peca(m, "PilarAgua", Vector3.new(1.2, 5 + i, 1.2), c * CFrame.new(i * 3, 2.5, -7.5), Color3.fromRGB(80, 160, 255), Enum.Material.Glass)
			gota.Transparency = 0.4
		end
	elseif nat == "Terra" then
		for i, h in ipairs({ 6, 9, 5, 7 }) do
			peca(m, "Rocha", Vector3.new(3, h, 3), c * CFrame.new(-6 + i * 2.6, h / 2 - 0.5, -8) * CFrame.Angles(0, math.rad(i * 25), math.rad(i % 2 == 0 and 8 or -6)), Color3.fromRGB(125, 100, 70), Enum.Material.Rock)
		end
	elseif nat == "Raio" then
		peca(m, "Rocha", Vector3.new(6, 7, 6), c * CFrame.new(0, 3.5, -8), Color3.fromRGB(70, 70, 80), Enum.Material.Rock)
		local haste = peca(m, "ParaRaio", Vector3.new(0.5, 12, 0.5), c * CFrame.new(0, 13, -8), Color3.fromRGB(190, 190, 200), Enum.Material.Metal)
		local ponta = peca(m, "Faisca", Vector3.new(1.2, 1.2, 1.2), c * CFrame.new(0, 19.4, -8), Color3.fromRGB(255, 240, 120), Enum.Material.Neon, Enum.PartType.Ball)
		ponta.CanCollide = false
		luz(ponta, Color3.fromRGB(190, 220, 255), 26, 2.5)
		haste.CanCollide = false
	else -- Vento
		for _, x in ipairs({ -6, 0, 6 }) do
			peca(m, "Mastro", Vector3.new(0.4, 12, 0.4), c * CFrame.new(x, 6, -8), Color3.fromRGB(110, 80, 55), Enum.Material.Wood)
			local faixa = peca(m, "Faixa", Vector3.new(4, 1.2, 0.15), c * CFrame.new(x + 2.1, 10.8, -8) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(190, 245, 215), Enum.Material.Fabric)
			faixa.CanCollide = false
		end
	end
	-- placa
	local placa = peca(m, "Placa", Vector3.new(8, 2.6, 0.4), c * CFrame.new(8, 5, 2) * CFrame.Angles(0, math.rad(-35), 0), Color3.fromRGB(110, 80, 55), Enum.Material.WoodPlanks)
	peca(m, "PlacaPoste", Vector3.new(0.6, 5, 0.6), c * CFrame.new(8, 2.5, 2.3) * CFrame.Angles(0, math.rad(-35), 0), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		texto(placa, face, string.upper(t.Name) .. " PRACTICE\n" .. nomeLugar, cor)
	end
	m.PrimaryPart = base
	m:SetAttribute("Natureza", nat)
	m.Parent = pasta
	CollectionService:AddTag(m, "Pratica")
end

---------------------------------------------------------------
-- Cemitério antigo e o túmulo do Primeiro
---------------------------------------------------------------
local NOMES = { "Taro Ishida", "Mei Aoyama", "Goro Tanabe", "Rin Kusaka", "Daiki Mori", "Sora Hayami", "Kenzo Arai", "Yui Shibata",
	"Hideo Nagase", "Aya Furuta", "Jun Okabe", "Nao Sugita", "Toma Hirose", "Emi Kanda", "Shin Uehara", "Kaho Tsuda" }
local function cemiterio()
	local centro = MissionData.Lugares.Cemiterio.Pos
	local m = Instance.new("Model")
	m.Name = "Cemiterio"
	m.Parent = pasta
	local pedra = Color3.fromRGB(125, 125, 130)
	local rng = Random.new(77) -- sempre o mesmo cemitério
	local i = 0
	for linha = -1, 1 do
		for col = -3, 3 do
			if not (linha == 0 and math.abs(col) <= 1) then -- o meio fica para o túmulo grande
				i += 1
				local chao = chaoLivre(centro.X + col * 6.5, centro.Z + linha * 9, 3)
				local c = CFrame.new(chao) * CFrame.Angles(0, math.rad(rng:NextInteger(-8, 8)), 0)
				peca(m, "Cova", Vector3.new(3, 0.4, 5), c * CFrame.new(0, 0.2, 1.5), Color3.fromRGB(85, 70, 55), Enum.Material.Ground)
				local lapide = peca(m, "Lapide", Vector3.new(2.6, 3.2, 0.6), c * CFrame.new(0, 1.6, -1.2) * CFrame.Angles(math.rad(rng:NextInteger(-5, 5)), 0, math.rad(rng:NextInteger(-4, 4))), pedra, Enum.Material.Slate)
				texto(lapide, Enum.NormalId.Back, NOMES[(i - 1) % #NOMES + 1], Color3.fromRGB(40, 40, 45))
			end
		end
	end
	-- túmulo do Primeiro: pedra grande com uma árvore nascendo dele (o clã da madeira)
	local chao = chaoLivre(centro.X, centro.Z, 8)
	local c = CFrame.new(chao)
	local t = Instance.new("Model")
	t.Name = "TumuloPrimeiro"
	peca(t, "Base", Vector3.new(9, 1, 9), c * CFrame.new(0, 0.5, 0), Color3.fromRGB(100, 100, 108), Enum.Material.Cobblestone)
	peca(t, "Degrau", Vector3.new(6, 0.8, 6), c * CFrame.new(0, 1.4, 0), pedra, Enum.Material.Slate)
	local lapide = peca(t, "Lapide", Vector3.new(4, 6.5, 1.2), c * CFrame.new(0, 5, -1.5), Color3.fromRGB(150, 150, 158), Enum.Material.Marble)
	texto(lapide, Enum.NormalId.Back, "HASHIRO\nTHE FIRST\nWOOD SAGE", Color3.fromRGB(45, 80, 45))
	local tronco = peca(t, "Arvore", Vector3.new(1.2, 9, 1.2), c * CFrame.new(2.6, 5.5, -2.2) * CFrame.Angles(0, 0, math.rad(-8)), Color3.fromRGB(95, 65, 40), Enum.Material.Wood)
	tronco.CanCollide = false
	local copa = peca(t, "Copa", Vector3.new(8, 6, 8), c * CFrame.new(3.4, 11.5, -2.2), Color3.fromRGB(70, 150, 70), Enum.Material.Grass, Enum.PartType.Ball)
	copa.CanCollide = false
	for _, x in ipairs({ -3.4, 3.4 }) do
		local lanterna = peca(t, "Lanterna", Vector3.new(1, 1.4, 1), c * CFrame.new(x, 2.5, 2.4), Color3.fromRGB(255, 220, 150), Enum.Material.Neon)
		luz(lanterna, Color3.fromRGB(255, 210, 140), 16, 1.4)
		peca(t, "LanternaPe", Vector3.new(0.5, 1.8, 0.5), c * CFrame.new(x, 1.9 - 1, 2.4), pedra)
	end
	t.PrimaryPart = lapide
	t.Parent = pasta
	CollectionService:AddTag(t, "NPCParado")
end

---------------------------------------------------------------
-- Mestres de clã sem boneco no mapa
---------------------------------------------------------------
local function mestre(nome, x, z, olharPara, pele, corpo, pernas, enfeitar)
	local ok, m = pcall(function()
		local d = Instance.new("HumanoidDescription")
		d.HeadColor = pele
		d.TorsoColor = corpo
		d.LeftArmColor, d.RightArmColor = corpo, corpo
		d.LeftLegColor, d.RightLegColor = pernas, pernas
		return Players:CreateHumanoidModelFromDescription(d, Enum.HumanoidRigType.R15)
	end)
	if not ok or not m then
		warn("[MundoExtras] Não deu para criar " .. nome .. ": " .. tostring(m))
		return
	end
	m.Name = nome
	local root = m:WaitForChild("HumanoidRootPart")
	local hum = m:FindFirstChildOfClass("Humanoid")
	local chao = chaoLivre(x, z, 4)
	local pos = chao + Vector3.new(0, hum.HipHeight + root.Size.Y / 2, 0)
	m:PivotTo(CFrame.lookAt(pos, Vector3.new(olharPara.X, pos.Y, olharPara.Z)))
	root.Anchored = true
	hum.MaxHealth, hum.Health = math.huge, math.huge
	local head = m:FindFirstChild("Head")
	local function colar(nomePeca, size, offset, cor, forma, mat, base)
		base = base or head
		local p = Instance.new("Part")
		p.Name = nomePeca
		p.Size = size
		p.Color = cor
		p.Material = mat or Enum.Material.SmoothPlastic
		if forma then p.Shape = forma end
		p.CanCollide, p.Massless, p.CanQuery = false, true, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.CFrame = base.CFrame * offset
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = base, p
		w.Parent = p
		p.Parent = m
		return p
	end
	if head then
		local okEnfeite, erroEnfeite = pcall(enfeitar, m, colar, head)
		if not okEnfeite then warn("[MundoExtras] Enfeites de " .. nome .. ": " .. tostring(erroEnfeite)) end
	end
	m.Parent = pasta
	CollectionService:AddTag(m, "NPCParado")
	return m, chao
end

local function cachorro(pos, olharPara)
	local m = Instance.new("Model")
	m.Name = "Aka"
	local branco, marrom = Color3.fromRGB(240, 235, 225), Color3.fromRGB(150, 100, 60)
	local c = CFrame.lookAt(pos, Vector3.new(olharPara.X, pos.Y, olharPara.Z))
	local corpo = peca(m, "Corpo", Vector3.new(1.3, 1.2, 2.4), c * CFrame.new(0, 1.3, 0), branco, Enum.Material.SmoothPlastic)
	peca(m, "Cabeca", Vector3.new(1.2, 1.1, 1.2), c * CFrame.new(0, 2.1, -1.4), branco, Enum.Material.SmoothPlastic)
	peca(m, "Focinho", Vector3.new(0.6, 0.5, 0.6), c * CFrame.new(0, 1.9, -2.2), marrom, Enum.Material.SmoothPlastic)
	for _, x in ipairs({ -0.4, 0.4 }) do
		peca(m, "Orelha", Vector3.new(0.35, 0.7, 0.2), c * CFrame.new(x, 2.9, -1.3) * CFrame.Angles(0, 0, math.rad(x > 0 and -15 or 15)), marrom, Enum.Material.SmoothPlastic)
		for _, zz in ipairs({ -0.8, 0.8 }) do
			peca(m, "Pata", Vector3.new(0.4, 0.8, 0.4), c * CFrame.new(x, 0.4, zz), branco, Enum.Material.SmoothPlastic)
		end
	end
	peca(m, "Rabo", Vector3.new(0.3, 0.3, 1), c * CFrame.new(0, 1.9, 1.5) * CFrame.Angles(math.rad(35), 0, 0), branco, Enum.Material.SmoothPlastic)
	m.PrimaryPart = corpo
	m.Parent = pasta
end

---------------------------------------------------------------
-- Kiro (Inu): igual ao Kiba: cabelo castanho espetado, testeira de Konoha, presas vermelhas, jaqueta cinza e faixa na perna
---------------------------------------------------------------
local PecasNPC = ServerStorage:FindFirstChild("PecasNPC") -- pasta com o KibaHair (acessório do cabelo)
local function kibaEnfeites(m, colar, head)
	local hx, hy, hz = head.Size.X, head.Size.Y, head.Size.Z
	local pele = head.Color
	local jaqueta, cinza = Color3.fromRGB(84, 84, 94), Color3.fromRGB(140, 140, 150)
	local function glifo(p, txt, cor)
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		sg.PixelsPerStud = 80
		sg.Parent = p
		local t = Instance.new("TextLabel")
		t.Size = UDim2.fromScale(1, 1)
		t.BackgroundTransparency = 1
		t.Text = txt
		t.TextScaled = true
		t.Font = Enum.Font.GothamBlack
		t.TextColor3 = cor
		t.Parent = sg
	end
	-- cabelo: a peça da loja guardada em ServerStorage.PecasNPC.KibaHair (se faltar, monta com pontas)
	local molde = PecasNPC and PecasNPC:FindFirstChild("KibaHair")
	local fio = molde and molde:FindFirstChild("Handle")
	if fio then
		local h = fio:Clone()
		for _, c in ipairs(h:GetChildren()) do
			if c:IsA("Attachment") or c:IsA("TouchTransmitter") then c:Destroy() end
		end
		h.Name = "Cabelo"
		h.Anchored, h.CanCollide, h.CanQuery, h.CanTouch, h.Massless = false, false, false, false, true
		h.CFrame = head.CFrame * CFrame.new(0, hy * 0.36, hz * 0.34) * CFrame.Angles(math.rad(-6), 0, 0)
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, h
		w.Parent = h
		h.Parent = m
	else
		local marrom = Color3.fromRGB(70, 45, 30)
		colar("Cabelo", Vector3.new(hx * 1.12, hy * 0.5, hz * 1.12), CFrame.new(0, hy * 0.38, hz * 0.04), marrom, Enum.PartType.Ball, Enum.Material.Fabric)
		for i = 0, 6 do
			local a = math.rad(i * 51)
			colar("Ponta", Vector3.new(0.3, hy * 0.55, 0.3), CFrame.new(math.cos(a) * hx * 0.3, hy * 0.62, math.sin(a) * hz * 0.3) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), marrom, nil, Enum.Material.Fabric)
		end
	end
	-- testeira de Konoha: faixa azul-escura com a placa de metal e o símbolo da folha
	colar("Testeira", Vector3.new(hx * 1.07, hy * 0.24, hz * 1.07), CFrame.new(0, hy * 0.27, 0), Color3.fromRGB(26, 32, 58), nil, Enum.Material.Fabric)
	local placa = colar("TesteiraPlaca", Vector3.new(hx * 0.64, hy * 0.22, 0.1), CFrame.new(0, hy * 0.27, -hz * 0.55), Color3.fromRGB(190, 195, 205), nil, Enum.Material.Metal)
	glifo(placa, "@", Color3.fromRGB(40, 45, 60))
	-- as marcas vermelhas das presas (triângulos para baixo) nas bochechas
	for _, x in ipairs({ -1, 1 }) do
		local mk = colar("Marca", Vector3.new(hx * 0.26, hy * 0.32, 0.04), CFrame.new(x * hx * 0.3, -hy * 0.1, -hz * 0.505), Color3.fromRGB(200, 35, 40))
		mk.Transparency = 1
		glifo(mk, "\u{25BC}", Color3.fromRGB(200, 35, 40))
	end
	-- jaqueta aberta no peito (camisa de rede), zíper, cós claro, mãos e botas
	local torso, baixo = m:FindFirstChild("UpperTorso"), m:FindFirstChild("LowerTorso")
	if torso then
		local sx, sy, sz = torso.Size.X, torso.Size.Y, torso.Size.Z
		colar("Gola", Vector3.new(sx * 0.98, sy * 0.2, sz * 1.08), CFrame.new(0, sy * 0.42, 0), jaqueta, nil, Enum.Material.Fabric, torso)
		colar("Rede", Vector3.new(sx * 0.36, sy * 0.36, 0.06), CFrame.new(0, sy * 0.26, -sz * 0.5), Color3.fromRGB(150, 150, 156), nil, Enum.Material.DiamondPlate, torso)
		colar("Ziper", Vector3.new(0.09, sy * 0.62, 0.05), CFrame.new(0, -sy * 0.17, -sz * 0.51), Color3.fromRGB(200, 200, 208), nil, Enum.Material.Metal, torso)
	end
	if baixo then baixo.Color = cinza end
	for _, n in ipairs({ "LeftHand", "RightHand" }) do
		local p = m:FindFirstChild(n)
		if p then p.Color = pele end
	end
	for _, n in ipairs({ "LeftFoot", "RightFoot" }) do
		local p = m:FindFirstChild(n)
		if p then p.Color = Color3.fromRGB(62, 62, 72) end
	end
	-- faixa branca na perna direita
	local coxa = m:FindFirstChild("RightUpperLeg")
	if coxa then
		colar("FaixaPerna", Vector3.new(coxa.Size.X * 1.16, coxa.Size.Y * 0.5, coxa.Size.Z * 1.16), CFrame.new(0, -coxa.Size.Y * 0.1, 0), Color3.fromRGB(238, 238, 238), nil, Enum.Material.Fabric, coxa)
	end
	-- pose (mão direita na cintura, braço esquerdo apontando para frente): as peças ficam ancoradas já na posição.
	-- cada junta (Motor6D ou AnimationConstraint) leva a peça filha para: pai * C0 * rotação * C1^-1
	local function posar(nome, rot)
		local j = m:FindFirstChild(nome, true)
		if not j then return end
		local pai, filho, c0, c1
		if j:IsA("Motor6D") then
			pai, filho, c0, c1 = j.Part0, j.Part1, j.C0, j.C1
		elseif j:IsA("AnimationConstraint") and j.Attachment0 and j.Attachment1 then
			pai, filho, c0, c1 = j.Attachment0.Parent, j.Attachment1.Parent, j.Attachment0.CFrame, j.Attachment1.CFrame
		end
		if pai and filho then filho.CFrame = pai.CFrame * c0 * rot * c1:Inverse() end
	end
	posar("RightShoulder", CFrame.Angles(0, 0, math.rad(32)))
	posar("RightElbow", CFrame.Angles(0, 0, math.rad(-75)))
	posar("RightWrist", CFrame.identity)
	posar("LeftShoulder", CFrame.Angles(math.rad(80), 0, math.rad(-14)))
	posar("LeftElbow", CFrame.Angles(math.rad(-12), 0, 0))
	posar("LeftWrist", CFrame.identity)
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
end

---------------------------------------------------------------
-- Montagem
---------------------------------------------------------------
task.spawn(function()
	task.wait(2) -- deixa o mapa carregar antes de procurar chão livre
	for _, nat in ipairs(NatureData.Order) do
		local lugar = MissionData.Lugares["Pratica_" .. nat]
		if lugar then pontoPratica(nat, lugar.Pos, lugar.Name) end
		for _, extra in ipairs(MissionData.PraticaExtra[nat] or {}) do
			pontoPratica(nat, extra, "Forest Fire Pit")
		end
	end
	cemiterio()
	local pele = Color3.fromRGB(235, 195, 160)
	-- Kiro (Inu): vestido como o Kiba, com o cachorro Aka ao lado
	local praca = MissionData.Lugares.Praca.Pos
	local _, chao = mestre("MestreInu", 85, 5, praca, pele, Color3.fromRGB(84, 84, 94), Color3.fromRGB(58, 64, 82), kibaEnfeites)
	if chao then
		local p = chaoLivre(chao.X + 3.5, chao.Z + 1, 3)
		cachorro(p, praca)
	end
end)
