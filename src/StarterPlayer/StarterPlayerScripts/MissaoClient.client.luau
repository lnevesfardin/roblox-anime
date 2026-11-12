-- LocalScript: StarterPlayerScripts > MissaoClient
-- Caixa de conversa com NPCs, quadro de missões, missão atual no canto direito,
-- marcador do objetivo no mundo, nome e "!" em cima dos NPCs e avisos de missão concluída.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local MissionData = require(ReplicatedStorage:WaitForChild("MissionData"))
local FocoNPC = require(ReplicatedStorage:WaitForChild("FocoNPC"))
local action = ReplicatedStorage:WaitForChild("MissionAction")
local evento = ReplicatedStorage:WaitForChild("MissionEvent")
local player = Players.LocalPlayer

local COR = {
	painel = Color3.fromRGB(20, 20, 23), card = Color3.fromRGB(30, 30, 34), linha = Color3.fromRGB(58, 58, 64),
	texto = Color3.fromRGB(240, 240, 244), fraco = Color3.fromRGB(140, 140, 150), laranja = Color3.fromRGB(255, 140, 40),
	verde = Color3.fromRGB(70, 190, 110), vermelho = Color3.fromRGB(215, 70, 70), ouro = Color3.fromRGB(255, 205, 70),
}
local RANK_COR = { D = Color3.fromRGB(120, 200, 120), C = Color3.fromRGB(90, 160, 255), B = Color3.fromRGB(180, 100, 255), A = Color3.fromRGB(255, 160, 40), S = Color3.fromRGB(255, 70, 90) }

local function new(classe, props)
	local o = Instance.new(classe)
	for k, v in pairs(props) do
		if k ~= "Parent" then o[k] = v end
	end
	o.Parent = props.Parent
	return o
end
local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function label(parent, texto, tam, cor, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = texto, TextSize = tam, TextColor3 = cor or COR.texto, Font = Enum.Font.GothamBold, TextWrapped = true, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function botao(parent, texto, cor, size, pos)
	local b = new("TextButton", { Size = size, Position = pos, BackgroundColor3 = cor, Text = texto, TextColor3 = Color3.new(1, 1, 1), Font = Enum.Font.GothamBlack, TextSize = 13, Parent = parent })
	corner(b, 8)
	return b
end

local gui = new("ScreenGui", { Name = "MissaoUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 13, Parent = player:WaitForChild("PlayerGui") })
local function ligado() return player:GetAttribute("Jogando") == true end
gui.Enabled = ligado()
player:GetAttributeChangedSignal("Jogando"):Connect(function() gui.Enabled = ligado() end)

local estado = { NpcsComMissao = {}, Rank = "Estudante" }

---------------------------------------------------------------
-- Missão atual (canto superior direito)
---------------------------------------------------------------
local tracker = new("Frame", { AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(240, 74), BackgroundColor3 = COR.painel, BackgroundTransparency = 0.1, Parent = gui })
corner(tracker, 10)
new("UIStroke", { Color = COR.linha, Thickness = 1.5, Parent = tracker })
local tRank = label(tracker, "", 11, COR.laranja, { Position = UDim2.fromOffset(10, 5), Size = UDim2.new(1, -40, 0, 14), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local tNome = label(tracker, "", 14, COR.texto, { Position = UDim2.fromOffset(10, 20), Size = UDim2.new(1, -20, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })

-- selo vermelho (losango) das missões principais da história, no lugar da letra do rank
local VERMELHO_PRINCIPAL = Color3.fromRGB(220, 45, 50)
local function selo(parent, pos, tam)
	local s = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = UDim2.fromOffset(tam, tam), Rotation = 45,
		BackgroundColor3 = VERMELHO_PRINCIPAL, BorderSizePixel = 0, Parent = parent })
	corner(s, 3)
	new("UIStroke", { Color = Color3.fromRGB(255, 150, 150), Thickness = 1.5, Parent = s })
	local miolo = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.36, 0.36),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = s })
	corner(miolo, 2)
	return s
end
local function principal(id)
	if id == "__exame" then return true end
	local m = MissionData.Get(id)
	return m ~= nil and m.Historia ~= nil
end
local tSelo = selo(tracker, UDim2.fromOffset(18, 29), 12)
tSelo.Visible = false
local function nomeComSelo(com)
	tSelo.Visible = com
	tNome.Position = UDim2.fromOffset(com and 30 or 10, 20)
	tNome.Size = UDim2.new(1, com and -40 or -20, 0, 18)
end
local tObj = label(tracker, "", 12, COR.fraco, { Position = UDim2.fromOffset(10, 39), Size = UDim2.new(1, -20, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
local tDrop = botao(tracker, "X", COR.card, UDim2.fromOffset(22, 18), UDim2.new(1, -28, 0, 4))
tDrop.TextSize = 11
local function posicionarTracker()
	-- lado direito, abaixo da lista de jogadores do Roblox
	tracker.Position = UDim2.new(1, -12, 0.3, 0)
end
posicionarTracker()

local function nomeNpc(key)
	local i = MissionData.NPCs[key]
	return i and i.Name or key
end
local function objetivo(missao, p)
	local t = missao.Tipo
	if t == "falar" then return "Talk to " .. nomeNpc(missao.Alvo) end
	if t == "ir" then return "Go to " .. MissionData.Lugares[missao.Alvo].Name end
	if t == "treinar" then return ("Train at the Ninja Academy  %d/%d"):format(p, missao.N) end
	if t == "derrotar" then return ("Defeat bandits at the hideouts  %d/%d"):format(p, missao.N) end
	if t == "coletar" then return ("Collect glowing herbs in the forest  %d/%d"):format(p, missao.N) end
	if t == "exame" then return "Talk to " .. nomeNpc(missao.Npc) .. " to start the exam" end
	return ""
end

---------------------------------------------------------------
-- Marcador do objetivo no mundo
---------------------------------------------------------------
local ancora = new("Part", { Name = "MarcadorMissao", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.one, Parent = workspace })
local marca = new("BillboardGui", { Name = "MarcaMissao", Size = UDim2.fromOffset(120, 46), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 100000, StudsOffset = Vector3.new(0, 7, 0), Enabled = false, Parent = ancora })
local mIcone = label(marca, "◆", 22, COR.ouro, { Size = UDim2.new(1, 0, 0, 24), Font = Enum.Font.GothamBlack })
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = mIcone })
local mDist = label(marca, "", 12, Color3.new(1, 1, 1), { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18), Font = Enum.Font.GothamBlack })
new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 1.5, Parent = mDist })

