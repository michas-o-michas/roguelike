# Relatório de Análise do Projeto — Rootfall

**Data:** 21/02/2025  
**Escopo:** Análise de estrutura, sistemas, qualidade de código e alinhamento com a visão do jogo.

---

## 1. Visão geral do projeto

| Item | Valor |
|------|--------|
| **Nome** | Rootfall |
| **Versão** | 0.1 |
| **Engine** | Godot 4.6 |
| **Renderização** | Forward+, D3D12 (Windows) |
| **Física** | Jolt Physics |
| **Gênero** | Survival Roguelike 3D |
| **Cena principal** | `Scenes/MainMenu.tscn` (uid 44gkbea22p70) |

**Fluxo de entrada:** MainMenu → Level1 (com loading) → mundo procedural + dungeons + player.

---

## 2. Inventário do que existe

### 2.1 Scripts GDScript (~83 arquivos .gd)

- **Autoloads (singletons):** SettingsManager, DungeonManager, GameManager, InventoryManager, CraftingManager, WeaponSystem, ScreenFade, SoundManager, MobRegistry, ToolSelectionManager, SpellManager.
- **Player:** `Player.gd`, `ThirdPersonCamera.gd`, `weapon_pivot.gd`, `player_ui.gd`, `weapon_handler.gd`.
- **Inventário/Craft:** `inventory_manager.gd`, `crafting_manager_json.gd`, UI (inventory_ui, inventory_slot, hotbar, hotbar_spells, crafting_ui, recipe_card).
- **Mundo procedural:** `InfiniteWorldGenerator.gd`, TerrainMeshBuilder, ChunkCollisionBuilder, VegetationBuilder, GrassCircleManager, WaterHelper, POIManager, SpawnerManager, biome_data, poi_data, etc.
- **Inimigos:** mob_registry, mob_spawner, mob_base, mob_data.
- **Interação/Recursos:** Interactable, InteractionManager, ResourceNode, HealthComponent, floating_health_bar.
- **Combate/Itens:** weapon.gd, item.gd, MagicProjectile, Chest, pickup.
- **Dungeon:** DungeonManager, room, scene_portal, portal_spawn, spawn_at_marker.
- **Outros:** DayNightCycle, SkillManager, SettingsManager, GameManager, TreeWind, PropWithVariants, etc.

### 2.2 Cenas (~70 .tscn)

- **Fluxo:** MainMenu, Level1, LoadingScreen, Settings, PauseMenu.
- **Player:** player.tscn.
- **UI:** inventory_ui, hotbar, hotbar_spells, inventory_slot, inventory_slot_spell, recipe_card, ItemViewer.
- **Mundo:** Tree, Stone, grass, Landingpad, DayNightCycle; árvores/vegetação em Assets e world_generator_v2.
- **Combate/Itens:** MagicProjectile; axe, pickaxe, staff, sword em items/Scenes.
- **Inimigos:** mob_base, mob_spawner, wolf, wolf_spawner.
- **Componentes:** FloatingHealthBar, HealthComponent, InteractionManager, DamageNumber.
- **Dungeon:** dungeon_lv_1, dungeon_lv_2, temple.
- **Efeitos:** ResourceHitParticles, AmbientParticles, ChunkAmbientParticles, TeleportParticles.

### 2.3 Recursos e dados

- **Itens/armas:** axe.tres, pickaxe.tres, wood_sword.tres, staff.tres (items/).
- **Receitas:** Recipes/recipes.json + crafting_manager_json.
- **Biomas/POI:** world_generator_v2 (BiomeData, ItemVariant, BiomeItem, POIData, WorldTheme).
- **Mobs:** data/mobs (ex.: wolf.tres).
- **Skills:** Skills/hp_level*.tres.
- **Addon:** mixamo_animation_retargeter.

---

## 3. Sistemas principais e dependências

| Sistema | Função | Consumidores principais |
|--------|--------|---------------------------|
| **InventoryManager** | Slots, itens (Item), moedas, API por id | weapon_handler, ToolSelectionManager, inventory_slot, inventory_ui, crafting_ui, ResourceNode, pickup, Chest |
| **CraftingManager** | item_registry (id→Item), receitas JSON, craft | InventoryManager, WeaponSystem, crafting_ui, recipe_card |
| **WeaponSystem** | Acesso a armas por id | weapon_handler |
| **SpellManager** | Slots de magia, spell selecionado | weapon_handler, hotbar_spells |
| **ToolSelectionManager** | Ferramenta ativa (axe, pickaxe, staff) | weapon_handler, hotbar, hotbar_spells, ResourceNode, inventory_slot |
| **GameManager** | Loading, progresso da geração, ligação LoadingScreen ↔ InfiniteWorldGenerator | main_menu, InfiniteWorldGenerator, test_scene_setup |
| **DungeonManager** | Arena + dungeons, portais | Level1_main |
| **MobRegistry** | Registro de mobs a partir de .tres | mob_spawner, SpawnerManager |
| **InteractionManager** | Raycast E, Interactable, outline | Player (via nó na cena) |

