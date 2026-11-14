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

## Naturezas: 4 etapas, escolha 1 de 2 (`NatureData`, `NatureServer`, `NatureClient`)
- Cada natureza (Fogo, Vento, Raio, Terra, Água) tem 4 etapas e 2 jutsus por etapa (40 no total). Em cada etapa o jogador escolhe
  1 dos 2; o outro fica de fora para sempre. A escolha é liberada pela missão `N<etapa>_<Natureza>` do mestre
  (`Recompensa.Escolha`), cai em `data.Natureza.Pendente` e é feita no painel NATURES (botão CHOOSE; abre sozinho uma vez).
- Requisitos: etapa 1 (3 treinos), etapa 2 (Nv 18, 6 treinos), etapa 3 (Nv 35 + rank Chunin, 9 treinos), etapa 4 (Nv 50 + rank Jonin, 12 treinos).
- 4 teclas de equipar: G, H, J e K (slots 5..8 do `AbilityServer`). O jutsu escolhido já vai para a primeira tecla livre.
- Quem já tinha `nat_X1`/`nat_X2` (opção A das etapas 1 e 2) mantém o jutsu como a escolha daquela etapa.
- Jutsus novos usam executores genéricos (`EF.proj/area/cone/line/target/rain`) descritos no campo `Ef` de cada jutsu.
- Dano = `PowerDamage x multiplicador`; natureza de afinidade: +25% de dano e -20% de chakra.

## HUD: letras maiores e mais imagens
- Escala: o HUD era reduzido duas vezes (0,78 na raiz x 0,8 no topo e no menu, ~62% do tamanho). Agora a raiz usa escala cheia
  (`HUD`, `AtributosClient`, `ClanClient` com a mesma conta), o topo fica em 1,0 e o menu lateral em 0,92.
- Barra do topo: nível 32, moedas e gemas 26, XP 14; moeda dourada de verdade (`iconeMoeda`) e gema maior.
- Menu lateral: botões 118x100, ícones 1,4x e coloridos por tela (`COR_ICONE`: Crates dourado, Collection azul, Battle Pass amarelo,
  Shop ciano, Settings cinza), nome em 14 (antes 9 espaçado), selo de notificação maior.
- Texto secundário (`COR.fraco`) mais claro (176,176,188) em HUD, Missões, Atributos e Clã.
- Barras de habilidades (X/Y/C em `CombatClient`, poderes do clã em `AbilityClient`, naturezas em `NatureClient`): escala responsiva
  `clamp((largura/2 + 111) / 864, 0.55, 0.95)` (antes fixa em 0,75), letras de 13 a 21; botões STATS/CLAN abaixo da barra do topo (y = 80 x escala).
- Naturezas: emoji do elemento no lugar do nome (🔥 Fogo, 💨 Vento, ⚡ Raio, 🌍 Terra, 💧 Água) nos slots, no painel e na escolha.

## Battle Pass: mais difícil + trilha Premium (`EconomyData.BattlePass`, `BattlePassServer`, `HUD`)
- `XPPerLevel` foi de 400 para 1200 (3x mais difícil). Quem já tinha XP do passe tem o XP multiplicado por 3 uma vez só (`BattlePass.Ver` < 2 em `PlayerData.withDefaults`).
- Duas trilhas: GRÁTIS e 👑 PREMIUM (abas no painel). Premium dá o dobro de moedas e, a cada 5 níveis, 50 gemas + 1 caixa (2 nos múltiplos de 10), mais itens extras; o nível 50 premium é o prêmio grande.
- Gamepass "Passe Premium (trilha paga)": criar no Creator Dashboard e colar o ID em `EconomyData.BattlePass.PremiumPassId`. Com ID 0 o botão mostra "coming soon" e, no Studio, o premium conta como comprado (para testar).
- Servidor: atributo do jogador `PassePremium` (dono do gamepass), `ClaimBattlePass` aceita número (grátis), `"p<n>"` (premium, exige o passe) e `"all"`. `PromptGamePassPurchaseFinished` libera na hora.