local function npcModelo(key)
	for _, tag in ipairs({ "NPC", "NPCParado" }) do
		for _, m in ipairs(CollectionService:GetTagged(tag)) do
			if m.Name == key then return m end
		end
	end
	return nil
end
local function alvoMarcador(missao)
	if not missao then return nil end
	local t = missao.Tipo
	if t == "falar" or t == "exame" then
		local m = npcModelo(t == "falar" and missao.Alvo or missao.Npc)
		return m and m:GetPivot().Position
	end
	if t == "treinar" then return MissionData.Lugares.Academia.Pos end
	local l = MissionData.Lugares[missao.Alvo]
	return l and l.Pos
end

---------------------------------------------------------------
-- Nomes e "!" em cima dos NPCs
---------------------------------------------------------------
local placas = {} -- [modelo] = { nome, exclamacao }
local function placaNpc(m)
	if placas[m] then return end
	local head = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
	if not head then return end
	local info = MissionData.NPCs[m.Name] or MissionData.NPCs.StarterCharacter
	-- só o "!" fica aqui (o nome em cima da cabeça é criado pelo servidor).
	-- BillboardGui precisa ficar direto no PlayerGui: dentro de uma ScreenGui ele não aparece.
	local b = new("BillboardGui", { Name = "AvisoNPC", Adornee = head, Size = UDim2.fromOffset(60, 30), StudsOffset = Vector3.new(0, 4.4, 0), MaxDistance = 90, LightInfluence = 0, Enabled = ligado(), Parent = player.PlayerGui })
	player:GetAttributeChangedSignal("Jogando"):Connect(function() b.Enabled = ligado() end)
	local ex = label(b, "!", 28, COR.ouro, { Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBlack, Visible = false })
	new("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 2, Parent = ex })
	placas[m] = { gui = b, ex = ex }
end
for _, m in ipairs(CollectionService:GetTagged("NPC")) do placaNpc(m) end
for _, m in ipairs(CollectionService:GetTagged("NPCParado")) do placaNpc(m) end
CollectionService:GetInstanceAddedSignal("NPC"):Connect(placaNpc)

---------------------------------------------------------------
-- Atualizar tela com o estado
---------------------------------------------------------------
local function atualizar()
	tRank.Text = "RANK · " .. string.upper(MissionData.RankName(estado.Rank or "Estudante"))
	local missao = estado.Ativa and MissionData.Get(estado.Ativa.Id)
	local proxima = nil
	if missao then
		if missao.Historia then
			nomeComSelo(true)
			tNome.Text = missao.Name
			tNome.TextColor3 = Color3.fromRGB(255, 105, 105)
		else
			nomeComSelo(false)
			tNome.Text = ("[%s] %s"):format(missao.Rank, missao.Name)
			tNome.TextColor3 = RANK_COR[missao.Rank] or COR.texto
		end
		tObj.Text = objetivo(missao, estado.Ativa.P)
		tDrop.Visible = not missao.Historia
	else
		-- sem missão: mostra o próximo passo do caminho (história)
		proxima = MissionData.DaHistoria((estado.Historia or 0) + 1)
		nomeComSelo(proxima ~= nil)
		if proxima then
			tNome.Text = ("PATH %d/%d · %s"):format(proxima.Historia, MissionData.TotalHistoria, proxima.Name)
			tNome.TextColor3 = COR.ouro
			tObj.Text = "Talk to " .. nomeNpc(proxima.Npc) .. " to continue." .. (proxima.Promove and "  (You become a Genin!)" or "")
		else
			tNome.Text = "No mission"
			tNome.TextColor3 = COR.texto
			tObj.Text = "Talk to people with a  !  or use the QUESTS board in the square."
		end
		tDrop.Visible = false
	end
	for m, pl in pairs(placas) do
		pl.ex.Visible = estado.NpcsComMissao[m.Name] == true and not estado.Ativa
	end
	local pos = alvoMarcador(missao)
	if not pos and proxima then
		local quem = npcModelo(proxima.Npc)
		pos = quem and quem:GetPivot().Position
	end
	if pos then
		ancora.Position = pos
		marca.Enabled = true
	else
		marca.Enabled = false
	end
end

task.spawn(function()
	while true do
		task.wait(0.25)
		if marca.Enabled then
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local missao = estado.Ativa and MissionData.Get(estado.Ativa.Id)
			if missao and (missao.Tipo == "falar" or missao.Tipo == "exame") then
				local pos = alvoMarcador(missao)
				if pos then ancora.Position = pos end
			end
			if root then
				mDist.Text = math.floor((root.Position - ancora.Position).Magnitude) .. "m"
			end
		end
	end
end)

tDrop.MouseButton1Click:Connect(function()
	local r = action:InvokeServer("desistir")
	if r and r.estado then estado = r.estado end
	atualizar()
end)

---------------------------------------------------------------
-- Caixa de conversa
---------------------------------------------------------------
local dialogo = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.fromOffset(560, 300), BackgroundColor3 = COR.painel, Visible = false, Parent = gui })
corner(dialogo, 14)
new("UIStroke", { Color = COR.laranja, Thickness = 2, Parent = dialogo })
local escala = new("UIScale", { Parent = dialogo })
local function ajustar()
	local v = workspace.CurrentCamera.ViewportSize
	escala.Scale = math.clamp(math.min(v.X / 640, v.Y / 520), 0.45, 1)
