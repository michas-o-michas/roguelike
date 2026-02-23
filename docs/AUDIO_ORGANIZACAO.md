# Organização dos áudios — Rootfall

**Nenhum áudio fica solto na raiz.** Tudo está em subpastas. O **SoundManager** e as cenas referenciam apenas caminhos dentro de `UI/`, `ambient/`, `music/`, `player/` e `world/`.

---

## Estrutura de pastas (atual)

```
Assets/sounds/
├── UI/                  # Interface (botões, inventário, notificações)
│   ├── button.mp3       # ui_click
│   ├── hover.mp3        # ui_hover
│   ├── teleport.mp3     # Teleporte (Landingpad)
│   ├── open-inventory.wav
│   ├── player-select.mp3
│   ├── bell-notification.wav
│   ├── eat.wav          # player_heal
│   ├── fast-punch-2047.wav  # player_hurt
│   ├── teleporting-sound.wav
│   ├── music1.mp3
│   └── little-birds.wav
│
├── ambient/             # Ambiente (dia/noite, vento)
│   ├── windaudio.mp3    # Vento dia (Level1)
│   ├── night.wav        # Noite (Level1)
│   ├── day.wav
│   └── ambient-sound.mp3
│
├── music/               # Trilhas e jazz
│   ├── music_ingame.mp3 # Música in-game (Level1)
│   └── street-corner-jazz-cafe-338559.mp3
│
├── player/              # Jogador (passos, ataque, hurt/death/heal)
│   ├── attack_sword.mp3 # Ataque armas (player + items/*.tres)
│   ├── WASD Sound Grass Run 06.wav  # Passos (player.tscn)
│   ├── fast-sword.wav
│   ├── player_hurt.mp3  # (opcional; senão usa UI/fast-punch)
│   ├── player_death.mp3
│   └── player_heal.mp3  # (opcional; senão usa UI/eat.wav)
│
└── world/               # Mundo (baú, coleta)
    ├── chest_open.mp3   # (adicione quando tiver)
    └── harvest_complete.mp3
```

---

## Mapeamento ID → arquivo(s) tentados

O SoundManager tenta, por ID, os caminhos na ordem abaixo. O **primeiro que existir** é usado.

| ID | Caminhos tentados (ordem) |
|----|---------------------------|
| **ui_click** | `sounds/UI/button.mp3` |
| **ui_hover** | `sounds/UI/hover.mp3` |
| **ui_inventory_open** | `sounds/UI/open-inventory.wav` |
| **ui_select** | `sounds/UI/player-select.mp3` |
| **ui_notification** | `sounds/UI/bell-notification.wav` |
| **player_hurt** | `sounds/UI/fast-punch-2047.wav` → `sounds/player/player_hurt.*` |
| **player_death** | `sounds/player/player_death.*` |
| **player_heal** | `sounds/UI/eat.wav` → `sounds/player/player_heal.*` |
| **chest_open** | `sounds/world/chest_open.*` |
| **harvest_complete** | `sounds/UI/bell-notification.wav` → `sounds/world/harvest_complete.*` |

Extensões tentadas: `.mp3` e `.wav` quando houver `*`.

---

## Onde cada som toca

| ID | Onde |
|----|------|
| ui_click | Botões (menu, pause, settings) |
| ui_hover | Mouse sobre botão |
| ui_inventory_open | Abrir painel do inventário (tecla I) |
| ui_select | (Opcional) troca de slot / seleção |
| ui_notification | (Opcional) notificações gerais |
| player_hurt | Jogador leva dano |
| player_death | Morte do jogador |
| player_heal | Cura / poção |
| chest_open | Abrir baú (após gastar moedas) |
| harvest_complete | Recurso esgotado (árvore/pedra) |

---

## Dicas

- **Novo som:** coloque na subpasta correta (UI, ambient, music, player, world) e, se for um ID novo, adicione em `SoundManager._register_default_sounds()` ou use `SoundManager.register_sfx(&"meu_id", stream)` em código.
- **Música/ambiente longos:** use nós na cena (ex.: Level1) no bus **Music**; não use o pool de SFX.
- **Reorganizar de novo:** o script `scripts/organize_audio.ps1` já foi executado uma vez; não execute de novo para não duplicar movimentos. Para repor a estrutura do zero, restaure os áudios do controle de versão e rode o script novamente.
