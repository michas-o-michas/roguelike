# Sistema de Inimigos e Mobs

## Estrutura

| Arquivo | Descrição |
|---------|-----------|
| `mob_data.gd` | Resource: id, display_name, mob_scene, behaviour (PASSIVE/AGGRESSIVE/PASSIVE_AGGRESSIVE/NEUTRAL), stats (max_health, damage, defense, speed), difficulty_tier. |
| `mob_registry.gd` | Autoload: carrega `.tres` de `res://data/mobs/`. `get_mob(id)`, `get_mobs_by_tier(tier)`. |
| `mob_base.gd` | Script do mob: HealthComponent, take_damage(amount, attacker), grupo "enemy", AI por comportamento. |
| `mob_spawner.gd` | Nó que spawne mobs quando o jogador está perto; usa MobData. |

## Como adicionar um novo mob

1. Criar `data/mobs/<id>.tres` (MobData) com id, display_name, behaviour, stats e referência à cena do mob.
2. Criar cena do mob em `Scenes/enemies/` (herdar de `mob_base.tscn` ou instanciar; script já está na base).
3. No `.tres`, apontar `mob_scene` para essa cena.
4. Criar `Scenes/enemies/<id>_spawner.tscn` (instância de `mob_spawner.tscn` com `mob_data` = o .tres).
5. Criar `world_generator_v2/spawners/<id>_spawner_data.tres` (AnimalSpawnerData com spawner_scene = a cena do passo 4).
6. Adicionar esse AnimalSpawnerData ao array `animal_spawners` da cena Level1 (ou do gerador de mundo usado).

## Animações

O **mob_base.gd** suporta animações de duas formas (opcional):

1. **AnimationTree** (recomendado): no Inspector do mob, em "Animações", defina **Animation Tree Path** apontando para um nó AnimationTree (ex. dentro do Model). O script chama `travel(nome)` nos estados: **Idle**, **Walk**, **Run**, **Attack**, **Death**.
2. **AnimationPlayer**: defina **Animation Player Path** para um AnimationPlayer. O script chama `play(nome)` com os mesmos nomes.

**Nomes de animação esperados:** `Idle`, `Walk`, `Run`, `Attack`, `Death`. Crie essas animações (ou só as que usar) no state machine ou no AnimationPlayer. O mob troca automaticamente: parado → Idle; andando → Walk; correndo (velocidade alta) → Run; ao atacar → Attack (por `attack_anim_duration` segundos); ao morrer → Death.

Se não definir nenhum path, o mob funciona normalmente sem animação.

## Integração

- **weapon_handler**: mobs no grupo `"enemy"` recebem `take_damage(damage, player)`.
- **HealthComponent**: cada mob tem um filho HealthComponent; stats aplicados em `_ready` a partir do MobData.
- **SpawnerManager**: instancia cenas de spawner (ex. wolf_spawner.tscn); cada spawner spawne instâncias do mob quando o jogador está em `activation_distance`.