end
ajustar()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(ajustar)
local dNome = label(dialogo, "", 18, COR.laranja, { Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(400, 22), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
local dTitulo = label(dialogo, "", 12, COR.fraco, { Position = UDim2.fromOffset(16, 32), Size = UDim2.fromOffset(400, 14), TextXAlignment = Enum.TextXAlignment.Left })
local dFala = label(dialogo, "", 14, COR.texto, { Position = UDim2.fromOffset(16, 50), Size = UDim2.new(1, -32, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
local dFechar = botao(dialogo, "X", COR.card, UDim2.fromOffset(30, 26), UDim2.new(1, -40, 0, 10))
local lista = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 1, -128), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), Parent = dialogo })
new("UIListLayout", { Padding = UDim.new(0, 6), Parent = lista })
local dAviso = label(dialogo, "", 12, COR.vermelho, { Position = UDim2.new(0, 16, 1, -30), Size = UDim2.new(1, -32, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
dFechar.MouseButton1Click:Connect(function() dialogo.Visible = false end)
-- ao fechar a conversa (de qualquer jeito) a câmera volta ao normal
dialogo:GetPropertyChangedSignal("Visible"):Connect(function()
	if not dialogo.Visible then FocoNPC.Soltar() end
end)

local function recompensaTexto(r)
	local t = {}
	if r.XP then table.insert(t, "+" .. r.XP .. " XP") end
	if r.Coins then table.insert(t, "+" .. r.Coins .. " coins") end
	if r.Pontos then table.insert(t, "+" .. r.Pontos .. " stat pts") end
	if r.PrimeiroJutsu then table.insert(t, "+ clan jutsu") end
	if r.Jutsu then table.insert(t, "+ new jutsu") end
	if r.NovaNatureza then table.insert(t, "+ new nature") end
	return table.concat(t, "   ")
end

local function limparLista()
	for _, c in ipairs(lista:GetChildren()) do
		if c:IsA("GuiObject") then c:Destroy() end
	end
end

-- fala do NPC aparecendo letra por letra
local falaVez = 0
local function falar(texto, grande)
	falaVez += 1
	local minha = falaVez
	dFala.Size = UDim2.new(1, -32, 0, grande and 66 or 36)
	lista.Position = UDim2.fromOffset(12, grande and 122 or 92)
	lista.Size = UDim2.new(1, -24, 1, grande and -158 or -128)
	dFala.Text = "\"" .. texto .. "\""
	if not grande then
		dFala.MaxVisibleGraphemes = -1
		return
	end
	dFala.MaxVisibleGraphemes = 0
	task.spawn(function()
		local total = utf8.len(dFala.Text) or #dFala.Text
		for n = 2, total, 2 do
			if falaVez ~= minha then return end
			dFala.MaxVisibleGraphemes = n
			task.wait(0.012)
		end
		if falaVez == minha then dFala.MaxVisibleGraphemes = -1 end
	end)
end

-- Conversa com opções de resposta. Cada passo: fala do NPC, o jogador escolhe uma resposta,
-- o NPC reage, e segue. No fim chama aoFim(escolhas) com o número da opção de cada passo.
local function tocarConversa(conversa, aoFim)
	local escolhas = {}
	local i = 0
	local function opcao(texto, cor, ordem, clique)
		local b = new("TextButton", { Size = UDim2.new(1, -6, 0, 38), BackgroundColor3 = cor, Text = texto, TextColor3 = COR.texto, Font = Enum.Font.GothamBold,
			TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = ordem, AutoButtonColor = true, Parent = lista })
		corner(b, 8)
		new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 8), Parent = b })
		b.MouseButton1Click:Connect(clique)
		return b
	end
	local function passo()
		i += 1
		local p = conversa[i]
		if not p then
			aoFim(escolhas)
			return
		end
		limparLista()
		dAviso.Text = ""
		falar(p.Fala, true)
		if p.Opcoes then
			for k, op in ipairs(p.Opcoes) do
				opcao(k .. ".  " .. op.T, COR.card, k, function()
					escolhas[i] = k
					limparLista()
					falar(op.R or "...", true)
					opcao("Continue  >", COR.laranja, 1, passo)
				end)
			end
		else
			escolhas[i] = 0
			opcao("Continue  >", COR.laranja, 1, passo)
		end
	end
	passo()
end

local function abrirDialogo(d)
	dNome.Text = d.nome
	dTitulo.Text = d.titulo or ""
	dAviso.Text = ""
	limparLista()
	if d.conversa then
		-- missão "falar": a conversa com este NPC é a missão
		dialogo.Visible = true
		tocarConversa(d.conversa, function(escolhas)
			limparLista()
			local r = action:InvokeServer("conversou", escolhas)
			if r and r.estado then estado = r.estado end
			atualizar()
			if not (r and r.ok) then dialogo.Visible = false end
			-- se deu certo, o servidor já manda a próxima fala do NPC (com a próxima missão)
		end)
		return
	end
	falar(d.fala or "", false)
	if #d.ofertas == 0 then
		label(new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = lista }), "Nothing for you right now.", 13, COR.fraco, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left })
	end
	for i, o in ipairs(d.ofertas) do
		local f = new("Frame", { Size = UDim2.new(1, -6, 0, 62), BackgroundColor3 = COR.card, LayoutOrder = i, Parent = lista })
		corner(f, 8)
		if principal(o.Id) then
			selo(f, UDim2.fromOffset(19, 17), 15)
		else
			local tag = label(f, o.Rank or "D", 12, Color3.new(1, 1, 1), { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(22, 18), BackgroundTransparency = 0, BackgroundColor3 = RANK_COR[o.Rank] or COR.linha, Font = Enum.Font.GothamBlack })
			corner(tag, 4)
		end
		label(f, o.Name, 14, COR.texto, { Position = UDim2.fromOffset(36, 6), Size = UDim2.new(1, -150, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.GothamBlack })
		local sub = o.Desc
		if d.npc == "Quadro" and o.De then sub = sub .. "  (from " .. o.De .. ")" end
		label(f, sub, 11, COR.fraco, { Position = UDim2.fromOffset(36, 25), Size = UDim2.new(1, -150, 0, 16), TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })
		label(f, recompensaTexto(o.Recompensa or {}), 11, COR.verde, { Position = UDim2.fromOffset(36, 42), Size = UDim2.new(1, -150, 0, 14), TextXAlignment = Enum.TextXAlignment.Left })
		if o.Bloqueio then
			label(f, o.Bloqueio, 11, COR.fraco, { Position = UDim2.new(1, -110, 0, 0), Size = UDim2.new(0, 102, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
		else
			local b = botao(f, o.Id == "__exame" and "START" or "ACCEPT", o.Id == "__exame" and COR.vermelho or COR.verde, UDim2.fromOffset(92, 32), UDim2.new(1, -100, 0, 15))
			local function aceitar()
				local r = action:InvokeServer("aceitar", o.Id)
				if r and r.ok then
					if r.estado then estado = r.estado end
					atualizar()
					dialogo.Visible = false
				else
					dAviso.Text = (r and r.erro) or "Could not accept."
				end
			end
			b.MouseButton1Click:Connect(function()
				if o.Conversa and d.npc ~= "Quadro" then
					-- o NPC conversa com o jogador antes de entregar a missão
					tocarConversa(o.Conversa, function()
						limparLista()
						aceitar()
						if dialogo.Visible then task.delay(2, function() dialogo.Visible = false end) end
					end)
				else
					aceitar()
				end
			end)
		end
	end
	dialogo.Visible = true
end

-- fecha a conversa se o jogador se afastar
local origemDialogo
task.spawn(function()
	while true do
		task.wait(0.5)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if dialogo.Visible and origemDialogo and root and (root.Position - origemDialogo).Magnitude > 22 then
			dialogo.Visible = false
		end
	end
end)

---------------------------------------------------------------
-- Avisos
---------------------------------------------------------------
local toast = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 90), Size = UDim2.fromOffset(380, 64), BackgroundColor3 = COR.painel, BackgroundTransparency = 0.05, Visible = false, Parent = gui })
corner(toast, 12)
local toastBorda = new("UIStroke", { Color = COR.ouro, Thickness = 2, Parent = toast })
local toastT = label(toast, "", 18, COR.ouro, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), Font = Enum.Font.GothamBlack })
local toastS = label(toast, "", 13, COR.texto, { Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 22) })
local vez = 0
local function mostrarToast(titulo, sub, cor)
	vez += 1
	local minha = vez
	toastT.Text, toastS.Text = titulo, sub or ""
	toastT.TextColor3, toastBorda.Color = cor, cor
	toast.Visible = true
	toast.Position = UDim2.new(0.5, 0, 0, 70)
	TweenService:Create(toast, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 90) }):Play()
	task.delay(4, function()
		if vez == minha then toast.Visible = false end
	end)
end

evento.OnClientEvent:Connect(function(d)
	if d.tipo == "estado" then
		estado = d.estado or estado
		atualizar()
	elseif d.tipo == "dialogo" then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		origemDialogo = root and root.Position
		abrirDialogo(d)
		if d.modelo then FocoNPC.Focar(d.modelo) end
	elseif d.tipo == "concluida" then
		mostrarToast("MISSION COMPLETE!", d.nome .. "   " .. recompensaTexto(d.recompensa or {}), COR.ouro)
	elseif d.tipo == "aviso" then
		mostrarToast(d.bom and "NOTICE" or "HEY!", d.texto, d.bom and COR.verde or COR.vermelho)
	end
end)

-- estado inicial
task.spawn(function()
	for _ = 1, 30 do
		local r = action:InvokeServer("estado")
		if r and r.estado then
			estado = r.estado
			break
		end
		task.wait(0.5)
	end
	atualizar()
end)
atualizar()
