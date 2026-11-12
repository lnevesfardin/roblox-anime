-- ModuleScript: ServerStorage > SkinInimigo
-- Veste um inimigo (corpo R15 padrao) com a aparencia de um modelo de ServerStorage.Aparencias:
-- roupa, cores de pele, cabeca (com rosto), acessorios, chapeus e pecas soltas (cabelo, mascara, capuz...).
-- O esqueleto continua o do inimigo, entao andar e atacar funcionam como antes.
-- Varios modelos com o mesmo nome viram variacoes: o pedido escolhe pelo indice.

local ServerStorage = game:GetService("ServerStorage")

local SkinInimigo = {}

local CORPO = {
	Head = true, Torso = true, HumanoidRootPart = true, ["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
	UpperTorso = true, LowerTorso = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true,
	RightHand = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
}

-- peca do doador R6 -> peca equivalente no corpo R15 do inimigo
local MAPA_R6 = {
	Head = "Head", Torso = "UpperTorso",
	["Left Arm"] = "LeftLowerArm", ["Right Arm"] = "RightLowerArm",
	["Left Leg"] = "LeftUpperLeg", ["Right Leg"] = "RightUpperLeg",
}

local function norm(s)
	return (s:lower():gsub("^%s+", ""):gsub("%s+$", ""))
end

local function contaHumanoides(m)
	local n = 0
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("Humanoid") then
			n += 1
		end
	end
	return n
end

local function grupo(nome)
	if nome == "Head" then
		return "Head"
	end
	if nome == "Torso" or nome == "UpperTorso" or nome == "LowerTorso" then
		return "Torso"
	end
	local lado = (nome:sub(1, 4) == "Left" and "Left") or (nome:sub(1, 5) == "Right" and "Right") or nil
	if lado then
		if nome:find("Arm") or nome:find("Hand") then
			return lado .. "Arm"
		end
		if nome:find("Leg") or nome:find("Foot") then
			return lado .. "Leg"
		end
	end
	return nil
end

local function prender(parte, base, deslocamento)
	parte.Anchored = false
	parte.CanCollide = false
	parte.CanQuery = false
	parte.CanTouch = false
	parte.Massless = true
	parte.CFrame = base.CFrame * deslocamento
	local w = Instance.new("WeldConstraint")
	w.Part0 = base
	w.Part1 = parte
	w.Parent = parte
end

local function tirarScripts(inst)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

-- Procura o modelo-doador pelo nome (sem ligar para maiusculas e espacos nas pontas).
-- Modelos com mais de um Humanoid (rigs aninhados) sao ignorados.
function SkinInimigo.Achar(nome, indice)
	local pasta = ServerStorage:FindFirstChild("Aparencias")
	if not pasta or type(nome) ~= "string" then
		return nil
	end
	local alvo = norm(nome)
	local lista = {}
	for _, c in ipairs(pasta:GetChildren()) do
		if c:IsA("Model") and norm(c.Name) == alvo and contaHumanoides(c) <= 1 then
			table.insert(lista, c)
		end
	end
	if #lista == 0 then
		return nil
	end
	return lista[((indice or 1) - 1) % #lista + 1]
end

local function acharCabeca(doador)
	for _, c in ipairs(doador:GetChildren()) do
		if c:IsA("BasePart") and c.Name == "Head" then
			return c
		end
	end
	for _, d in ipairs(doador:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Head" then
			return d
		end
	end
	for _, d in ipairs(doador:GetDescendants()) do
		if d:IsA("BasePart") then
			local m = d:FindFirstChildOfClass("SpecialMesh")
			if m and m.MeshType == Enum.MeshType.Head then
				return d
			end
		end
	end
	return nil
end

local function coresDoDoador(doador)
	local cores = {}
	local bc = doador:FindFirstChildOfClass("BodyColors")
	if bc then
		cores.Head = bc.HeadColor3
		cores.Torso = bc.TorsoColor3
		cores.LeftArm = bc.LeftArmColor3
		cores.RightArm = bc.RightArmColor3
		cores.LeftLeg = bc.LeftLegColor3
		cores.RightLeg = bc.RightLegColor3
	end
	for _, p in ipairs(doador:GetChildren()) do
		if p:IsA("BasePart") then
			local g = grupo(p.Name)
			if g and not cores[g] then
				cores[g] = p.Color
			end
		end
	end
	return cores
end

-- Aplica a aparencia do doador no corpo do inimigo.
-- Devolve: aplicou (boolean), temCorpo (o doador trouxe cores de pele/corpo; se nao, so e cabeca/enfeites)
function SkinInimigo.Aplicar(model, doador)
	local head = model:FindFirstChild("Head")
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not (doador and head and hum) then
		return false, false
	end
	local mHead = acharCabeca(doador)

	-- roupas
	for _, c in ipairs(doador:GetChildren()) do
		if c:IsA("Shirt") or c:IsA("Pants") or c:IsA("ShirtGraphic") then
			c:Clone().Parent = model
		end
	end

	-- cores de pele
	local cores = coresDoDoador(doador)
	local temCorpo = next(cores) ~= nil
	if temCorpo then
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
				local g = grupo(p.Name)
				if g and cores[g] then
					p.Color = cores[g]
				end
			end
		end
		local bc = model:FindFirstChildOfClass("BodyColors")
		if bc then
			bc.HeadColor3 = cores.Head or bc.HeadColor3
			bc.TorsoColor3 = cores.Torso or bc.TorsoColor3
			bc.LeftArmColor3 = cores.LeftArm or bc.LeftArmColor3
			bc.RightArmColor3 = cores.RightArm or bc.RightArmColor3
			bc.LeftLegColor3 = cores.LeftLeg or bc.LeftLegColor3
			bc.RightLegColor3 = cores.RightLeg or bc.RightLegColor3
		end
	end

	-- cabeca do doador (com o rosto) por cima da cabeca do inimigo
	if mHead then
		local cabeca = mHead:Clone()
		for _, d in ipairs(cabeca:GetChildren()) do
			if not (d:IsA("DataModelMesh") or d:IsA("Decal")) then
				d:Destroy()
			end
		end
		if cores.Head then
			cabeca.Color = cores.Head
		end
		cabeca.Name = "CabecaSkin"
		prender(cabeca, head, CFrame.new())
		cabeca.Parent = model
		for _, d in ipairs(head:GetChildren()) do
			if d:IsA("Decal") then
				d:Destroy()
			end
		end
		head.Transparency = 1
	end

	-- acessorios do doador (cabelo etc.); chapeus antigos (Hat) ou os que falharem viram pecas soltas
	local soltos = {}
	for _, a in ipairs(doador:GetChildren()) do
		if a:IsA("Accoutrement") then
			if a:IsA("Accessory") then
				local k = a:Clone()
				tirarScripts(k)
				local ok = pcall(function()
					hum:AddAccessory(k)
				end)
				if not ok then
					k:Destroy()
					soltos[a] = true
				end
			else
				soltos[a] = true
			end
		end
	end

	-- pecas soltas (cabelo, mascara, capuz, oculos...) presas na parte do corpo mais proxima
	local corpoDoador = {}
	for _, c in ipairs(doador:GetChildren()) do
		if c:IsA("BasePart") and CORPO[c.Name] and c.Name ~= "HumanoidRootPart" then
			table.insert(corpoDoador, c)
		end
	end
	if mHead and not table.find(corpoDoador, mHead) then
		table.insert(corpoDoador, mHead)
	end
	if #corpoDoador == 0 then
		return true, temCorpo
	end
	for _, p in ipairs(doador:GetDescendants()) do
		local anc = p:IsA("BasePart") and p:FindFirstAncestorWhichIsA("Accoutrement") or nil
		if p:IsA("BasePart") and not CORPO[p.Name] and p ~= mHead and p.Transparency < 0.99
			and (not anc or soltos[anc]) then
			local melhor, dist = nil, math.huge
			for _, b in ipairs(corpoDoador) do
				local d = (p.Position - b.Position).Magnitude
				if d < dist then
					melhor, dist = b, d
				end
			end
			local base = (melhor == mHead and head) or model:FindFirstChild(melhor.Name) or model:FindFirstChild(MAPA_R6[melhor.Name] or "") or head
			local k = p:Clone()
			for _, d in ipairs(k:GetChildren()) do
				if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") or d:IsA("BasePart") then
					d:Destroy()
				end
			end
			prender(k, base, melhor.CFrame:ToObjectSpace(p.CFrame))
			k.Parent = model
		end
	end
	return true, temCorpo
end

return SkinInimigo
