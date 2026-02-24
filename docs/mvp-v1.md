# ROOTFALL — MVP v1

## Objetivo

Provar que o loop funciona:
> matar mobs → moedas → stats/dungeon → boss → morreu → recomeça

Se o jogador morrer e quiser imediatamente recomeçar, o MVP cumpriu seu papel.

---

## Loop Concreto do MVP

1. Nasce sem moedas no mundo
2. Mata lobos na superfície (3 moedas/kill)
3. Gasta moedas em stats (50/ponto) no menu de status
4. Acumula 200 moedas → paga para entrar na Dungeon 1
5. Enfrenta mobs mais fortes (5–8 moedas/kill)
6. Derrota o boss da Dungeon 1
7. Morre a qualquer momento → Game Over → recomeça do zero

---

## Checklist de Sistemas

### Mundo
- [x] Geração procedural infinita
- [x] Ciclo dia/noite
- [x] Dificuldade crescente por dia

### Combate
- [x] Espada, machado, staff
- [x] Inimigo: Lobo (superfície)
- [ ] Inimigo: Sentinela (dungeon, tier 5)
- [ ] Inimigo: Guardião (dungeon, tier 8)
- [ ] Boss da Dungeon 1

### Moedas e Progressão
- [x] Mobs dropam moedas por difficulty_tier
- [x] Stats comprados com moedas (StatsManager)
- [ ] Portal da dungeon com custo em moedas

### Dungeon
- [x] Sistema de dungeon (entra/sai sem trocar cena)
- [ ] Portal com custo de 200 moedas
- [ ] Spawners configurados com mobs de dungeon

### Game Over / Permadeath
- [ ] Tela de Game Over (dias + moedas)
- [ ] Reset completo ao recomeçar

---

## Mobs do MVP

| Mob | Local | HP | Dano | Tier | Coins/kill |
|---|---|---|---|---|---|
| Lobo | Superfície | 60 | 8 | 3 | 3 |
| Sentinela | Dungeon 1 | 80 | 12 | 5 | 5 |
| Guardião | Dungeon 1 | 150 | 20 | 8 | 8 |
| Boss | Dungeon 1 | 500 | 25 | — | 100 |

---

## O que NÃO entra no MVP

- Sistema de stamina
- Construção de base
- Múltiplas camadas de dungeon
- Narrativa explícita
- Co-op
- Crafting avançado (existe mas não é o foco)