## Missões diárias e bônus de login (`DiariasData`, `DiariasServer`, `ExtrasClient`)
- 3 missões por dia sorteadas (sem repetir; semente = data + UserId): matar inimigos ⚔, taijutsu 👊, treinar 💪, ganhar XP ⭐, ganhar moedas 💰, completar missões 📜. O dia vira à meia-noite de Brasília.
- Recompensa por missão (moedas e XP crescem com o nível) + bônus por fazer as 3 (`DiariasData.BONUS`: 300 moedas, 5 gemas, 1 caixa).
- Login de 7 dias em sequência (`DiariasData.LOGIN`); perder um dia volta ao dia 1. Save: `data.Diarias`, `data.Login`.
- Eventos: `ServerStorage.DiariaEvento` (kill, xp, coins, missao) disparado por `CombatServer.hit`, `PlayerData.AddXP/AddCoins` e `MissionServer.concluir`; `MissaoProgresso` continua levando treinar/taijutsu.
- Cliente: botão 📅 DAILY (bolinha vermelha com o número de prêmios prontos, atributo `DiariasPendentes`) abre o painel; abre sozinho uma vez por sessão (depois do clã e do tutorial).

## Ranking por nível (`RankingServer`, painel RANK em `ExtrasClient`)
- `OrderedDataStore "RankingNivel_v1"`, pontuação = nível x 1.000.000 + XP; publica a cada 90 s, ao sair e no `BindToClose`; top 50 em cache por 45 s. Sem DataStore (Studio) usa só os jogadores do servidor.
- RemoteFunction `GetRanking` devolve a lista (posição, id, nome, nível) e a posição do próprio jogador ("50+" fora do top).

## Tutorial da primeira entrada (`TutorialServer`, `TutorialClient`)
- Servidor guarda `data.Tutorial`; atributo `TutorialPendente` vale até terminar ou pular (RemoteEvent `TutorialAcao` "fim"). Quem já jogava também vê uma vez.
- Cliente: 9 passos com ícone, teclas desenhadas, seta que balança e foco (4 faixas escuras em volta do elemento: barra de nível, barra de jutsus, menu lateral, botões do topo). Começa depois da roleta do clã; botão ❓ HELP repete o tour.
- Atributo local `TutorialAtivo` e `TutorialPendente` seguram a abertura automática do DAILY até o fim do tour.

## Números de dano flutuantes (`DanoNumeroClient`)
- RemoteEvent `ReplicatedStorage.DanoNumero` (criado por `CombatServer` ou `AbilityServer`, quem subir primeiro): `FireClient` só para quem bateu, com posição, valor, cor e tipo.
- Soco = branco, jutsu = cor do elemento/clã (maior, "pop"), queimadura = menor. Máximo de 36 números ao mesmo tempo.

## Ícones dos jutsus (`IconesData`)
- Emoji por jutsu de clã e de Kekkei Genkai nos slots Q/E/R/V (entre a tecla e o tempo de recarga) e na lista do painel POWERS; bloqueado mostra ❓. Naturezas já usam o emoji do elemento.

## Rasengan e Raikiri (`NatureData`)
- Não são jutsus novos: renomeei duas opções da etapa 3 que já existiam. `nat_vento3b` (Vento, esfera de ar) virou **Rasengan** e `nat_raio3a` (Relâmpago, investida em linha) virou **Raikiri**. IDs e efeitos iguais, então nada se perde nos saves. Continua escolhendo 1 de 2 na etapa.

## Pergaminho com prêmios variados (`CharacterData.CrateRewards`, `CrateServer`)
- A raridade sorteada escolhe uma lista de prêmios, cada um com peso `W`: `Coins`, `Gems`, `Item` (boost 2x XP / 2x moedas), `Cosmetic` (bandana, cachecol, rastro, aura) e `Ficha` (re-giro). Pergaminho Básico e Rikudou têm listas próprias.
- Acessório: sorteia um que o jogador ainda não tem; se já tem todos da lista, vira `Fallback` (moedas ou gemas).
- Fichas: `cla` soma +1 em `data.Cla.Giros` (giro grátis da roleta de clã) e `natureza` soma em `data.Natureza.Fichas` (o re-giro das naturezas gasta a ficha antes das 50 gemas). Os botões mostram "(N free)" quando há ficha.
- Se o sorteio do prêmio falhar, o pagamento é devolvido.

