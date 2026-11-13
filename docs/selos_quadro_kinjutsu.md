# Selos de mão, quadro de missões e kinjutsu

## Selos de mão (`ReplicatedStorage.SelosDeMao`)
- Todo jutsu do jogo (clã Q/E/R, Kekkei Genkai V e natureza G/H) começa com selos de mão: o jogador junta as mãos
  no peito, troca de selo 4 vezes e estica os braços; o jutsu só sai em `Selos.SOLTAR_EM` = 0,62 s (corpo volta ao normal em 0,8 s).
- Uso: `Selos.Fazer(cor, aoSoltar)` (AbilityClient e NatureClient). Enquanto faz selos o jogador não repete o jutsu
  (`Selos.Ativo()`) e o CombatClient solta a pose de corrida (atributo `Selos`).
- A pose vai em `joint.Transform` na `PreSimulation`. Os ângulos dos quadros foram medidos no R15 do jogo
  (mãos a ~0,3 studs uma da outra, na altura do peito); mexer neles exige medir de novo a posição das mãos.

## Quadro de missões
- Não há mais limite diário/por hora: `QUADRO_POR_HORA` foi removido. O quadro mostra `QUADRO_OFERTAS` (4) missões do rank do
  jogador e repõe uma nova a cada missão concluída (não repete as últimas `QUADRO_MEMORIA`).
- O título mostra `Rank missions · N done`.
- 50 missões do quadro (`Quadro = true` em `MissionData.Missoes`): entregar algo a alguém (`falar` com o NPC), achar algo para
  alguém (`coletar`/`ir`) e derrotar bandidos (`derrotar`). O 8º campo da lista é o texto do objetivo (`Obj`), usado pelo
  cliente nas missões `falar`/`ir`.

## Kinjutsu nas ondas (`WaveServer.kinjutsu`)
- Inimigos do `MapData` com `Kin` e `KinCada` (segundos) usam jutsu proibido: Team Taka (Snake's Den), Rogue Genin, Mist Assassin
  e Rogue Jonin (Rogue Ninja Raid). Tipos: `Selo` (explosão em volta do inimigo), `Chamas` (linha de fogo roxo), `Maldicao`
  (marca roxa no chão sob o jogador) e `Veneno` (neblina que fica no chão).
- O inimigo para, brilha em roxo, marca o chão por ~1,3 s e só então causa dano (2,4x o dano dele). Matar o inimigo durante
  o preparo cancela o jutsu. O aviso "Kinjutsu - ..." aparece no texto da partida em todas as ondas.
- Chefes (White Snake, etc.) continuam com os kits próprios.

## Reset de progresso (botão em Configurações)
- Aparece só para as contas em `PlayerData.RESET_PERMITIDO` (hoje: `dutzboi`). Os outros jogadores não veem o botão.
- Clique em "Reset", depois em "Confirm?" em até 4 s. O servidor (`ResetarProgresso`) grava o save padrão e expulsa a conta.
- Não funciona durante uma partida (`InRun`). `CanSave` fica falso durante a gravação para o progresso antigo não voltar ao sair.
- Para liberar outra conta, acrescente o nome em `RESET_PERMITIDO`.