Migração de inventário (GameManager → InventoryManager) está documentada como concluída em `docs/plano-unificar-inventario.md`.

---

## 4. Qualidade de código

### 4.1 Pontos positivos

- **Tipagem:** Uso consistente de tipos em GDScript 2.0 (`var x: int`, `func f() -> void`), principalmente em Player, weapon_handler, inventory_manager, ResourceNode, crafting_manager.
- **Documentação em código:** Comentários `##` e blocos “Como usar” em weapon_handler, weapon.gd, item.gd, crafting_manager, inventory_manager.
- **Exports organizados:** `@export_group` e `@export` bem usados (weapon_handler, Player, InfiniteWorldGenerator), facilitando tuning no editor.
- **Sinais:** Uso adequado de sinais para desacoplamento (inventory_changed, weapon_equipped, depleted, world_generation_progress, etc.).
- **Null-safety:** Verificações `get_node_or_null()`, `is_instance_valid()`, checagem de autoloads (ex.: ResourceNode verifica ToolSelectionManager e InventoryManager).
- **Tratamento de erro:** Uso de `push_warning` e `push_error` em pontos críticos (crafting_manager, weapon_handler, InfiniteWorldGenerator, scene_portal, main_menu, etc.).
- **Recursos bem modelados:** Item/Weapon com enums (Type, Rarity, ToolSlot, AttackEffect, ProjectileType), clara separação entre item genérico e arma.
- **Interface Interactable:** Contrato claro (get_display_label, interact, on_focus_enter/exit); ResourceNode integrado via try_start_harvest.

### 4.2 Pontos de atenção

- **Arquivos muito grandes:**  
  - `InfiniteWorldGenerator.gd` (~1386 linhas): concentra terreno, POIs, spawners, vegetação, grama, água, rebase de origem, LOD. Vale dividir em módulos (ex.: TerrainGeneration, POIGeneration, VegetationGeneration) ou extrair responsabilidades para nós/scripts auxiliares.  
  - `weapon_handler.gd` (~529 linhas): melee, mineração, projéteis, slots no corpo, coleta. Possível extrair “HarvestController” e “ProjectileLauncher” para reduzir complexidade.

- **Acoplamento a estrutura de cena:** weapon_handler e Player assumem paths específicos (HandMarker, AttackArea, Camera3D, HealthComponent). Falta de nós quebra em cenas alternativas; fallbacks ajudam, mas um documento “estrutura esperada do player” ou prefab recomendado reduziria erros.

- **Interactable restrito a ResourceNode:** Em `Interactable.interact()` só se chama `(get_parent() as ResourceNode).try_start_harvest(interactor)`. Qualquer outro tipo de interação (baús, NPCs, portais) precisaria estender ou substituir essa lógica — hoje o design é “interação = recurso”.

- **Sem testes automatizados:** Nenhum framework de testes (ex.: GUT) ou CI. Apenas cenas/scripts de teste manual (test_scene_setup, test_scene_manager, pasta Testes/). Para um projeto que cresce, testes unitários em inventário, crafting e fórmulas de dano seriam úteis.

- **Duplicação de responsabilidade de “player”:** Player.gd expõe base_damage, damage, attack_speed; o dano real vem da arma no weapon_handler. SkillManager e outros sistemas precisam saber onde ler “dano atual” (arma vs bônus do player) — um único ponto de verdade (ex.: “dano efetivo = weapon_handler.get_current_damage()”) evitaria confusão.

- **Hardcoded e magic numbers:** Ex.: índices de slots de equipamento (29–32) em InventoryManager; alguns valores em InfiniteWorldGenerator. Constantes nomeadas já existem (SLOT_EQUIP_MELEE, etc.); revisar outros números (distancias, tempos) e centralizar onde fizer sentido.

### 4.3 Consistência e convenções

