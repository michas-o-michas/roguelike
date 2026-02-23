# Análise de Áudio — Rootfall (Roguelike)

Resumo do que existe, lacunas e lista de áudios necessários para um nível **AAA**.

---

## 0. Sistema de sons implementado (SoundManager + buses)

- **SettingsManager:** em `_ready()` chama `_ensure_audio_buses()`: cria os buses **Music** e **SFX** se não existirem, para os sliders de áudio funcionarem.
- **SoundManager (autoload):**
  - Garante o bus **SFX** se não existir.
  - **Pool de 16** `AudioStreamPlayer` no bus SFX (vários sons ao mesmo tempo).
  - **API:** `play_sfx(stream, volume_db, pitch_scale)`, `play_sfx_id(id, volume_db, pitch_scale)`, `play_stream(stream)` (compatível com landingpad).
  - **Registro:** `ui_click` → button.mp3, `ui_hover` → hover.mp3; `register_sfx(id, stream)` para registrar mais.
  - **UI:** `connect_buttons_sound(root)` conecta todos os `Button` sob `root` a clique e hover.
- **Menus:** Menu principal, Pause e Settings chamam `SoundManager.connect_buttons_sound(self)` no `_ready()`.
- **Jogador:** `AttackAudio` (WeaponHandler) e `StepAudio` (Player) usam bus **SFX** (definido em código), então o slider de SFX afeta ataque e passos.

Para a **música** do Level1 (vento, música, noite) usar o slider **Music**, defina no editor o bus dos nós `DayCycle`, `Music`, `NightCycle` e do 4º player para **Music**.

**Sons de gameplay e UI:** o SoundManager tenta vários caminhos por ID (raiz, `UI/`, `player/`, `world/`). Ver **`docs/AUDIO_ORGANIZACAO.md`** para a lista completa de IDs, pastas e onde cada som toca.

Resumo dos IDs usados: `ui_click`, `ui_hover`, `ui_inventory_open`, `ui_select`, `ui_notification`, `player_hurt`, `player_death`, `player_heal`, `chest_open`, `harvest_complete`. Basta colocar os arquivos nas pastas indicadas; o primeiro caminho que existir é usado.

---

## 1. O que já existe

### 1.1 Sistema e configuração

| Item | Estado |
|------|--------|
| **SettingsManager** | Master / Music / SFX (0–100%), persistência em `user://settings.cfg` |
| **Tela de configurações** | Sliders de áudio (Master, Music, SFX) e `apply_audio()` |
| **AudioServer** | `apply_audio()` ajusta volume por bus (Master, Music, SFX) |
| **SoundManager** (autoload) | `play_stream(stream)` — um único `AudioStreamPlayer`, bus **Master** |
| **Buses** | Código espera buses **Music** e **SFX**; se não existirem no projeto, sliders de Music/SFX não têm efeito |

**Recomendação:** Em **Project → Project Settings → Audio**, criar buses **Music** e **SFX** como filhos de Master e fazer todos os players de música/SFX usarem esses buses (assim os sliders passam a funcionar).

---

### 1.2 Arquivos de áudio no projeto

| Arquivo | Uso atual |
|---------|-----------|
| `Assets/sounds/WASD Sound Grass Run 06.wav` | Passos do player (StepAudio no `player.tscn`) |
| `attack_sword.mp3` (raiz) | Ataque de todas as armas (wood_sword, axe, pickaxe, staff) |
| `Assets/sounds/windaudio.mp3` | DayCycle em Level1 (vento dia) |
| `Assets/sounds/music_ingame.mp3` | Música in-game em Level1 |
| `Assets/sounds/night.wav` | NightCycle em Level1 (ambiente noite) |
| `Assets/sounds/street-corner-jazz-cafe-338559.mp3` | 4º AudioStreamPlayer2D em Level1 (não há lógica ligando ao ciclo dia/noite) |
| `Assets/sounds/teleport.mp3` | Teleporte (Landingpad, via SoundManager) |
| `Assets/sounds/hover.mp3` | Hover no Landingpad |
| `Assets/sounds/button.mp3` | **Não usado** em nenhum script (menu/settings não tocam som de botão) |
| `Assets/sounds/ambient-sound.mp3` | Import existe; **não referenciado** em cenas/scripts |
| `Assets/sounds/day.wav` | Import existe; **não usado** em Level1 (DayCycle usa windaudio) |
| `Assets/sounds/fast-sword.wav` | Import existe; **não usado** |
| `mixkit-footsteps-in-woods-loop-533.wav` | Na raiz; **não usado** no player |

---

### 1.3 Onde o áudio é tocado

