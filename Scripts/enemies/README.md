# Sistema de Mobs (genérico)

Base para qualquer tipo de mob: **lobo, vaca, coelho, zumbi, atirador**, etc.

## Ideia em uma frase

- **MobData (.tres)** = receita: “qual cena instanciar + stats + comportamento”.
- **Cena do mob (.tscn)** = o bicho (modelo, animações, colisão). Não referencia o .tres.
- **Spawner** = instancia a cena e chama `set_mob_data(mob_data)` com o .tres.

Assim não fica confuso: o .tres aponta para a cena; a cena não aponta para o .tres. No jogo o spawner sempre seta o MobData na instância.

## Arquivos

| Arquivo | Papel |
|--------|--------|
| **mob_data.gd** | Resource: id, display_name, **mob_scene**, behaviour, attack_type (MELEE/RANGED), stats. A “receita”. |
| **mob_base.gd** | Script base do mob: vida, AI, ataque melee, animações. Cena do mob herda de mob_base.tscn. |
| **mob_spawner.gd** | Spawne instâncias quando o jogador está perto; usa MobData para instanciar mob_scene e setar dados. |

## Comportamentos (Behaviour)

- **PASSIVE** — não ataca; pode fugir.
- **AGGRESSIVE** — persegue e ataca ao detectar.
- **PASSIVE_AGGRESSIVE** — ataca só se for atacado ou jogador muito perto.
- **NEUTRAL** — ataca só se for atacado.

## Tipo de ataque (AttackType)

- **MELEE** — corpo a corpo (padrão). Usa attack_radius, attack_area_path, etc.
- **RANGED** — atira de longe. Use uma cena que estenda mob_base e implemente disparo de projétil (ou script próprio).

## Animações

Na cena do mob, use nós **AnimationTree** e **AnimationPlayer** com esses nomes na raiz. O mob_base usa automaticamente (Idle, Walk, Run, Attack, Death). Só preencha paths no Inspector ou no MobData se os nós tiverem outro nome ou estiverem em outro nó.

## Adicionar um novo mob

1. Criar a **cena** do bicho (herdar de mob_base.tscn) → ex.: `cow.tscn`.
2. Criar o **MobData** `.tres` com mob_scene = `cow.tscn` e stats → ex.: `cow.tres`.
3. Criar o **spawner** que usa `cow.tres` → ex.: `cow_spawner.tscn`.
4. Registrar o spawner no mundo (Animal Spawners no Level1/gerador).

Detalhes em **COMO_CRIAR_UM_MOB.md**.
