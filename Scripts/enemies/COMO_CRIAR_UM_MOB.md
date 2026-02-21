# Como criar um mob (ex.: lobo, urso, coelho)

O sistema usa **5 peças** que se encaixam assim:

```
Level1 (ou sua cena de mundo)
  └── animal_spawners = [ wolf_spawner_data.tres, ... ]
           │
           ▼
wolf_spawner_data.tres (AnimalSpawnerData)
  └── spawner_scene = wolf_spawner.tscn
           │
           ▼
wolf_spawner.tscn (instância do MobSpawner)
  └── mob_data = wolf.tres
           │
           ▼
wolf.tres (MobData)
  └── mob_scene = wolf.tscn   +  stats (vida, dano, comportamento)
           │
           ▼
wolf.tscn (instância do mob_base.tscn)
  └── é a cena que aparece no mundo (o bicho em si)
```

Ou seja: **o mundo** spawne **spawners**; cada **spawner** usa um **MobData** para spawne a **cenas do mob**.

---

## Passo 1: Criar a cena do mob (o bicho em si)

**O que é:** a cena que representa o inimigo no mundo (CharacterBody3D com vida, colisão, etc.).

**Como fazer:**

1. No Godot: **Scene → New Inherited Scene** (ou “Nova cena herdada”).
2. Escolha **`res://Scenes/enemies/mob_base.tscn`** como cena base.
3. Salve como **`Scenes/enemies/<nome>.tscn`** (ex.: `wolf.tscn`, `bear.tscn`, `rabbit.tscn`).
4. (Opcional) Renomeie o nó raiz no Inspector: ex. "Wolf", "Bear".
5. (Opcional) Adicione um modelo 3D como filho do nó **Model** dentro da cena (o mob_base já tem esse nó vazio).

**Resultado:** você tem uma cena que **herda** de `mob_base.tscn`. Não precisa de script novo; o comportamento vem do MobData que vamos criar.

---

## Passo 2: Criar o recurso MobData (.tres)

**O que é:** a “ficha” do mob: id, nome, qual cena usar, vida, dano, defesa, velocidade e **comportamento** (passivo, agressivo, etc.).

**Como fazer:**

1. No Godot: **clique direito na pasta `data/mobs/`** (crie a pasta se não existir) → **New Resource**.
2. Procure por **MobData** (ou “Resource” e depois no Inspector escolha **Script** = `res://Scripts/enemies/mob_data.gd`).
3. Salve como **`data/mobs/<id>.tres`** (ex.: `wolf.tres`, `bear.tres`). O **id** é o nome interno do mob (ex.: `"wolf"`).
4. No Inspector, preencha:
   - **Id:** `wolf` (mesmo nome do arquivo, sem .tres).
   - **Display Name:** `Lobo` (nome bonito para UI/debug).
   - **Mob Scene:** arraste a cena do **Passo 1** (ex.: `Scenes/enemies/wolf.tscn`).
   - **Behaviour:**  
     - `0` = PASSIVE (não ataca; pode fugir)  
     - `1` = AGGRESSIVE (persegue e ataca)  
     - `2` = PASSIVE_AGGRESSIVE (só ataca se for atacado ou jogador muito perto)  
     - `3` = NEUTRAL (só revida quando atacado)
   - **Max Health:** ex. `50`.
   - **Damage:** ex. `12` (dano ao jogador quando encostar).
   - **Defense:** ex. `0`.
   - **Speed:** ex. `6`.
   - **Difficulty Tier:** `1` a `10` (1 = fácil perto do spawn; o SpawnerManager usa isso para decidir onde spawne).

**Resultado:** um arquivo `.tres` que define “quem é” o mob e qual cena instanciar.

---

## Passo 3: Criar a cena do spawner desse mob

**O que é:** um nó que fica no mundo e, quando o jogador se aproxima, cria várias cópias do seu mob (ex.: lobos). Cada tipo de mob tem a **mesma** lógica de spawn, mas com **MobData** diferente.