| Contexto | Implementação |
|----------|----------------|
| **Passos** | `Player.gd`: `step_audio.play()` a cada `step_interval` / `step_interval_sprint` ao andar/correr no chão. Um único som (grama). |
| **Ataque melee** | `weapon_handler.gd`: `_play_attack_sound()` — `AttackAudio` (3D) com `equipped_weapon.attack_sound`. Todas as armas usam o mesmo `attack_sword.mp3`. |
| **Teleporte / dungeon** | `landingpad.gd`: `_play_sound(stream)` → SoundManager; sons configuráveis no Inspector (teleport, dungeon_enter, dungeon_exit). |
| **Música / ambiente Level1** | 4× `AudioStreamPlayer2D` na cena: DayCycle (vento), Music (music_ingame), NightCycle (night), mais um com jazz. **Nenhum script** faz crossfade ou liga dia/noite ao ciclo (DayNightCycle só mexe em céu/luz). |

---

## 2. O que falta (lacunas)

### 2.1 Sistema

- **Buses Music/SFX** no projeto e roteamento: SoundManager e players 3D usam Master; sliders de Music/SFX podem não afetar nada.
- **SoundManager:** um único player; se tocar teleporte e em seguida outro efeito, o primeiro é cortado. Para AAA: pool de players ou bus SFX dedicado com vários canais.
- **Day/Night e áudio:** DayNightCycle não controla áudio; os 4 players em Level1 tocam em paralelo sem lógica de transição dia/noite (vento vs noite vs música vs jazz).

### 2.2 Feedback de jogador

- **Dano recebido:** nenhum som ao levar hit (HealthComponent tem `damage_taken` / `died`, sem conexão com áudio).
- **Morte do jogador:** nenhum som de morte.
- **Cura:** nenhum som de heal.
- **Pulo:** nenhum som de pulo/aterrissagem.
- **Dash:** nenhum som.

### 2.3 Mundo e interação

- **Baú (Chest):** abrir/fechar sem som.
- **Interação genérica (Interactable):** sem som de “interact”.
- **Coleta (ResourceNode / HarvestController):** sem som de machado/picareta, árvore caindo, recurso coletado.
- **Pickup (itens/moedas):** sem som de pegar item/moeda.

### 2.4 Combate e inimigos

- **Projétil (magic):** sem som de lançamento ou impacto.
- **Inimigos (mob_base):** sem som de ataque, hit recebido ou morte.
- **Armas:** um único som de ataque para todas; não há variação por tipo (espada vs machado vs picareta vs cajado).

### 2.5 UI

- **Menu principal / Pause / Settings:** botões sem som (button.mp3 existe e não é usado).
- **Hover em botões:** sem som (hover.mp3 só no Landingpad).
- **Inventário / hotbar / craft:** sem sons de abrir/fechar, seleção, craft concluído.

### 2.6 Ambiente e música

- **Ciclo dia/noite:** sem crossfade vento ↔ noite; música e jazz não reagem ao período do dia.
- **Dungeon:** sem música/ambiente específicos (apenas sons do landingpad enter/exit).
- **Biomas:** um único conjunto de passos (grama); sem variação para terra, pedra, madeira, água, neve.

---

## 3. Como melhorar (sistema)

1. **Buses:** Criar **Music** e **SFX** em Project Settings → Audio; rotear:
   - Música e ambientes → Music  
   - Efeitos (ataque, passos, UI, etc.) → SFX  
   - SoundManager e novos sistemas de SFX → SFX  

2. **SoundManager:**  
   - Trocar para bus **SFX**.  
   - Suportar **pool de players** (ex.: 8–16) para múltiplos SFX simultâneos sem cortar.  
   - Opcional: API `play_sfx(stream, volume_db, pitch_scale)` para variação.

3. **Música/ambiente em Level1:**  
   - Script (ex. em Level1_main ou em um nó “AudioController”) que:  
     - Lê o estado do DayNightCycle (manhã/dia/tarde/noite).  
     - Faz crossfade entre vento (dia) e night.wav (noite).  
     - Opcional: atenuar ou trocar música noite (ex. jazz só à noite, ou layer extra).

4. **Passos por superfície:**  
   - Raycast ou área para detectar superfície (grama, terra, pedra, madeira, água).  
   - Array ou Resource com um som (ou conjunto) por tipo; trocar `step_audio.stream` conforme o tipo.

5. **Sons por arma:**  
   - Em cada `weapon .tres`: `attack_sound` diferente (espada, machado, picareta, cajado).  
   - Usar `fast-sword.wav` onde fizer sentido (ex. ataque rápido) e outros para golpes pesados.

6. **Eventos de áudio centralizados:**  
   - Conectar sinais (HealthComponent `damage_taken`, `died`, `healed`; Chest `opened`; etc.) a um **AudioEvents** (autoload) que chama SoundManager ou players 3D com o som correto. Assim fica um único lugar para trocar bancos de som depois.

---

## 4. Lista de áudios para nível AAA

