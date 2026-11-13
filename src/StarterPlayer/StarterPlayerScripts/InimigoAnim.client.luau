-- LocalScript: StarterPlayerScripts > InimigoAnim
-- Animação por código dos inimigos (tag "Inimigo"): balanço de braços e pernas andando e soco quando o servidor
-- (InimigoGolpe) marca o atributo GolpeT. Não depende de animações de terceiros e funciona em R6 e R15.
-- GolpeN = golpe do combo (1, 2 e 3): ímpar = braço direito, par = esquerdo, 3º = os dois braços (golpe forte).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local DURACAO = 0.32 -- segundos do soco
local inimigos = {}

local function juntas(m)
	local j = {}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Motor6D") then
			j[(d.Name:gsub(" ", ""))] = d
		end
	end
	return j
end

local function entrar(m)
	inimigos[m] = { fase = math.random() * 6, peso = 0 }
end
for _, m in ipairs(CollectionService:GetTagged("Inimigo")) do
	entrar(m)
end
CollectionService:GetInstanceAddedSignal("Inimigo"):Connect(entrar)
CollectionService:GetInstanceRemovedSignal("Inimigo"):Connect(function(m)
	inimigos[m] = nil
end)

-- 0 a 1 a 0 durante o soco (sobe rápido, volta devagar)
local function pulso(m)
	local t = m:GetAttribute("GolpeT")
	if not t then return 0, 0 end
	local idade = workspace:GetServerTimeNow() - t
	if idade < 0 or idade > DURACAO then return 0, 0 end
	local x = idade / DURACAO
	return (x < 0.3) and (x / 0.3) or (1 - (x - 0.3) / 0.7), m:GetAttribute("GolpeN") or 1
end

RunService.PreRender:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local olho = cam and cam.CFrame.Position
	for m, st in pairs(inimigos) do
		local hrp = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hrp and hum and olho and hum.Health > 0 and (hrp.Position - olho).Magnitude < 160 then
			local j = st.j
			if not j or not j.RightShoulder or not j.RightShoulder.Parent then
				j = juntas(m)
				st.j = j
			end
			local v = hrp.AssemblyLinearVelocity
			local vel = Vector3.new(v.X, 0, v.Z).Magnitude
			local andando = vel > 0.8
			st.peso += ((andando and 1 or 0) - st.peso) * math.min(dt * 8, 1)
			if andando then
				st.fase += dt * math.clamp(vel * 0.5, 4, 9)
			end
			local a = math.sin(st.fase) * 0.75 * st.peso
			local resp = math.sin(os.clock() * 1.6 + st.fase) * 0.03
			local p, n = pulso(m)
			local dir = (n % 2 == 1 or n == 3) and p or 0 -- braço direito
			local esq = (n % 2 == 0 or n == 3) and p or 0 -- braço esquerdo
			local giro = (n == 3 and 0.5 or 0.3) * p * ((n % 2 == 1) and -1 or 1)
			if hum.RigType == Enum.HumanoidRigType.R6 then
				if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(0, 0, a * (1 - p) + dir * 1.7) end
				if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(0, 0, a * (1 - p) - esq * 1.7) end
				if j.RightHip then j.RightHip.Transform = CFrame.Angles(0, 0, -a) end
				if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(0, 0, -a) end
				if j.Neck and p > 0 then j.Neck.Transform = CFrame.Angles(0, 0, 0) end
			else
				if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(a * (1 - p) + dir * 1.55, 0, resp) end
				if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(-a * (1 - p) + esq * 1.55, 0, -resp) end
				if j.RightElbow then j.RightElbow.Transform = CFrame.Angles(-0.25 - dir * 0.3, 0, 0) end
				if j.LeftElbow then j.LeftElbow.Transform = CFrame.Angles(-0.25 - esq * 0.3, 0, 0) end
				if j.RightHip then j.RightHip.Transform = CFrame.Angles(-a, 0, 0) end
				if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(a, 0, 0) end
				if j.RightKnee then j.RightKnee.Transform = CFrame.Angles(-math.max(a, 0) * 0.8, 0, 0) end
				if j.LeftKnee then j.LeftKnee.Transform = CFrame.Angles(-math.max(-a, 0) * 0.8, 0, 0) end
				if j.Waist then j.Waist.Transform = CFrame.Angles(resp * 0.5 + p * 0.12, giro, 0) end
			end
		end
	end
end)
