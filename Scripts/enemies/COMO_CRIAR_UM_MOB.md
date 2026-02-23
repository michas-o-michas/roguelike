# Como criar um mob (lobo, vaca, coelho, zumbi, atirador…)

O sistema é **genérico**: uma **receita** (.tres) diz qual **cena** instanciar e com quais stats. O **spawner** usa a receita e coloca o bicho no mundo.

---

## Fluxo (quem usa o quê)

```
MobData (wolf.tres)  ←  "receita": id, nome, qual cena, vida, dano, comportamento
    │
    │  mob_scene = wolf.tscn   (aponta para a cena)
    ▼
wolf.tscn  ←  a cena do bicho (modelo, animações, colisão). NÃO precisa ter wolf.tres dentro.
    │
    │  O spawner instancia wolf.tscn e chama set_mob_data(wolf.tres)
    ▼
No jogo: lobo aparece com stats e comportamento do wolf.tres
```

- **MobData (.tres)** = receita: "spawnar a cena X com esses stats e esse comportamento".
- **Cena do mob (.tscn)** = o bicho em si. **Não** coloque o .tres na cena; o spawner seta o MobData ao instanciar.
- Na cena do mob, o campo **mob_data** no Inspector é **opcional**: use só para testar a cena sozinha no editor (rodar a cena do lobo e ter vida/dano). No jogo, o spawner sempre seta.

---

## Passo 1: Criar a cena do mob

1. **Scene → New Inherited Scene** → base: `res://Scenes/enemies/mob_base.tscn`.
2. Salve como `Scenes/enemies/<nome>.tscn` (ex.: `wolf.tscn`, `cow.tscn`, `zombie.tscn`).
3. Adicione modelo 3D, colisão, etc. no nó **Model** (ou na raiz, conforme a base).
4. **Animações (opcional):** adicione na raiz os nós **AnimationTree** e **AnimationPlayer** (com esses nomes). O script usa automaticamente; não precisa preencher paths. O AnimationTree deve ter `anim_player` apontando para o AnimationPlayer.
5. **Não preencha** `mob_data` na cena (deixe vazio). Só preencha se for testar a cena sozinha no editor.

**Resultado:** uma cena que é o "corpo" do mob (visual + física). Ela não referencia nenhum .tres.

---

## Passo 2: Criar a receita (MobData .tres)

1. Clique direito em `data/mobs/` → **New Resource** → **MobData** (ou Resource e escolha o script).
2. Salve como `data/mobs/<id>.tres` (ex.: `wolf.tres`, `cow.tres`).
3. No Inspector:
   - **Id:** `wolf` (nome interno).
   - **Display Name:** `Lobo`.
   - **Mob Scene:** arraste a cena do **Passo 1** (ex.: `Scenes/enemies/wolf.tscn`). É a única ligação: a receita aponta para a cena.
   - **Behaviour:** PASSIVE / AGGRESSIVE / PASSIVE_AGGRESSIVE / NEUTRAL.
   - **Attack Type:** MELEE (corpo a corpo) ou RANGED (atirador — use cena com lógica de projétil).
   - **Max Health, Damage, Defense, Speed**, etc.
   - **Detection Radius:** ex. 30 (raio em que detecta o jogador).
   - **Attack Radius / Attack Cooldown:** para MELEE.
   - **Difficulty Tier:** 1–10.

**Resultado:** um .tres que diz "instanciar wolf.tscn com esses stats". A cena não aponta de volta para o .tres.

---

## Passo 3: Criar o spawner desse mob

1. **Scene → New Scene** → raiz **Node3D**.
2. Anexe o script `res://Scripts/enemies/mob_spawner.gd`.
3. No Inspector do spawner: **Mob Data** = arraste o .tres do Passo 2 (ex.: `data/mobs/wolf.tres`).
4. Salve como `Scenes/enemies/<nome>_spawner.tscn` (ex.: `wolf_spawner.tscn`).

**Resultado:** uma cena de spawner que, quando colocada no mundo, instancia a cena do mob e passa o MobData para ela.

---

## Passo 4: Registrar no mundo (Level1 / gerador)

1. Abra a cena do nível (ex.: `Scenes/Level1.tscn`).
2. No nó do **InfiniteWorldGenerator** (ou gerador usado), em **Animal Spawners**, adicione o recurso do spawner (ex.: `world_generator_v2/spawners/wolf_spawner_data.tres`).
3. O recurso `wolf_spawner_data.tres` deve ter **Spawner Scene** = `wolf_spawner.tscn`.

**Resultado:** o mundo passa a spawne lobos (ou o mob que você configurou) quando o jogador se aproxima.

---

## Resumo: quem referencia quem

| Quem            | Referencia        | Para quê |
|-----------------|-------------------|----------|
| **wolf.tres**   | wolf.tscn         | Saber qual cena instanciar |
| **wolf.tscn**   | Nada (ou mob_data só para teste) | Ser o bicho |
| **wolf_spawner.tscn** | wolf.tres   | Saber qual mob spawne e quais stats passar |
| **Spawner (em runtime)** | Instancia wolf.tscn e chama set_mob_data(wolf.tres) | Colocar o lobo no mundo com a receita certa |

Assim você pode criar vaca, coelho, zumbi, atirador: crie a cena do bicho, crie o .tres apontando para essa cena, crie o spawner que usa o .tres. A cena do mob nunca precisa "ter" o .tres dentro.