### 4.1 Player

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Passos | Grama (já existe), terra, pedra, madeira, neve, água (splash ao entrar), dungeon | Alta |
| Movimento | Pulo (takeoff), aterrissagem (landing), dash (whoosh) | Alta |
| Dano/Cura | Hit recebido (3–4 variações), morte do jogador, cura (potion/skill) | Alta |
| Armas | Espada (slash 2–3), machado (heavy 1–2), picareta (metal 1–2), cajado (whoosh/magic 1–2) | Alta |

### 4.2 Magia / projéteis

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Projétil | Lançamento (fireball, ice, etc.), impacto em chão/inimigo | Alta |
| Buff/Debuff | Ativar buff, tick de DoT (opcional) | Média |

### 4.3 Inimigos

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Ataque | 1 por tipo de mob (mordida, golpe, etc.) | Alta |
| Dano | Grunhido/impacto ao levar hit (2–3 por tipo) | Alta |
| Morte | Morte por tipo (ou por “família”: animal, humanoide) | Alta |
| Idle/Alert | Respiração ou alerta ao detectar jogador (opcional) | Baixa |

### 4.4 Mundo e interação

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Baú | Abrir, fechar (opcional) | Alta |
| Interação | Som genérico “interact” (porta, alavanca, NPC) | Média |
| Coleta | Machado em árvore, picareta em pedra, recurso coletado (madeira, minério, etc.) | Alta |
| Pickup | Moeda, item no chão, craft concluído | Alta |
| Portal/Dungeon | Teleporte (já existe), entrar/sair dungeon (já usados no Landingpad) | Já feito |

### 4.5 UI

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Botões | Clique (button.mp3 já existe — só conectar), hover (hover.mp3 já existe) | Alta |
| Inventário | Abrir/fechar, seleção de slot, item equipado | Média |
| Craft | Início/fim de craft, receita desbloqueada | Baixa |
| Notificações | Novo item, skill desbloqueada, achievement (opcional) | Baixa |

### 4.6 Música e ambiente

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Menu | Loop de menu principal (1–2 min) | Alta |
| In-game | Loop exploração (já existe music_ingame; melhorar mix/variações) | Alta |
| Combate | Camada ou faixa separada que entra em batalha (sting + loop ou layer) | Alta |
| Dungeon | Loop ambiente dungeon (tenso/ambient) | Alta |
| Dia/Noite | Ambiente dia (vento já existe), noite (night.wav já existe); só falta lógica de crossfade | Média |
| Boss / eventos | Sting de boss, evento especial (opcional) | Média |

### 4.7 Ambiente e Foley

| Categoria | Descrição | Prioridade |
|-----------|-----------|------------|
| Vento | Por bioma (floresta, tundra, montanha) — já existe um vento | Média |
| Água | Corrente, chuva (se houver) | Baixa |
| Fogueira / estruturas | Se houver acampamentos ou fogueiras | Baixa |

---

## 5. Priorização sugerida (roadmap)

1. **Fase 1 — Fundação**  
   - Buses Music/SFX e roteamento.  
   - SoundManager em SFX + pool de players.  
   - Conectar button.mp3 e hover.mp3 na UI (menu, pause, settings).  
   - Sons de dano/morte/cura do jogador (HealthComponent).  
   - Um som de abrir baú e um de pickup (moeda/item).

2. **Fase 2 — Combate**  
   - Um som por tipo de arma (espada, machado, picareta, cajado).  
   - Projétil: lançamento + impacto.  
   - Inimigos: ataque, hit, morte (por família ou tipo).

3. **Fase 3 — Mundo**  
   - Passos por superfície (pelo menos grama, terra, pedra).  
   - Pulo e aterrissagem.  
   - Coleta (machado/picareta + recurso coletado).  
   - Crossfade dia/noite (vento ↔ night.wav).

4. **Fase 4 — Polimento AAA**  
   - Música: menu, combate, dungeon.  
   - Mais variações de passos (neve, água, dungeon).  
   - Mais variações de hits e mortes.  
   - Ambientes por bioma/dungeon.

---

## 6. Resumo rápido

| Área | Tem | Precisa | Melhorar |
|-----|-----|---------|----------|
| Sistema | Settings, SoundManager, sliders | Buses Music/SFX, pool SFX | Rotear buses; pool no SoundManager |
| Player | Passos (grama), ataque (1 som) | Pulo, dano, morte, cura, dash, passos por superfície, som por arma | Variação por superfície e arma; conectar HealthComponent |
| Inimigos | Nada | Ataque, hit, morte | MobData ou sistema central com 1 som por tipo |
| Interação | Teleporte, hover/teleport no pad | Baú, interact, coleta, pickup | Chest, Interactable, HarvestController, pickup |
| UI | Nada conectado | Botão, hover, inventário | Usar button.mp3 e hover.mp3; inventário opcional |
| Música/Ambiente | 4 players em Level1 sem lógica | Crossfade dia/noite, música menu/combate/dungeon | Script de ciclo dia/noite + faixas por contexto |

Com isso, o projeto fica com uma base de áudio clara e um checklist objetivo para evoluir até um nível AAA.