## Easter eggs do lado leste (`SegredosData`, `SegredosServer`, `SegredosClient`)
- Passo 1: 3 selos 🌳👁🍃 escondidos em cantos do leste (posições em `SegredosData.Simbolos`; o servidor acha a altura do chão). Cada jogador acha os seus com a tecla E e o progresso fica salvo em `data.Segredos`.
- Passo 2: com os 3 selos aparece só para ele o santuário secreto (desenhado no cliente, em `SegredosData.Altar`) com um pilar de luz visível de longe.
- Passo 3: quatro pedestais (tecla E, segurar 1,5 s). O servidor confere: 3 selos, perto do altar, clã certo e rank mínimo (`RankMin`). O poder fica liberado para sempre.
- Poderes (tecla, recarga): 🌳 Gene do Hashirama (B, 60 s, qualquer jogador): cura 4% da vida máxima por segundo durante 10 s. 👁 Olho do Shisui (N, 75 s, só clã Uchiwa): inimigos em 45 studs (até 6) ficam imobilizados 6 s e perdem 5% da vida por segundo; o boss se solta em 40% do tempo e perde 25% disso; a kill conta para quem usou.
- Para criar mais um: acrescente em `SegredosData.Poderes` e `Ordem` e escreva o efeito em `EFEITOS` no `SegredosServer`.
- Cliente: botões com recarga no canto inferior direito (só aparecem com `Jogando`, o poder liberado e o rank certo), aviso no topo, atalhos B, N, M e L.

## Tesouros do Sábio dos Seis Caminhos (`SegredosData.Poderes.bashosen` / `kohaku`, `SegredosServer.EFEITOS`)
- Ficam como pedestais extras no santuário secreto do leste. **Só Jonin ou maior** pega e usa (`RankMin = "Jonin"`; ordem em `SegredosData.RankOrdem`). Abaixo disso o pedestal mostra "Jonin rank only" e o botão não aparece.
- **Separados dos jutsus:** teclas próprias (M e L), botões e recargas próprios, e o dano não usa Ninjutsu, `BuffDano` nem jutsus equipados: é uma fatia da vida máxima do inimigo. Não mexem na barra de jutsus (Q E R V, G H J K).
- **Chakra:** o uso gasta uma fração do `ChakraMax` (`Chakra`: Bashosen 80%, Kohaku 60%). Sem chakra suficiente o poder NÃO dispara, nada é gasto, não entra em recarga e aparece "Not enough chakra!". Sem punição de exaustão.
- 🌿 **Bashosen** (M, 45 s): explosão enorme em 35 studs (até 12 inimigos) de UM dos cinco elementos por uso, em ordem; o botão mostra o próximo. Dano base 35% da vida máxima (boss: 20% disso). 🔥 Fogo: queima 5%/s por 4 s. 💧 Água: empurra e imobiliza 1,5 s. 🌪 Vento: empurrão forte. ⚡ Raio: imobiliza 3 s. 🪨 Terra: dano x1,3 e imobiliza 2 s. O boss se solta em 40% do tempo e é empurrado menos.
- 🏺 **Kohaku no Jōhei** (L, 60 s): sela a alma do inimigo MAIS FORTE (maior vida máxima) em 50 studs. Ele fica imobilizado 3 s e depois some (a kill conta para quem usou). Boss resiste: fica preso 1,5 s e só perde 12% da vida.
- Ajustes rápidos em `SegredosData` (`Cooldown`, `Dano`, `Chakra`, `Elementos`, `Duracao`). Elementos novos: acrescente em `Elementos` (Nome, Emoji, Cor + Burn/Force/Stun/Mult).
- Testado em Play: bloqueio por rank (Estudante/Chunin/Genin), bloqueio sem chakra, gasto de chakra, recarga, ciclo dos 5 elementos (dano, fogo, empurrão e imobilização), Kohaku no mais forte e no boss, botões e pedestais no cliente.

## Tamanho do HUD (`ReplicatedStorage.HudEscala`)
- Um só lugar controla o tamanho: `HudEscala.Fator` (hoje 0.85; 1 = cheio, 0.78 = o compacto antigo). Quer maior ou menor? Mude só esse número.
- `HudEscala.Hud(viewport)`: barra de nível, menu da esquerda, STATS, DAILY, RANK, HELP e o chip do clã. Além da largura, limita pela altura: o menu da esquerda precisa caber abaixo da fileira de botões do topo (antes, em janelas baixas, ele subia e passava por cima dela).
- `HudEscala.Barras(viewport)`: barras de baixo (golpes X Y C, poderes Q E R V, naturezas G H J K) e os botões dos easter eggs (M, L...).
- Usado em: HUD, ExtrasClient, AtributosClient, ClanClient, TutorialClient, AbilityClient, CombatClient, NatureClient e SegredosClient.
