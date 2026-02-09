# ROOTFALL

## Documento de Visão de Jogo

---

## 1. Visão Geral

**Nome:** Rootfall
**Gênero:** Survival Roguelike 3D
**Engine:** Godot 4.6
**Plataforma alvo:** PC (inicialmente)
**Modo:** Singleplayer (co-op como possibilidade futura)

### Fantasia Central

> *O mundo não está morrendo — ele está sendo abandonado pelas próprias raízes que o sustentavam.*

Em **Rootfall**, o jogador explora um mundo vivo, antigo e instável, sustentado por raízes colossais que conectam a superfície a camadas profundas do planeta. Com o colapso dessas raízes, biomas entram em decadência, criaturas emergem e a sobrevivência exige adaptação constante.

O jogo mistura **sobrevivência sistêmica** com **progressão roguelike**, onde cada descida às profundezas é uma aposta: quanto mais fundo, maior o risco — e maior a transformação do mundo e do jogador.

---

## 2. Pilar de Design

Rootfall se sustenta em **quatro pilares fundamentais**:

### 2.1 Sobrevivência com Pressão Progressiva

* Recursos são limitados e distribuídos de forma desigual
* O mundo se torna mais hostil com o tempo e profundidade
* Segurança nunca é permanente

### 2.2 Exploração Vertical

* O progresso não é apenas horizontal (mapa), mas **vertical** (camadas)
* Cada nova camada desbloqueia mecânicas, riscos e narrativas

### 2.3 Progressão com Consequência

* Escolhas moldam o estilo do personagem
* Builds não são infinitas — toda força vem com custo

### 2.4 Mundo Vivo e Reativo

* Biomas evoluem, entram em colapso ou se corrompem
* Inimigos e recursos refletem o estado do mundo

---

## 3. Game Loop Principal

### Loop Central

1. **Explorar a Superfície / Camada Atual**
2. **Coletar Recursos & Enfrentar Ameaças**
3. **Retornar a um Ponto Seguro (Root Camp)**
4. **Craftar, Evoluir, Preparar-se**
5. **Descer para Camadas Mais Profundas**
6. **Desencadear Mudanças no Mundo**
7. **Repetir com Novas Condições**

### Loop Emocional

* Curiosidade → Tensão → Risco → Alívio → Poder → Novo Medo

---

## 4. Estrutura do Mundo

### 4.1 Camadas do Mundo

O mundo é dividido em **camadas verticais**, cada uma representando um estágio de decadência das raízes.

Exemplo:

1. **Superfície Viva**

   * Biomas relativamente estáveis
   * Recursos básicos
   * Ameaças previsíveis

2. **Raízes Expostas**

   * Terreno instável
   * Inimigos adaptativos
   * Primeiros eventos de colapso

3. **Subsolo Antigo**

   * Ambientes opressivos
   * Escassez real
   * Criaturas ligadas às raízes

4. **Núcleo Corrompido**

   * Mundo hostil e mutável
   * Regras quebradas
   * Bosses estruturais

---

## 5. Estrutura de Biomas

Cada camada contém **biomas proceduralmente combinados**, definidos por:

* Tipo de raiz dominante
* Estado (vivo, apodrecendo, corrompido)
* Temperatura
* Umidade

### Exemplos de Biomas

* **Floresta de Raízes Vivas** – abundância, mas predadores territoriais
* **Campos Fúngicos** – cura passiva + venenos
* **Cavernas Ósseas** – recursos raros, alta letalidade
* **Desertos de Cinzas** – baixa visibilidade, inimigos emboscadores

---

## 6. Sistema de Progressão

### 6.1 Progressão Roguelike

* Cada run altera o mundo permanentemente
* Mortes não resetam tudo, mas deixam cicatrizes

### 6.2 Raízes como Metaprogressão

O jogador absorve **Essências de Raiz**, usadas para:

* Desbloquear habilidades passivas
* Modificar regras do mundo
* Acessar novas camadas

### 6.3 Builds

* Combate direto
* Mobilidade
* Sustentação
* Risco alto / recompensa alta

Cada build fecha portas para outras.

---

## 7. Combate – Revisão de Feeling

### Objetivo

Combate deve ser **pesado, legível e perigoso**.

### Princípios

* Poucos golpes, impacto alto
* Erro é punido
* Stamina é mais importante que vida

### Diretrizes

* Ataques com *commitment* (não canceláveis facilmente)
* Inimigos com telegraph claro
* Knockback significativo
* Feedback audiovisual forte

### Fantasia do Combate

> *Você não dança com os inimigos — você sobrevive a eles.*

---

## 8. Crafting e Sobrevivência

* Crafting orientado a preparação, não spam
* Bancadas específicas por camada
* Itens degradam

### Tipos de Itens

* Temporários (run-based)
* Permanentes (meta)

---

## 9. Identidade do Jogo

### Tom

* Melancólico
* Hostil
* Misterioso

### Sensação desejada

* Solidão
* Descoberta
* Superação

---

## 10. Objetivo Final

Rootfall não é sobre vencer o mundo.

É sobre **entender por que ele está caindo** — e decidir se vale a pena salvá-lo.

---

## 11. Frase-Guia

> *Quanto mais fundo você vai, menos o mundo se parece com algo que queria ser salvo.*
