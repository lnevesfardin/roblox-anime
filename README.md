# Roblox Anime RPG

RPG de anime para Roblox: o jogador é ele mesmo, ganha personagens em caixas (Common → Mythic), se transforma neles e enfrenta mapas com 5 ondas, sendo a última um boss.

## O que já existe

- **Caixas (gacha)** com 5 raridades e garantia: 20 aberturas sem Épico ou melhor garantem um Épico ou melhor.
- **Coleção e equipar**: o personagem equipado muda vida e dano e ganha contorno da cor da raridade. Só dá para trocar no lobby.
- **Progressão**: nível, XP e moedas, salvos em DataStore.
- **Combate**: clique, toque ou F = combo de 4 golpes (3 socos + chute). X (segurar e soltar) = soco carregado, Y = soco aéreo, C = soco com investida. O servidor decide o dano.
- **Poderes** (Q / E / R): 3 por personagem (2 básicos + 1 forte), com recarga e dano calculados no servidor.
- **Mapa Snake's Den**: Lab Guinea Pigs → Sound Ninjas → Kab Clones → Red Cloud Team → boss **White Snake**, que tem golpe venenoso, mordidas e invoca cobras.
- **Corrida**: Shift no PC, botão "Run" no celular, L3 no controle.
- **Lobby**: vila japonesa com reta de saída, floresta e 5 destinos (Snake's Den, Sand Village, Hideout, Ninja World War, Valley of the End).

## Estrutura

```
src/
  ReplicatedStorage/
    CharacterData.luau      raridades, personagens, caixas, fórmulas de XP e status
    MapData.luau            ondas, inimigos, boss e recompensas de cada mapa
  ServerStorage/
    PlayerData.luau         dados do jogador + DataStore
  ServerScriptService/
    ProgressionServer       liga o PlayerData
    CrateServer             abre caixas (RemoteFunction OpenCrate)
    EquipServer             coleção e equipar (GetCollection / EquipCharacter)
    CombatServer            ataque do jogador (RemoteEvent Attack)
    AbilityServer           os 9 poderes dos personagens (RemoteEvent UseAbility)
    WaveServer              partida: contagem, ondas, boss, recompensa
    NascerNaVila            faz o jogador nascer na praça da vila
  StarterPlayer/StarterPlayerScripts/
    PainelCaixa             painel de nível/moedas + botão de caixa
    PainelColecao           janela de coleção
    CombatClient            ataque + HUD das ondas e barra do boss
    AbilityClient           teclas Q/E/R, HUD de recarga, investida do Tatashi
    Corrida                 correr
```

Arquivos `.server.luau` são Script, `.client.luau` são LocalScript e `.luau` são ModuleScript.

## Mapa e construções

As construções, como a vila, a floresta, os destinos e as arenas `Mapa_Ninja` (Snake's Den) e `Mapa_ExameNinja` (Ninja Exam, arena flutuante com boss Grand Proctor), ficam salvas no próprio place do Roblox (placeId `80763788407481`), não neste repositório. Para guardar uma cópia, use no Studio **File → Save to File As…** e coloque o `.rbxl` aqui.

## Como usar o código

- **Pelo Studio:** cada arquivo corresponde a um script com o mesmo nome no lugar indicado acima.
- **Com Rojo (opcional):** `rojo serve` usa o `default.project.json` para sincronizar a pasta `src` com o Studio.

## Para salvar o progresso dos jogadores

Publique o jogo e ative **Game Settings → Security → Enable Studio Access to API Services**.
