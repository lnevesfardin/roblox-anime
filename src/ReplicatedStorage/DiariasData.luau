-- ModuleScript: ReplicatedStorage > DiariasData
-- Dados compartilhados das missoes diarias e do bonus de login (servidor entrega, cliente so mostra).
local D = {}

D.QTD = 3 -- missoes diarias por dia
D.BONUS = { Coins = 300, Gems = 5, Crates = 1 } -- por fazer todas as diarias do dia

-- bonus de login: sequencia de 7 dias (se faltar um dia volta ao dia 1)
D.LOGIN = {
	{ Coins = 200 },
	{ Crates = 1 },
	{ Coins = 400, Item = "boost_xp_15" },
	{ Coins = 300, Crates = 1 },
	{ Gems = 10 },
	{ Coins = 800, Item = "boost_coins_15" },
	{ Gems = 30, Crates = 3 },
}

-- recompensa em "fichas" com emoji (imagem em vez de texto)
function D.Chips(r)
	local t = {}
	if r.Coins then table.insert(t, "💰 " .. r.Coins) end
	if r.XP then table.insert(t, "⭐ " .. r.XP) end
	if r.Gems then table.insert(t, "💎 " .. r.Gems) end
	if r.Crates then table.insert(t, "📦 " .. r.Crates) end
	if r.Item then table.insert(t, "⚡ Boost") end
	return table.concat(t, "  ")
end

return D
