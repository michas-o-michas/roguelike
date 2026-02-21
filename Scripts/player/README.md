# Scripts do Player

Scripts específicos do jogador (complementam a cena `Player/player.tscn` e `Player/Player.gd`).

## Estrutura

| Arquivo | Uso |
|---------|-----|
| `weapon_handler.gd` | Equipar armas, ataque melee/ranged, mineração, swing visual. **Única fonte de input de ataque** (attack/mb1); chama `Player.play_attack_animation()`. |

## Nós na cena do Player (ordem lógica)

- **HealthComponent** – Vida, dano, defesa, i-frames (invencibilidade após hit).
- **WeaponHandler** – Arma equipada e ataques.
- **AttackArea** – Área de overlap para melee.
- **Camera3D** – Câmera em terceira pessoa (referência opcional no WeaponHandler para projéteis).
- **StepAudio**, **RayCast3D**, **UI**, etc.

## Integração

- **Player.gd**: movimento, pulo, dash, câmera, animações; delega vida/dano ao `HealthComponent` e expõe `take_damage()`, `heal()`, `get_health_component()`.
- **SkillManager**: usa `player.get_health_component()` para bônus de vida e `player.base_max_jumps` para bônus de pulos.
- **Inimigos**: chamar `player.take_damage(amount)` para machucar o jogador (respeita i-frames e defesa).
