-- Script: ServerScriptService > BattlePassServer
-- Battle Pass de 50 niveis (1200 XP por nivel) com duas trilhas: gratis e Premium (gamepass EconomyData.BattlePass.PremiumPassId).
-- O XP vem de PlayerData.AddXP. O jogador resgata cada nivel alcancado; o servidor confere tudo antes de entregar.
-- Resgate: lv = numero (gratis), "p<numero>" (Premium) ou "all" (tudo que estiver liberado).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")

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

-- Premium: dono do gamepass (no Studio, enquanto o gamepass nao existe, fica liberado para teste)
local function verificarPremium(player)
	local tem = false
	if BP.PremiumPassId ~= 0 then
		local ok, r = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, BP.PremiumPassId) end)
		tem = ok and r == true
	elseif RunService:IsStudio() then
		tem = true
	end
	player:SetAttribute("PassePremium", tem)
end
Players.PlayerAdded:Connect(function(p) task.spawn(verificarPremium, p) end)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(verificarPremium, p) end
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, comprou)
	if comprou and BP.PremiumPassId ~= 0 and passId == BP.PremiumPassId then
		player:SetAttribute("PassePremium", true)
	end
end)

local function snapshot(player, data)
	local claimed, claimedP = {}, {}
	for lv = 1, BP.MaxLevel do
		claimed[lv] = data.BattlePass.Claimed[tostring(lv)] == true
		claimedP[lv] = data.BattlePass.ClaimedP[tostring(lv)] == true
	end
	local level = levelOf(data)
	return {
		ok = true,
		xp = data.BattlePass.XP,
		level = level,
		xpInLevel = level >= BP.MaxLevel and BP.XPPerLevel or data.BattlePass.XP - level * BP.XPPerLevel,
		perLevel = BP.XPPerLevel,
		claimed = claimed,
		claimedP = claimedP,
		premium = player:GetAttribute("PassePremium") == true,
	}
end

getPass.OnServerInvoke = function(player)
	local data = PlayerData.Get(player)
	if not data then
		return { ok = false, reason = "Your data is still loading." }
	end
	return snapshot(player, data)
end

local busy = {}

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
	local motivo
	local ok, err = pcall(function()
		local reached = levelOf(data)
		local premium = player:GetAttribute("PassePremium") == true
		local list = {} -- { nivel, premium }
		local function inteiro(n) return type(n) == "number" and n == math.floor(n) and n >= 1 and n <= reached end
		if lv == "all" then
			for i = 1, reached do
				table.insert(list, { i, false })
				if premium then table.insert(list, { i, true }) end
			end
		elseif inteiro(lv) then
			list = { { lv, false } }
		elseif type(lv) == "string" and lv:sub(1, 1) == "p" and inteiro(tonumber(lv:sub(2))) then
			if premium then
				list = { { tonumber(lv:sub(2)), true } }
			else
				motivo = "Premium Pass only."
			end
		end
		for _, e in ipairs(list) do
			local key = tostring(e[1])
			local claimed = e[2] and data.BattlePass.ClaimedP or data.BattlePass.Claimed
			local reward = e[2] and BP.PremiumRewards[e[1]] or BP.Rewards[e[1]]
			if not claimed[key] and reward then
				claimed[key] = true
				PlayerData.GrantReward(player, reward)
				table.insert(granted, e[1])
			end
		end
	end)
	busy[player] = nil
	if not ok then
		warn("[BattlePassServer] " .. tostring(err))
		return { ok = false, reason = "Internal error." }
	end
	if #granted == 0 then
		return { ok = false, reason = motivo or "Nothing to claim yet." }
	end
	local s = snapshot(player, data)
	s.granted = granted
	return s
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)
