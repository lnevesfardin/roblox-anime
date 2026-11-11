-- ModuleScript: ReplicatedStorage > TravelData
-- Destinos do "lançamento do clone": um clone do jogador aparece e arremessa ele até o lugar escolhido.
-- Pos é o ponto no chão (a altura é ajustada pelo servidor).

local TravelData = {}

TravelData.COOLDOWN = 60 -- segundos entre um lançamento e outro

TravelData.Destinos = {
	{ Id = "Praca", Name = "Village Square", Pos = Vector3.new(63, 3, -12) }, -- meio da praça de pedra
	{ Id = "Academia", Name = "Ninja Academy", Pos = Vector3.new(-120, 3, -530) },
	{ Id = "Mercado", Name = "Market Street", Pos = Vector3.new(-26, 3, -560) },
	{ Id = "Oeste", Name = "West District", Pos = Vector3.new(-295, 3, -280) },
}

function TravelData.Get(id)
	for _, d in ipairs(TravelData.Destinos) do
		if d.Id == id then
			return d
		end
	end
	return nil
end

return TravelData
