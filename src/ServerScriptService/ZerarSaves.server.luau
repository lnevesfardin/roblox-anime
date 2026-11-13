-- Script: ServerScriptService > ZerarSaves
-- TEMPORÁRIO: zera o save das contas listadas e roda só uma vez (marca feito no store ZerarSaves_v1).
-- Depois que rodar com sucesso no jogo publicado, pode apagar este script.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local CONTAS = { "dutzboi", "silencio_fofinho", "gojo_rebaixadao", "dabizok" }
local STORE_SAVE = "RPGCarreira_v1"
local STORE_FLAG = "ZerarSaves_v1"
local CHAVE_FLAG = "feito_" .. table.concat(CONTAS, "_")

local flags = DataStoreService:GetDataStore(STORE_FLAG)
local okFlag, jaFeito = pcall(function() return flags:GetAsync(CHAVE_FLAG) end)
if not okFlag then
	warn("[ZerarSaves] não consegui ler a flag: " .. tostring(jaFeito))
	return
end
if jaFeito then
	return
end

local store = DataStoreService:GetDataStore(STORE_SAVE)

-- quem estiver jogando agora é expulso antes, para não salvar de volta o progresso antigo
for _, nome in ipairs(CONTAS) do
	local plr = Players:FindFirstChild(nome)
	if plr then plr:Kick("Seu progresso está sendo zerado. Entre de novo em alguns segundos.") end
end
if #Players:GetPlayers() > 0 then task.wait(5) end

for _, nome in ipairs(CONTAS) do
	local okId, userId = pcall(function() return Players:GetUserIdFromNameAsync(nome) end)
	if not okId then
		warn(("[ZerarSaves] %s: não achei o UserId (%s)"):format(nome, tostring(userId)))
	else
		local okRem, erro = pcall(function() store:RemoveAsync("player_" .. userId) end)
		if okRem then
			print(("[ZerarSaves] %s (%d): save zerado"):format(nome, userId))
		else
			warn(("[ZerarSaves] %s (%d): falhou (%s)"):format(nome, userId, tostring(erro)))
		end
	end
end

pcall(function() flags:SetAsync(CHAVE_FLAG, true) end)
print("[ZerarSaves] concluído")
