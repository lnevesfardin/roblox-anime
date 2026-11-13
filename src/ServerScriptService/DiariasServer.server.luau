-- Script: ServerScriptService > DiariasServer
-- Missoes diarias (3 por dia, sorteadas) + bonus por fazer todas + bonus de login de 7 dias.
-- O dia vira a meia-noite de Brasilia. Progresso: BindableEvent ServerStorage.DiariaEvento (kill, xp, coins, missao)
-- e ServerStorage.MissaoProgresso (treinar, taijutsu). Cliente: RemoteFunction DiariasAcao ("estado", "missao", "bonus", "login").
-- Save: data.Diarias = { Dia, Missoes = { { Id, N, Prog, Pega, Coins, XP } }, BonusPego }, data.Login = { Dia, Seq }

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local PlayerData = require(ServerStorage:WaitForChild("PlayerData"))
local CharacterData = require(ReplicatedStorage:WaitForChild("CharacterData"))
local DiariasData = require(ReplicatedStorage:WaitForChild("DiariasData"))

local evento = Instance.new("BindableEvent")
evento.Name = "DiariaEvento"
evento.Parent = ServerStorage
local acao = Instance.new("RemoteFunction")
acao.Name = "DiariasAcao"
acao.Parent = ReplicatedStorage

local FUSO = -3 * 3600
local function agora() return os.time() + FUSO end
local function diaDe(offset) return os.date("!%Y-%m-%d", agora() + (offset or 0) * 86400) end

local POOL = {
	{ Id = "kill", Emoji = "⚔", Texto = "Defeat {n} enemies", Ns = { 20, 30, 40 } },
	{ Id = "taijutsu", Emoji = "👊", Texto = "Defeat {n} enemies with taijutsu only", Ns = { 8, 12 } },
	{ Id = "treinar", Emoji = "💪", Texto = "Complete {n} trainings", Ns = { 2, 3 } },
	{ Id = "xp", Emoji = "⭐", Texto = "Earn {n} XP", Auto = function(lv) return math.max(150, math.floor(CharacterData.XPForLevel(lv) * 0.35 / 10) * 10) end },
	{ Id = "coins", Emoji = "💰", Texto = "Collect {n} coins", Auto = function(lv) return 300 + lv * 25 end },
	{ Id = "missao", Emoji = "📜", Texto = "Complete {n} quest", Ns = { 1 } },
}
local POR_ID = {}
for _, d in ipairs(POOL) do POR_ID[d.Id] = d end

local function garantir(player, data)
	local hoje = diaDe(0)
	local d = data.Diarias
	if type(d) ~= "table" or d.Dia ~= hoje or type(d.Missoes) ~= "table" then
		d = { Dia = hoje, Missoes = {}, BonusPego = false }
		local rng = Random.new((tonumber((hoje:gsub("-", ""))) or 1) + player.UserId)
		local pool = table.clone(POOL)
		local lv = data.Level or 1
		for _ = 1, DiariasData.QTD do
			local def = table.remove(pool, rng:NextInteger(1, #pool))
			local n = def.Ns and def.Ns[rng:NextInteger(1, #def.Ns)] or def.Auto(lv)
			table.insert(d.Missoes, { Id = def.Id, N = n, Prog = 0, Pega = false,
				Coins = 100 + lv * 8, XP = math.max(20, math.floor(CharacterData.XPForLevel(lv) * 0.12)) })
		end
		data.Diarias = d
	end
	if type(data.Login) ~= "table" then data.Login = { Dia = "", Seq = 0 } end
	return d, data.Login
end

local function loginProximo(l)
	if l.Dia == diaDe(0) then return l.Seq, true end -- ja pegou hoje
	if l.Dia == diaDe(-1) then return (l.Seq % #DiariasData.LOGIN) + 1, false end
	return 1, false
end

local function estado(player)
	local data = PlayerData.Get(player)
	if not data then return nil end
	local d, l = garantir(player, data)
	local ms, feitas = {}, 0
	for i, m in ipairs(d.Missoes) do
		local def = POR_ID[m.Id]
		if m.Pega then feitas += 1 end
		ms[i] = { Emoji = def and def.Emoji or "⭐", Texto = def and def.Texto:gsub("{n}", tostring(m.N)) or m.Id, N = m.N, Prog = m.Prog, Pega = m.Pega, Coins = m.Coins, XP = m.XP }
	end
	local proximo, pego = loginProximo(l)
	return { Missoes = ms, Feitas = feitas, BonusPego = d.BonusPego, Bonus = DiariasData.BONUS,
		Login = { Proximo = proximo, Pego = pego }, Reset = 86400 - (agora() % 86400) }
end

local function pendentes(player)
	local e = estado(player)
	if not e then return 0 end
	local n = 0
	for _, m in ipairs(e.Missoes) do
		if m.Prog >= m.N and not m.Pega then n += 1 end
	end
	if e.Feitas >= #e.Missoes and not e.BonusPego then n += 1 end
	if not e.Login.Pego then n += 1 end
	return n
end
local function aplicar(player) player:SetAttribute("DiariasPendentes", pendentes(player)) end

local function progresso(player, tipo, qtd)
	local data = PlayerData.Get(player)
	if not data or not qtd or qtd <= 0 then return end
	local d = garantir(player, data)
	local mudou = false
	for _, m in ipairs(d.Missoes) do
		if m.Id == tipo and m.Prog < m.N then
			m.Prog = math.min(m.N, m.Prog + qtd)
			mudou = true
		end
	end
	if mudou then aplicar(player) end
end
evento.Event:Connect(progresso)
task.spawn(function()
	local mp = ServerStorage:WaitForChild("MissaoProgresso", 30)
	if mp then
		mp.Event:Connect(function(player, tipo, qtd)
			if tipo == "treinar" or tipo == "taijutsu" then progresso(player, tipo, qtd or 1) end
		end)
	end
end)

local function salvar(player) task.spawn(function() pcall(PlayerData.Save, player) end) end

acao.OnServerInvoke = function(player, pedido, a)
	local data = PlayerData.Get(player)
	if not data then return { ok = false, erro = "Loading..." } end
	local d, l = garantir(player, data)
	if pedido == "missao" then
		local m = d.Missoes[tonumber(a) or 0]
		if not m or m.Pega or m.Prog < m.N then return { ok = false, erro = "Not finished yet.", estado = estado(player) } end
		m.Pega = true
		PlayerData.AddCoins(player, m.Coins)
		PlayerData.AddXP(player, m.XP)
		salvar(player)
	elseif pedido == "bonus" then
		local feitas = 0
		for _, m in ipairs(d.Missoes) do if m.Pega then feitas += 1 end end
		if d.BonusPego or feitas < #d.Missoes then return { ok = false, erro = "Claim all daily missions first.", estado = estado(player) } end
		d.BonusPego = true
		PlayerData.GrantReward(player, DiariasData.BONUS)
		salvar(player)
	elseif pedido == "login" then
		local proximo, pego = loginProximo(l)
		if pego then return { ok = false, erro = "Already claimed today.", estado = estado(player) } end
		l.Dia, l.Seq = diaDe(0), proximo
		PlayerData.GrantReward(player, DiariasData.LOGIN[proximo])
		salvar(player)
	end
	aplicar(player)
	return { ok = true, estado = estado(player) }
end

local function setup(player)
	for _ = 1, 60 do
		if PlayerData.Get(player) then break end
		task.wait(0.25)
	end
	while player.Parent do
		aplicar(player)
		task.wait(60) -- pega a virada do dia mesmo com o jogador online
	end
end
Players.PlayerAdded:Connect(setup)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(setup, p) end
