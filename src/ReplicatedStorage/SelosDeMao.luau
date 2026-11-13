-- ModuleScript: ReplicatedStorage > SelosDeMao
-- Selos de mão antes de todo jutsu: o personagem junta as mãos na frente do peito, troca de selo algumas
-- vezes e estica os braços; só então o jutsu sai (a função aoSoltar é chamada nesse momento).
-- Roda só no cliente de quem lança. A pose vai no Transform das juntas, depois da animação do Roblox
-- (PreSimulation), então vale tanto nas juntas antigas (Motor6D) quanto nas novas (AnimationConstraint).
-- Uso: if not Selos.Ativo() then Selos.Fazer(cor, function() useEvent:FireServer(slot) end) end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local Selos = {}

Selos.SOLTAR_EM = 0.62 -- segundos até o jutsu sair
local DURACAO = 0.8    -- segundos até o corpo voltar ao normal
local COR_PADRAO = Color3.fromRGB(90, 180, 255)

-- pose = ombro x (para frente) e z (para dentro), cotovelo, pulso, cintura e pescoço, em graus.
-- Direita e esquerda são espelhadas. Ordem do CFrame.Angles: o z (para dentro) vem primeiro, depois o x (para frente).
local function pose(ox, oz, cot, pul, cin, pes)
	return {
		RightShoulder = Vector3.new(ox, 0, -oz), LeftShoulder = Vector3.new(ox, 0, oz),
		RightElbow = Vector3.new(cot, 0, 0), LeftElbow = Vector3.new(cot, 0, 0),
		RightWrist = Vector3.new(pul, 0, 0), LeftWrist = Vector3.new(-pul, 0, 0),
		Waist = Vector3.new(cin, 0, 0), Neck = Vector3.new(pes, 0, 0),
	}
end

local QUADROS = {
	{ t = 0.00, p = pose(0, 0, 0, 0, 0, 0) },
	{ t = 0.14, p = pose(90, 50, 50, 0, -4, 0) },    -- selo 1: mãos juntas no peito (medido no R15: mãos a ~0.3 studs uma da outra)
	{ t = 0.28, p = pose(120, 40, 30, 0, -6, -5) },  -- selo 2: mãos mais altas, perto do queixo
	{ t = 0.42, p = pose(70, 50, 50, 0, -3, 3) },    -- selo 3: mãos baixas, na altura do estômago
	{ t = 0.54, p = pose(90, 50, 50, 0, -5, -2) },   -- selo 4 (segura um instante)
	{ t = 0.68, p = pose(96, 6, 16, 0, -16, 6) },    -- solta: braços esticados para frente
	{ t = 1.00, p = pose(96, 6, 16, 0, -16, 6) },
}

local JUNTAS = { "RightShoulder", "LeftShoulder", "RightElbow", "LeftElbow", "RightWrist", "LeftWrist", "Waist", "Neck" }

local function suave(a) return a * a * (3 - 2 * a) end

local function amostra(t)
	for i = 2, #QUADROS do
		local b = QUADROS[i]
		if t <= b.t then
			local a = QUADROS[i - 1]
			local f = suave((t - a.t) / (b.t - a.t))
			local r = {}
			for nome, va in pairs(a.p) do
				r[nome] = va:Lerp(b.p[nome], f)
			end
			return r
		end
	end
	return QUADROS[#QUADROS].p
end

local ativo = false

function Selos.Ativo()
	return ativo
end

-- cor = cor do jutsu (faíscas nas mãos). aoSoltar roda quando os braços se estendem. Devolve false se já está fazendo selos.
function Selos.Fazer(cor, aoSoltar)
	if ativo then return false end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then return false end
	cor = cor or COR_PADRAO

	local juntas = {}
	if hum.RigType == Enum.HumanoidRigType.R15 then
		for _, d in ipairs(char:GetDescendants()) do
			if (d:IsA("Motor6D") or d:IsA("AnimationConstraint")) and table.find(JUNTAS, d.Name) then
				juntas[d.Name] = d
			end
		end
	end

	ativo = true
	player:SetAttribute("Selos", true) -- o CombatClient solta a pose de corrida enquanto isso
	local extras = {}
	local function limpar()
		for _, o in ipairs(extras) do
			if o.Parent then o:Destroy() end
		end
		extras = {}
	end

	-- faíscas de chakra nas duas mãos
	for _, nome in ipairs({ "RightHand", "LeftHand" }) do
		local mao = char:FindFirstChild(nome)
		if mao then
			local pe = Instance.new("ParticleEmitter")
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(cor, Color3.new(1, 1, 1))
			pe.LightEmission = 1
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
			pe.Lifetime = NumberRange.new(0.25, 0.45)
			pe.Speed = NumberRange.new(1, 3)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Rate = 45
			pe.Parent = mao
			table.insert(extras, pe)
		end
	end

	local t0 = os.clock()
	local soltou = false
	local conexao
	local function fim()
		if conexao then conexao:Disconnect() conexao = nil end
		ativo = false
		player:SetAttribute("Selos", nil)
		limpar()
	end

	conexao = RunService.PreSimulation:Connect(function()
		local t = os.clock() - t0
		if not char.Parent or hum.Health <= 0 then
			fim()
			return
		end
		if not soltou and t >= Selos.SOLTAR_EM then
			soltou = true
			for _, o in ipairs(extras) do
				if o:IsA("ParticleEmitter") then o:Emit(14) o.Rate = 0 end
			end
			if aoSoltar then task.spawn(aoSoltar) end
		end
		if t >= DURACAO then
			fim()
			return
		end
		-- entra e sai da pose suavemente
		local w = math.clamp(t / 0.08, 0, 1) * (1 - math.clamp((t - (DURACAO - 0.1)) / 0.1, 0, 1))
		local p = amostra(t)
		for nome, j in pairs(juntas) do
			local v = p[nome]
			if v and j.Parent then
				local alvo = CFrame.Angles(math.rad(v.X), math.rad(v.Y), math.rad(v.Z))
				j.Transform = j.Transform:Lerp(alvo, w)
			end
		end
	end)

	-- sem as juntas do R15 (R6, por exemplo) não há pose, mas o jutsu sai no mesmo tempo
	return true
end

return Selos
