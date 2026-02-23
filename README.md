# Rootfall

**Survival Roguelike 3D** — Godot 4.6

O mundo não está morrendo; está sendo abandonado pelas raízes que o sustentavam. Explore, colete, enfrente ameaças e desça pelas camadas em um mundo procedural vivo e instável.

---

## Como rodar

1. **Requisitos:** [Godot 4.6](https://godotengine.org/download) (ou 4.x compatível).
2. Abra o Godot e use **Import** → navegue até esta pasta e selecione **`project.godot`**.
3. Com o projeto aberto, pressione **F5** ou clique no botão **Play** (▶) para iniciar.
4. A cena principal é o **Main Menu**; de lá você entra no jogo (Level1) com loading do mundo procedural.

---

## Visão do jogo

- **Gênero:** Survival Roguelike 3D, singleplayer (co-op como possibilidade futura).
- **Loop:** Explorar → Coletar recursos e enfrentar ameaças → Voltar ao ponto seguro → Craftar e preparar → Descer a camadas mais profundas → Repetir.
- **Pilares:** Sobrevivência com pressão progressiva, exploração vertical, progressão com consequência, mundo vivo e reativo.
- **Documentação de visão e MVP:** `docs/readme.md`, `docs/mvp-v1.md`.

---

## Estrutura do projeto (resumo)

| Pasta / arquivo | Conteúdo |
|-----------------|----------|
| `Player/` | Cena e script do jogador, câmera 3ª pessoa, weapon handler. |
| `Scripts/` | Lógica de jogo: inventário, crafting, armas, magia, inimigos, UI, etc. |
| `Scenes/` | MainMenu, Level1, LoadingScreen, Settings, PauseMenu, UI, inimigos, partículas. |
| `world_generator_v2/` | Mundo procedural: chunks, terreno, biomas, vegetação, POIs, spawners. |
| `dungeon/` | Dungeons e portais. |
| `Componentes/` | HealthComponent, InteractionManager, barras de vida, etc. |
| `Interface/` | Interactable (E para interagir). |
| `items/` | Recursos de itens e armas (.tres), cenas de equipamento. |
| `docs/` | Visão, MVP, plano de inventário, estrutura do Player, relatório de análise. |

---

## Testes

- **Inventário e crafting:** Abra a cena `Tests/test_inventory_crafting.tscn` e rode com **F6** (Play cena atual). No console devem aparecer mensagens `[TEST] ✅` ou `[TEST] ❌`. Requer autoloads InventoryManager e CraftingManager (já configurados no projeto).

## Documentação útil

- **Estrutura esperada do Player:** `docs/PLAYER_STRUCTURE.md` (nós obrigatórios e opcionais).
- **Relatório de análise do projeto:** `docs/RELATORIO_ANALISE_PROJETO.md`.
- **Addon Mixamo (animações):** instruções abaixo.

---

# Mixamo Animation Retargeter for Godot 4.3

This plugin simplifies the process of importing and retargeting Mixamo animations in Godot 4.x projects.

## Features

- Adds a "Retarget Mixamo Animation" option to the right-click menu for FBX files in the FileSystem dock.
- Automatically sets up the correct import settings for Mixamo animations.
- Supports batch processing of multiple FBX files.
- Saves retargeted animations as separate .res files that can be added to Animation Libraries.

## Installation

1. Download or clone this repository.
2. Copy the `addons/mixamo_animation_retargeter` folder into your Godot project's `addons` folder.
3. Enable the plugin in Project Settings -> Plugins.

## Usage

1. Import your Mixamo FBX file(s) into your Godot project using ufbx.
2. In the FileSystem dock, right-click on the FBX file(s) you want to retarget.
3. Select "Retarget Mixamo Animation" from the context menu.
4. Choose a destination folder for the exported animation(s).
5. The plugin will automatically update the import settings, retarget the animation(s), and save them as .res files in the specified folder.
6. Ensure your character model has a Skeleton3D node named "Skeleton" for the exported animations to work correctly.
7. Ensure your Character Skeleton is also retargeted using Bone Mapping. This ensures both the animation and the skeleton will share the same bone names.
8. Add the exported .res files to an AnimationLibrary and you should be able to play the animations in the scene.

## Requirements

- Godot 4.3

## Configuration

The plugin uses a predefined bone map for Mixamo animations. If you need to customize the bone mapping, you can modify the `mixamo_bone_map.tres` file in the plugin folder.

## Known Issues

- Untested with older Godot versions.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

GNU GPLv3

## Credits

Developed by Matt Marcin @ RaidTheory

## Disclaimer

This plugin is not affiliated with or endorsed by Mixamo or Adobe. Mixamo and its logo are registered trademarks of Adobe Inc. All rights to Mixamo assets and branding belong to Adobe Inc.
