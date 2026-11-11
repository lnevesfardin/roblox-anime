-- Script: ServerScriptService > ViagemServer
-- Lançamento do clone: um clone do jogador aparece atrás dele e o arremessa, como um canhão,
-- até o destino escolhido (TravelData). O servidor confere a recarga e conduz o voo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local TravelData = require(ReplicatedStorage:WaitForChild("TravelData"))

local travel = Instance.new("RemoteFunction")
travel.Name = "Travel"
travel.Parent = ReplicatedStorage

local proximo = {} -- [player] = os.clock() em que pode lançar de novo
local voando = {}

local function fumaca(pos)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2
	p.Position = pos
	p.Anchored = true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(240, 240, 240)
	p.Transparency = 0.2
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.5), { Size = Vector3.one * 9, Transparency = 1 }):Play()
	Debris:AddItem(p, 0.6)
end

local function criarClone(char, root)
	local ok, clone = pcall(function()
		char.Archivable = true
		local c = char:Clone()
		char.Archivable = false
		return c
	end)
	if not ok or not clone then return nil end
	clone.Name = "CloneLancador"
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("ForceField") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide, d.CanQuery, d.CanTouch = false, false, false
		end
	end
	local hum = clone:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	clone:PivotTo(root.CFrame * CFrame.new(0, 0, 2.4))
	clone.Parent = workspace
	fumaca(clone:GetPivot().Position)
	return clone
end

travel.OnServerInvoke = function(player, id)
	local destino = TravelData.Get(id)
	if not destino then
		return { ok = false, erro = "Unknown place." }
	end
	if player:GetAttribute("InRun") then
		return { ok = false, erro = "Not during a match." }
	end
	local agora = os.clock()
	if voando[player] then
		return { ok = false, erro = "Already flying." }
	end
	if (proximo[player] or 0) > agora then
		return { ok = false, erro = string.format("Wait %.0fs.", proximo[player] - agora) }
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or root.Anchored then
		return { ok = false, erro = "Can't travel right now." }
	end
	voando[player] = true
	proximo[player] = agora + TravelData.COOLDOWN

	task.spawn(function()
		-- chão do destino
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = workspace:Raycast(destino.Pos + Vector3.new(0, 60, 0), Vector3.new(0, -200, 0), params)
		local chao = hit and hit.Position or destino.Pos
		local altura = hum.HipHeight + root.Size.Y / 2 + 0.5
		local fim = chao + Vector3.new(0, altura, 0)
		pcall(function() player:RequestStreamAroundAsync(fim, 5) end)

		local clone = criarClone(char, root)
		task.wait(0.35) -- o clone "pega impulso"
		if not root.Parent then voando[player] = nil return end

		local p0 = root.Position
		local dist = (fim - p0).Magnitude
		local T = math.clamp(dist / 140, 1.2, 3.2)
		local H = math.clamp(dist * 0.22, 25, 120)
		local plano = Vector3.new(fim.X - p0.X, 0, fim.Z - p0.Z)
		local olhar = plano.Magnitude > 1 and plano.Unit or root.CFrame.LookVector
		root.Anchored = true
		local t = 0
		while t < T and root.Parent and hum.Health > 0 do
			t += RunService.Heartbeat:Wait()
			local a = math.min(t / T, 1)
			local pos = p0:Lerp(fim, a) + Vector3.new(0, 4 * H * a * (1 - a), 0)
			-- inclina o corpo: sobe de frente, desce apontando para o chão
			local inclina = math.rad(-60 + 120 * a)
			root.CFrame = CFrame.lookAt(pos, pos + olhar) * CFrame.Angles(inclina, 0, 0)
		end
		if root.Parent then
			root.CFrame = CFrame.lookAt(fim, fim + olhar)
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			root.Anchored = false
			fumaca(fim - Vector3.new(0, altura - 1, 0))
		end
		if clone then
			fumaca(clone:GetPivot().Position)
			clone:Destroy()
		end
		voando[player] = nil
	end)
	return { ok = true, espera = TravelData.COOLDOWN }
end

Players.PlayerRemoving:Connect(function(player)
	proximo[player] = nil
	voando[player] = nil
end)
