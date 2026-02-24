# ROOTFALL

## Documento de Visão

---

## 1. Conceito

**Rootfall** é um roguelike 3D de sobrevivência onde o jogador começa sem nada em um mundo hostil que fica progressivamente mais perigoso a cada noite.

O loop é simples e direto:

> **Matar mobs → ganhar moedas → ficar mais forte → entrar em dungeons → boss**

Morre? Começa do zero.

---

## 2. Loop de Gameplay

```
1. Nasce no mundo com 0 moedas
2. Explora e mata mobs da superfície
3. Gasta moedas em stats (vida, dano, velocidade...)
4. Paga para entrar em dungeons
5. Dentro da dungeon: mobs mais difíceis, mais moedas
6. Avança até o boss
7. Morre → game over → recomeça do zero
```

---

## 3. Ciclo Dia/Noite

- **Dia:** mobs presentes mas comportamento normal
- **Noite:** mobs com detecção 50% maior, spawnam 2x mais, 2x mais rápido
- **Cada novo dia:** dificuldade sobe — mais mobs, mais fortes, mais coins por kill

---

## 4. Economia de Moedas

Moedas são a única progressão. Tudo gira em torno delas.

| Fonte | Quantidade |
|---|---|
| Lobo (superfície) | 3 moedas/kill |
| Sentinela (dungeon 1) | 5 moedas/kill |
| Guardião (dungeon 1) | 8 moedas/kill |
| Boss | 100+ moedas |

| Gasto | Custo |
|---|---|
| 1 ponto de atributo | 50 moedas |
| Entrar na Dungeon 1 | 200 moedas |
| Entrar na Dungeon 2 | 500 moedas |

---

## 5. Stats (comprados com moedas)

| Atributo | Bônus por ponto |
|---|---|
| Vida | +10 HP |
| Dano | +2 |
| Velocidade | +0.5 m/s |
| Defesa | +2 |
| Vel. Ataque | +5% |

---

## 6. Dungeons

- Entrada paga (custo em moedas visível no portal)
- Mobs internos com difficulty_tier maior = mais moedas/kill
- Boss no final: inimigo com mecânica única
- Saída disponível a qualquer momento

---

## 7. Permadeath

Ao morrer:
- **Tela de Game Over:** dias sobrevividos + moedas acumuladas
- **Reset completo:** moedas, stats, inventário
- O mundo recomeça do Dia 1

---

## 8. Frase-Guia

> *Cada moeda é uma decisão: ficar mais forte agora ou arriscar entrar na dungeon.*
