-- Script: ServerScriptService > NPCServer
-- Bonecos da vila (tag "NPC"): ficam em pé, passeiam perto de casa e olham para o jogador que chega perto.
-- A animação de andar é feita no cliente (NPCAnim), por código.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local RAIO = 10 -- distância máxima de passeio a partir da "Casa"
local rng = Random.new()

local function jogadorPerto(pos, dist)
	for _, p in ipairs(Players:GetPlayers()) do
		local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - pos).Magnitude < dist then
			return r
		end
	end
	return nil
end

local function cuidar(m)
	local hum = m:FindFirstChildOfClass("Humanoid")
	local hrp = m:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then
		return
	end
	-- a "casa" é onde o boneco foi deixado no Studio: ele passeia em volta desse ponto
	local casa = hrp.Position
	-- não deixa o boneco tombar nem mudar de tamanho
	hum.AutomaticScalingEnabled = false
	hum.BreakJointsOnDeath = false
	for _, e in ipairs({ "FallingDown", "Ragdoll", "Climbing", "Swimming", "Dead" }) do
		hum:SetStateEnabled(Enum.HumanoidStateType[e], false)
	end
	hum.MaxHealth = math.huge
	hum.Health = math.huge
	hum.WalkSpeed = 6
	hrp.Anchored = false
	pcall(function()
		hrp:SetNetworkOwner(nil)
	end)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude

	task.spawn(function()
		task.wait(rng:NextNumber(0, 4))
		while m.Parent and hum.Parent do
			local pos = hrp.Position
			-- caiu do mapa ou foi empurrado para longe: volta para casa
			if pos.Y < casa.Y - 15 or (pos - casa).Magnitude > RAIO * 4 then
				m:PivotTo(CFrame.new(casa))
				hrp.AssemblyLinearVelocity = Vector3.zero
			end
			local perto = jogadorPerto(pos, 9)
			if perto then
				-- para e vira para o jogador
				hum:MoveTo(pos)
				local alvo = Vector3.new(perto.Position.X, pos.Y, perto.Position.Z)
				if (alvo - pos).Magnitude > 0.5 then
					hrp.CFrame = hrp.CFrame:Lerp(CFrame.lookAt(pos, alvo), 0.5)
				end
				task.wait(0.4)
			else
				local ang = rng:NextNumber(0, math.pi * 2)
				local destino = casa + Vector3.new(math.cos(ang), 0, math.sin(ang)) * rng:NextNumber(3, RAIO)
				params.FilterDescendantsInstances = CollectionService:GetTagged("NPC")
				local livre = not workspace:Raycast(pos, destino - pos, params)
				local chao = workspace:Raycast(destino + Vector3.new(0, 4, 0), Vector3.new(0, -10, 0), params)
				if livre and chao then
					hum:MoveTo(destino)
					local t0 = os.clock()
					while os.clock() - t0 < 5 and (hrp.Position - destino).Magnitude > 2 and not jogadorPerto(hrp.Position, 9) do
						task.wait(0.25)
					end
					hum:MoveTo(hrp.Position)
				end
				task.wait(rng:NextNumber(3, 8))
			end
		end
	end)
end

for _, m in ipairs(CollectionService:GetTagged("NPC")) do
	task.spawn(cuidar, m)
end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(cuidar)
