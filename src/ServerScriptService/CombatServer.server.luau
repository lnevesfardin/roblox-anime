-- Script: ServerScriptService > CombatServer
-- Ataque do jogador. O cliente só avisa "atacar"; o servidor decide quem leva dano.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

local attackEvent = Instance.new("RemoteEvent")
attackEvent.Name = "Attack"
attackEvent.Parent = ReplicatedStorage

local COOLDOWN = 0.5      -- segundos entre ataques
local RANGE = 9           -- alcance em studs
local CONE = 0.2          -- quanto maior, mais estreito o ataque à frente
local lastAttack = {}

attackEvent.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < COOLDOWN then
		return
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return
	end
	lastAttack[player] = now

	local damage = PlayerData.GetCombatStats(player).Damage
	local look = root.CFrame.LookVector

	for _, enemy in ipairs(CollectionService:GetTagged("Inimigo")) do
		local eh = enemy:FindFirstChildOfClass("Humanoid")
		local er = enemy:FindFirstChild("HumanoidRootPart")
		if eh and er and eh.Health > 0 then
			local offset = er.Position - root.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local reach = RANGE + (enemy:GetAttribute("Raio") or 0)
			if flat.Magnitude <= reach and (flat.Magnitude < 1 or flat.Unit:Dot(look) > CONE) then
				eh:TakeDamage(damage)
			end
		end
	end

	-- efeito visual simples do golpe
	local fx = Instance.new("Part")
	fx.Size = Vector3.new(7, 0.3, 6)
	fx.Material = Enum.Material.Neon
	fx.Color = Color3.fromRGB(255, 255, 255)
	fx.Transparency = 0.4
	fx.Anchored = true
	fx.CanCollide = false
	fx.CanQuery = false
	fx.CanTouch = false
	fx.CFrame = root.CFrame * CFrame.new(0, -0.5, -5)
	fx.Parent = workspace
	Debris:AddItem(fx, 0.15)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttack[player] = nil
end)
