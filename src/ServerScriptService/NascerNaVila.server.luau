-- Script: ServerScriptService > NascerNaVila
-- Garante que todo jogador nasce no centro da praça da vila
-- (evita nascer no céu ou fora do lugar ao entrar ou voltar de uma partida).

local Players = game:GetService("Players")
local spawn = workspace:WaitForChild("SpawnLocation")

local function posicao()
	local r = Random.new()
	return spawn.Position + Vector3.new(r:NextNumber(-4, 4), 3.5, r:NextNumber(-4, 4))
end

local function aoNascer(player, char)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then return end
	-- carrega o chão da praça antes de colocar o jogador lá (StreamingEnabled)
	pcall(function() player:RequestStreamAroundAsync(spawn.Position, 5) end)
	if player:GetAttribute("InRun") then return end -- quem está numa partida é levado pela WaveServer
	char:PivotTo(CFrame.new(posicao()) * CFrame.Angles(0, math.rad(180), 0))
	root.AssemblyLinearVelocity = Vector3.zero
end

local function setup(player)
	player.RespawnLocation = spawn
	player.CharacterAdded:Connect(function(char) aoNascer(player, char) end)
	if player.Character then task.spawn(aoNascer, player, player.Character) end
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do setup(p) end