- Nomenclatura: mistura de snake_case em arquivos (.gd) e PascalCase em classes/cenas; aceitável para Godot.
- Comentários em português e inglês; predominância de português em docs e comentários de alto nível.
- Nenhum TODO/FIXME relevante encontrado nos scripts (apenas um falso positivo em floating_health_bar.gd).

---

## 5. Documentação existente

- **docs/readme.md:** Visão do jogo, pilares, loop, camadas, biomas, combate, crafting, identidade.
- **docs/mvp-v1.md:** Escopo do MVP, loop concreto, camadas (Superfície Viva, Raízes Expostas), biomas, inimigos, boss, progressão, critérios de “MVP pronto”.
- **docs/plano-unificar-inventario.md:** Migração GameManager → InventoryManager (concluída); referência de API por id.
- **Scripts/enemies/README.md** e **COMO_CRIAR_UM_MOB.md:** Como criar mobs.
- **Scripts/player/README.md:** Documentação do player.
- **README.md na raiz:** Fala do addon Mixamo, não do jogo em si — quem clona o repositório pode esperar descrição do Rootfall na raiz.

---

## 6. Alinhamento com a visão e o MVP

- **Visão (docs/readme.md):** Survival roguelike 3D, exploração vertical, mundo vivo, progressão com consequência. Documento claro e coerente.
- **MVP (docs/mvp-v1.md):** Foco em loop jogável, 2 camadas, 4 biomas, 6 inimigos, 1 boss, crafting enxuto (15–25 receitas), sem multiplayer/construção livre.
- **Estado atual:**  
  - Mundo procedural (chunks, biomas, POIs, spawners, vegetação, grama, água), dungeons (níveis 1 e 2), ciclo dia/noite, combate (melee + staff/projéteis), coleta (machado/picareta), inventário unificado, crafting por JSON, magia (SpellManager), skills (SkillManager), interação (E) e portais/landing pads estão implementados.  
  - Ainda não está claro no código: “Superfície Viva” vs “Raízes Expostas” como camadas distintas de conteúdo (biomas/ameaças específicos do MVP), Root Camp explícito, boss “Guardião do Colapso”, metaprogressão (essências de raiz). Ou seja: a base técnica cobre grande parte do MVP; a curadoria de conteúdo e a progressão narrativa/camadas ainda dependem de design e conteúdo.

---

## 7. Resumo executivo

| Aspecto | Avaliação | Comentário |
|--------|-----------|------------|
| **Estrutura do projeto** | Boa | Pastas por domínio (Player, Scripts, Scenes, world_generator_v2, dungeon, Componentes, Interface). Autoloads bem definidos. |
| **Qualidade de código** | Boa, com ressalvas | Tipagem, sinais, exports e tratamento de erro bons; 2 scripts muito grandes e algum acoplamento a estrutura de cena. |
| **Documentação** | Boa | Visão, MVP e plano de inventário bem descritos; README na raiz não descreve o jogo. |
| **Testes e CI** | Fraca | Apenas testes manuais; sem testes automatizados nem pipeline de CI. |
| **Completude do MVP** | Parcial | Sistemas principais existem; falta fechar camadas, Root Camp, boss e metaprogressão conforme doc do MVP. |

---

## 8. Recomendações prioritárias

1. **Refatorar InfiniteWorldGenerator.gd:** Extrair geração de terreno, POIs, vegetação e spawners para classes/nós dedicados; manter o nó principal como orquestrador e para exports.
2. **Refatorar weapon_handler.gd:** Separar lógica de coleta (harvest) e de projéteis em componentes ou nós filhos, mantendo a API atual no WeaponHandler.
3. **Documentar estrutura do Player na raiz ou em docs:** Listar nós obrigatórios (HealthComponent, WeaponHandler, Camera3D, AttackArea, etc.) e opcionais para evitar quebras em novas cenas.
4. **Estender Interactable:** Permitir que outros tipos (baú, NPC, portal) implementem `interact()` sem depender de ResourceNode como pai; por exemplo, delegar para um componente no próprio nó.
5. **Introduzir testes automatizados:** Começar por inventário (add/remove/has_item, slots de equipamento) e crafting (receitas, consumo); depois fórmulas de dano/coleta se forem críticas para balanceamento.
6. **Atualizar README na raiz:** Incluir uma seção “Rootfall” com visão curta, como rodar (Godot 4.6), e link para docs/ (visão, MVP).

---

*Relatório gerado a partir de análise estática do repositório e leitura dos arquivos de código e documentação listados.*
