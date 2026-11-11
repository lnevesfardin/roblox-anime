-- LocalScript: StarterPlayerScripts > NPCAnim
-- Animação por código dos bonecos da vila (tag "NPC"): respiração parado e balanço de braços e pernas andando.
-- Funciona em corpos R6 e R15, sem usar animações de terceiros.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local npcs = {}

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
	npcs[m] = { fase = math.random() * 6, peso = 0, off = math.random() * 6 }
end
for _, m in ipairs(CollectionService:GetTagged("NPC")) do
	entrar(m)
end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(entrar)
CollectionService:GetInstanceRemovedSignal("NPC"):Connect(function(m)
	npcs[m] = nil
end)

RunService.PreSimulation:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local olho = cam and cam.CFrame.Position
	for m, st in pairs(npcs) do
		local hrp = m:FindFirstChild("HumanoidRootPart")
		local hum = m:FindFirstChildOfClass("Humanoid")
		if hrp and hum and olho and (hrp.Position - olho).Magnitude < 150 then
			local j = st.j
			if not j or not j.RightShoulder or not j.RightShoulder.Parent then
				j = juntas(m)
				st.j = j
			end
			local v = hrp.AssemblyLinearVelocity
			local vel = Vector3.new(v.X, 0, v.Z).Magnitude
			local andando = vel > 0.6
			st.peso += ((andando and 1 or 0) - st.peso) * math.min(dt * 8, 1)
			if andando then
				st.fase += dt * 7
			end
			local a = math.sin(st.fase) * 0.65 * st.peso
			local resp = math.sin(os.clock() * 1.6 + st.off) * 0.035
			if hum.RigType == Enum.HumanoidRigType.R6 then
				if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(0, 0, a + resp) end
				if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(0, 0, a - resp) end
				if j.RightHip then j.RightHip.Transform = CFrame.Angles(0, 0, -a) end
				if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(0, 0, -a) end
			else
				if j.RightShoulder then j.RightShoulder.Transform = CFrame.Angles(a, 0, resp) end
				if j.LeftShoulder then j.LeftShoulder.Transform = CFrame.Angles(-a, 0, -resp) end
				if j.RightHip then j.RightHip.Transform = CFrame.Angles(-a, 0, 0) end
				if j.LeftHip then j.LeftHip.Transform = CFrame.Angles(a, 0, 0) end
				if j.RightKnee then j.RightKnee.Transform = CFrame.Angles(-math.max(a, 0) * 0.8, 0, 0) end
				if j.LeftKnee then j.LeftKnee.Transform = CFrame.Angles(-math.max(-a, 0) * 0.8, 0, 0) end
				if j.Waist then j.Waist.Transform = CFrame.Angles(resp * 0.5, 0, 0) end
			end
		end
	end
end)
