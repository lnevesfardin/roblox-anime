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
  jogador e repõe uma nova a cada missão concluída.
- Rodízio: nenhuma missão volta antes de as outras do rank terem aparecido. A memória é `max(QUADRO_MEMORIA, missões do rank - QUADRO_OFERTAS)`
  e o save guarda até `QUADRO_HISTORICO` (60) ids em `q.Rec` (a ordem mostra a última vez que cada uma foi feita).
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

## Golpes dos inimigos (`ServerStorage.InimigoGolpe`)
- Inimigos humanoides (ondas, bandidos do acampamento e inimigos da floresta) batem em combo de 3 golpes com os mesmos efeitos de
  soco do jogador (rastro em meia-lua, anel de impacto, flash branco no alvo). Dano: 0,6x, 0,6x e 1,0x; pausa de ~1,9 s depois do
  3º golpe (a "janela" para revidar). Cobras (`isSnake`) e chefes com kit próprio não usam o módulo.
- Levar um golpe do jogador atordoa o inimigo e corta o combo (`Interromper`).

## XP por inimigo derrotado
- Ondas: `max(3, floor(VidaBase x 0,22 x XP da dificuldade))` para cada jogador da partida.
- Acampamento: Rogue Scout 10, Rogue Ninja 18, Rogue Brute 36 (quem estiver a menos de 70 studs).
- Os inimigos da floresta continuam pagando XP/moedas por `recompensarPerto`.

## Missões da história
- H7 "Rogue Ninjas Nearby" virou missão de reconhecimento (`ir` ao Acampamento): não repete o "derrotar" do H6.

## Treino dos postes (Vitality, Strength, Agility)
- Minigame de socos: 6 acertos (antes 10), faixa 0,32 -> 0,15 da barra, marcador mais lento e 5 vidas (antes 3).

## Animação dos inimigos (`InimigoAnim`)
- LocalScript que anima por código os modelos com a tag `Inimigo`: balanço de braços e pernas ao andar e soco quando o servidor
  marca `GolpeT`/`GolpeN` (feito em `InimigoGolpe.Tentar`). Não usa animações de terceiros (R6 e R15).

## Evolução
- `CharacterData.XPForLevel` = `160 x nível^1,6` (era 80): subir de nível pede o dobro de XP.

## Estilos de luta
- Só `Basico` e `Lee` estão em `FightStyles.Order`. Boxe, Karatê, Muay Thai e Jiu-Jitsu continuam definidos (guardados) e as missões
  deles foram para `MissionData.Desativadas`.
- Estilo Lee (mestre: Coach Gaien, missão `E_Lee`): requisitos Nv 25, 30 treinos na Academia (`data.Estilos.Treinos`) e 100 kills só
  com taijutsu (a kill vale se o golpe final foi soco/chute e o inimigo nunca levou jutsu: atributo `DanoJutsu`).
- 8 Portões Internos (tecla Z, RemoteEvent `PortaoLee`): cada portão dá +12% de dano e +1,6 de velocidade, gasta chakra e vida por
  segundo (a vida nunca chega a zero). Maestria 1..5 libera 2, 3, 5, 6 e 8 portões. O 8º dura 12 s e deixa 4 s de cansaço.