**Como fazer:**

1. **Scene → New Scene** → raiz **Node3D**.
2. Com a raiz selecionada, no Inspector clique em **Attach Script** e escolha **`res://Scripts/enemies/mob_spawner.gd`** (ou arraste o script para o nó).
3. No Inspector, no script do **MobSpawner**, defina:
   - **Mob Data:** arraste o recurso do **Passo 2** (ex.: `data/mobs/wolf.tres`).
   - (Opcional) **Activation Distance**, **Max Mobs**, **Spawn Interval**, **Spawn Radius** — já têm valores padrão.
4. Salve a cena como **`Scenes/enemies/<nome>_spawner.tscn`** (ex.: `wolf_spawner.tscn`).

**Resultado:** uma cena que, quando colocada no mundo (pelo SpawnerManager), spawne o mob definido no `mob_data`.

---

## Passo 4: Criar o AnimalSpawnerData (liga o spawner ao mundo)

**O que é:** o recurso que o **gerador de mundo** (InfiniteWorldGenerator) usa para decidir **quando** e **onde** colocar os spawners (ex.: “spawners de lobo” em bioma X, tier 1).

**Como fazer:**

1. Clique direito em **`world_generator_v2/spawners/`** → **New Resource**.
2. Procure **AnimalSpawnerData** (script: `res://world_generator_v2/animal_spawner_data.gd`).
3. Salve como **`world_generator_v2/spawners/<nome>_spawner_data.tres`** (ex.: `wolf_spawner_data.tres`).
4. No Inspector:
   - **Spawner Name:** ex. `Lobos` (nome para debug/log).
   - **Spawner Scene:** arraste a cena do **Passo 3** (ex.: `Scenes/enemies/wolf_spawner.tscn`).
   - **Difficulty Tier:** mesmo conceito do MobData (ex. `1`).
   - **Min Height / Max Height:** altura do terreno em que esse spawner pode aparecer (ex. 0 e 20).
   - **Allowed Biomes:** (opcional) lista de nomes de biomas; vazio = qualquer bioma.

**Resultado:** um `.tres` que diz “use a cena wolf_spawner.tscn quando for spawne de lobos”.

---

## Passo 5: Registrar no nível (Level1 ou sua cena de mundo)

**O que é:** dizer ao mundo **quais** spawners podem aparecer (lobos, ursos, etc.).

**Como fazer:**

1. Abra a cena onde está o **InfiniteWorldGenerator** (ex.: **`Scenes/Level1.tscn`**).
2. Selecione o nó do gerador (ex. “Level1”).
3. No Inspector, ache a propriedade **Animal Spawners** (array).
4. Aumente o tamanho do array (ex. +1) e no novo slot arraste o recurso do **Passo 4** (ex.: `world_generator_v2/spawners/wolf_spawner_data.tres`).

**Resultado:** quando o jogador explorar o mundo, o SpawnerManager vai instanciar spawners de lobo (e de outros que você colocou no array); cada spawner, por sua vez, vai instanciar lobos quando o jogador se aproximar.

---

## Resumo em uma frase por arquivo

| Arquivo | O que é |
|--------|---------|
| `Scenes/enemies/wolf.tscn` | O lobo em si (herda de mob_base). |
| `data/mobs/wolf.tres` | Ficha do lobo: cena + stats + comportamento. |
| `Scenes/enemies/wolf_spawner.tscn` | Nó que spawne lobos quando o jogador chega perto (usa wolf.tres). |
| `world_generator_v2/spawners/wolf_spawner_data.tres` | Config do mundo: “onde/como colocar spawners de lobo”. |
| **Level1** → **animal_spawners** | Lista de “quais spawners o mundo pode usar” (inclui wolf_spawner_data). |

Para criar **outro** mob (ex.: urso): repita os 5 passos trocando “wolf” por “bear” e ajustando stats e comportamento no `.tres` do MobData.
