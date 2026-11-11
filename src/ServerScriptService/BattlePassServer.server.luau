-- Script: ServerScriptService > BattlePassServer
-- Battle Pass de 50 níveis. O XP vem das partidas (PlayerData.AddXP soma no Passe também).
-- O jogador resgata cada nível alcançado; o servidor confere tudo antes de entregar.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local EconomyData = require(ReplicatedStorage:WaitForChild("EconomyData"))
local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local BP = EconomyData.BattlePass

local getPass = Instance.new("RemoteFunction")
getPass.Name = "GetBattlePass"
getPass.Parent = ReplicatedStorage

local claimLevel = Instance.new("RemoteFunction")
claimLevel.Name = "ClaimBattlePass"
claimLevel.Parent = ReplicatedStorage

local function levelOf(data)
	return math.min(BP.MaxLevel, math.floor(data.BattlePass.XP / BP.XPPerLevel))
end

local function snapshot(data)
	local claimed = {}
	for lv = 1, BP.MaxLevel do
		claimed[lv] = data.BattlePass.Claimed[tostring(lv)] == true
	end
	local level = levelOf(data)
	return {
		ok = true,
		xp = data.BattlePass.XP,
		level = level,
		xpInLevel = level >= BP.MaxLevel and BP.XPPerLevel or data.BattlePass.XP - level * BP.XPPerLevel,
		perLevel = BP.XPPerLevel,
		claimed = claimed,
	}
end

getPass.OnServerInvoke = function(player)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	return snapshot(data)
end

local busy = {}

-- lv = número do nível, ou "all" para resgatar tudo o que estiver liberado
claimLevel.OnServerInvoke = function(player, lv)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	if busy[player] then
		return { ok = false, reason = "Wait a moment." }
	end
	busy[player] = true
	local granted = {}
	local ok, err = pcall(function()
		local reached = levelOf(data)
		local list = {}
		if lv == "all" then
			for i = 1, reached do
				table.insert(list, i)
			end
		elseif type(lv) == "number" and lv == math.floor(lv) and lv >= 1 and lv <= reached then
			list = { lv }
		end
		for _, i in ipairs(list) do
			local key = tostring(i)
			if not data.BattlePass.Claimed[key] and BP.Rewards[i] then
				data.BattlePass.Claimed[key] = true
				PlayerData.GrantReward(player, BP.Rewards[i])
				table.insert(granted, i)
			end
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[BattlePassServer] " .. tostring(err))
		return { ok = false, reason = "Internal error." }
	end
	if #granted == 0 then
		return { ok = false, reason = "Nothing to claim yet." }
	end
	local s = snapshot(data)
	s.granted = granted
	return s
end

game.Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
