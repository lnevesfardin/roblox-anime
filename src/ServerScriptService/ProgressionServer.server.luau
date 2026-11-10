-- Script: ServerScriptService > ProgressionServer
-- Liga o sistema de dados e cria os "avisos" que outros scripts usam para dar recompensa.

local ServerStorage = game:GetService("ServerStorage")
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))

PlayerData.Init()

local function makeEvent(name)
	local e = ServerStorage:FindFirstChild(name)
	if not e then
		e = Instance.new("BindableEvent")
		e.Name = name
		e.Parent = ServerStorage
	end
	return e
end

-- Como dar recompensa a partir de outro script do servidor:
--   ServerStorage.AddXP:Fire(jogador, 100)
--   ServerStorage.AddCoins:Fire(jogador, 50)
makeEvent("AddXP").Event:Connect(PlayerData.AddXP)
makeEvent("AddCoins").Event:Connect(PlayerData.AddCoins)
