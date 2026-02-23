# Estrutura esperada do Player (Rootfall)

Este documento descreve os nós que o **Player** deve ter para o jogo funcionar corretamente. Use como referência ao duplicar a cena ou criar variantes.

## Cena base

- **Raiz:** `CharacterBody3D` com script `Player/Player.gd` (ex.: `Player/player.tscn`).

---

## Nós obrigatórios

| Nó | Tipo | Descrição |
|----|------|-----------|
| **HealthComponent** | Nó com script `Componentes/HealthComponent.gd` | Vida, dano e morte do jogador. O Player define `base_health` e repassa para o componente em `_ready()`. |
| **WeaponHandler** | `Node3D` com script `Scripts/player/weapon_handler.gd` | Armas, ataques melee, projéteis e coleta (E em árvore/pedra). Deve ser filho direto do Player. |
| **Camera3D** (ou equivalente) | `Camera3D` | Câmera 3ª pessoa. Pode estar em subnó (ex.: dentro de um pivot). O `ThirdPersonCamera.gd` costuma controlar essa câmera. |
| **AttackArea** | `Area3D` com `CollisionShape3D` | Área de overlap para ataques melee (estilo roguelike). O WeaponHandler a encontra como irmão (`get_parent().get_node_or_null("AttackArea")`) se não for atribuída no Inspector. |
| **RayCast3D** | `RayCast3D` | Usado para snap no chão e `position_on_terrain()`. Opcional para movimento básico, mas necessário para o gerador de mundo posicionar o jogador no terreno. |

O Player deve estar no grupo **`player`** (adicionado em `Player.gd` em `_ready()`).

---

## Nós opcionais (recomendados)

| Nó | Tipo | Descrição |
|----|------|-----------|
| **StepAudio** | `AudioStreamPlayer3D` | Som de passos; o Player usa em `_process` quando andando/correndo. |
| **AnimationTree** | `AnimationTree` | Animação (Idle, Walk, Run, Attack). Caminho configurável por `animation_tree_path` no Inspector. |
| **AttackAudio** | `AudioStreamPlayer3D` | Filho do **WeaponHandler** (não do Player). Som de ataque; o WeaponHandler espera `$AttackAudio`. |
| **HandMarker** | `Node3D` | Onde a arma aparece na mão. Pode ser `Character/CharacterArmature/Skeleton3D/HandMarker` ou outro path; o WeaponHandler tenta fallbacks se não atribuído. |
| **InteractionManager** | Nó com script `Componentes/InteractionManager/InteractionManager.gd` | Mira e interação (E). Pode ser filho do Player ou irmão; precisa de `camera`, `ray_cast_3d` e, se existir, `prompt_label`. |

---

## WeaponHandler — referências no Inspector

No **WeaponHandler** (script `weapon_handler.gd`), configure no Inspector quando a estrutura da cena for diferente do padrão:

- **hand_marker:** Nó da mão (ex.: `Character/CharacterArmature/Skeleton3D/HandMarker`).
- **attack_area:** Area3D de melee (se não for irmã com nome `AttackArea`).
- **camera_node:** Câmera usada para projéteis e mira (se não for `Camera3D` no parent).
- **attack_raycast:** (Opcional) RayCast para mineração em alvo específico.
- **slot_display_melee / slot_display_staff / slot_display_axe / slot_display_pickaxe:** NodePaths para os pivots onde as armas ficam no corpo (costas/quadril). Se vazios, o script tenta fallback por nome no skeleton.

---

## Terceira pessoa (câmera)

O script `ThirdPersonCamera.gd` normalmente controla:

- Órbita ao redor do personagem (mouse).
- Distância (scroll).
- Pitch min/max.

A câmera pode ser filha do Player ou de um subnó (ex.: `CameraPivot`). O importante é que o **WeaponHandler** e o **InteractionManager** usem a mesma câmera para mira e projéteis.

---

## Resumo mínimo para funcionar

Para o jogo carregar e o personagem andar/atacar sem erros:

1. **CharacterBody3D** com `Player.gd`.
2. **HealthComponent** como filho.
3. **WeaponHandler** como filho (com `hand_marker` e `attack_area` configurados ou detectados por fallback).
4. **Camera3D** (ou pivot com câmera) para visão e, se usar staff/projéteis, referenciada em `camera_node` do WeaponHandler.
5. Nó no grupo **player**.

O resto (StepAudio, AnimationTree, InteractionManager, slots de arma no corpo) melhora a experiência mas não é obrigatório para um teste mínimo.
