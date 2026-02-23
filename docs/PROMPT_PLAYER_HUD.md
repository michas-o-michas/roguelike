# Prompt para gerar a Player HUD — Rootfall

Use o texto abaixo como prompt para o GPT (ou outro modelo) gerar **toda a Player HUD** do projeto Rootfall, integrada aos sistemas existentes.

---

## Prompt (copie e cole)

```
Você vai gerar a Player HUD completa para o jogo Rootfall, um survival roguelike 3D em Godot 4.6 com GDScript 2.0. O jogo tem tema de mundo vivo, raízes e decadência — a HUD pode ter estética orgânica/terrosa, mas deve ser legível e funcional.

### Requisitos técnicos

- **Engine:** Godot 4.6  
- **Linguagem:** GDScript 2.0, com tipagem estática onde fizer sentido (`var x: int`, `func f() -> void`).  
- **Estrutura:** A HUD deve ser um único `CanvasLayer` (ou cena principal que contenha um) que possa ser instanciada como filha do Player. Use nós `Control` para layout (anchors, containers).  
- **Integração:** Conectar-se aos **Autoloads** e ao **Player** existentes; não recriar lógica de inventário, magia ou vida — apenas consumir sinais e APIs já existentes.

### Sistemas existentes que a HUD deve usar

1. **Vida do jogador**  
   - O Player tem um nó filho `HealthComponent` (script `Componentes/HealthComponent.gd`).  
   - Para obter: `player.get_health_component()` (pode ser null).  
   - O componente expõe: `current_health`, `max_health`, e os sinais `health_changed(old_value, new_value)`, `died()`, `damage_taken(amount)`, `healed(amount)`.  
   - Criar uma **barra de vida** (ex.: TextureProgressBar ou ColorRect + ColorRect de fundo) que atualize ao conectar em `health_changed` e que receba referência ao player (por exemplo, o nó da HUD obtém o player via `get_tree().get_first_node_in_group("player")` no `_ready()` ou por parâmetro injetado).

2. **Inventário e hotbar**  
   - **InventoryManager** (Autoload): sinais `inventory_changed`, `coins_changed(new_amount)`; funções `get_coins()`, `get_slot(slot_index)` (cada slot é null ou `{ "item": Item, "amount": int }`). Slots 0–8 são a hotbar de itens; slots 29–32 são equipamento (melee, staff, axe, pickaxe).  
   - **ToolSelectionManager** (Autoload): ferramenta ativa; sinal `tool_changed(active_slot)`; `active_tool_slot` é um enum (MELEE, STAFF, AXE, PICKAXE).  
   - A HUD deve incluir ou referenciar uma **hotbar de itens** (9 slots, teclas 1–9, ações `hotbar_1` … `hotbar_9`). Quando o cajado (STAFF) está equipado, a hotbar de itens pode ser escondida e outra barra (magias) é mostrada — já existe essa lógica no projeto; você pode criar uma versão unificada ou reutilizar a ideia.  
   - Mostrar **moedas** em um canto (Label que atualiza em `coins_changed` e `get_coins()`).

3. **Magias (cajado)**  
   - **SpellManager** (Autoload): sinais `selected_spell_slot_changed(slot)`, slots 0–8; `get_spell_at_slot(i)`, `get_selected_spell()`, `set_selected_slot(i)`. Ações de entrada `spell_1` … `spell_9`.  
   - Incluir uma **hotbar de magias** (9 slots) visível apenas quando a ferramenta ativa é STAFF (ToolSelectionManager.active_tool_slot == Weapon.ToolSlot.STAFF), com destaque no slot selecionado.

4. **Skills (buffos passivos)**  
   - O **SkillManager** (não é Autoload; fica na cena do nível) aplica skills ao player; o player tem uma lista `player.skills` (recursos do tipo Skill, com `name`, `icon`, etc.).  
   - Já existe uma classe **SkillsHUD** (`Skills/skills_hud.gd`) que mostra ícones de skills em um GridContainer; ela recebe o player e chama `update_skills(player)`.  
   - A nova HUD deve incluir uma área de **ícones de skills** (pode reutilizar a lógica do SkillsHUD ou integrar um nó que chame `update_skills` quando o player ganhar/perder skills). Se o SkillManager for acessível por grupo ou por caminho na árvore, a HUD pode obter o player e atualizar quando necessário.

5. **Interação (opcional)**  
   - Um **Label** ou painel que mostre o texto de interação (ex.: “E – Colher madeira”) quando o jogador estiver olhando para um objeto interagível. Isso é gerenciado pelo **InteractionManager** no Player; se houver um sinal ou nó global para o texto de prompt, conectar a ele; caso contrário, pode deixar um nó placeholder com texto vazio para implementação futura.

### Layout sugerido da HUD

- **Canto inferior central ou inferior esquerdo:** Hotbar de itens (9 slots) ou Hotbar de magias (9 slots), alternando conforme a ferramenta ativa.  
- **Canto superior esquerdo (ou esquerdo):** Barra de vida (HP) com valor numérico opcional (ex.: “45 / 100”).  
- **Canto superior direito:** Moedas (ícone + Label).  
- **Canto inferior direito ou acima da hotbar:** Área de ícones de skills (grid pequeno).  
- **Centro da tela (ou inferior):** Placeholder para prompt de interação (E – …).  
- Manter **z_index** e **layer** do CanvasLayer compatíveis com o resto do jogo (ex.: inventário usa z_index 50 quando aberto; a HUD fixa pode usar layer 15 como no Skills atual).

### Arquivos e cenas a gerar

1. **Cena principal da HUD** (ex.: `Scenes/UI/PlayerHUD.tscn`):  
   - Raiz: `CanvasLayer` (ou `Control` dentro de um CanvasLayer).  
   - Filhos: containers para barra de vida, hotbar, hotbar de magias, moedas, skills, prompt de interação.  
   - Script anexado à raiz: `Scripts/UI/player_hud.gd`.

2. **Script `player_hud.gd`**:  
   - Em `_ready()`: obter o player (grupo `"player"`), conectar sinais do HealthComponent, InventoryManager, SpellManager, ToolSelectionManager; atualizar estado inicial (vida, moedas, slots, visibilidade hotbar itens vs magias).  
   - Usar `@onready` para nós da cena (barra de vida, labels, containers de slots).  
   - Não duplicar lógica de inventário: usar apenas `InventoryManager.get_slot(i)`, `get_coins()`, e sinais. Para slots visuais, pode usar cenas de slot existentes (`inventory_slot.tscn`, `inventory_slot_spell.tscn`) se estiverem disponíveis, ou criar slots simples (TextureRect + Label para quantidade).  
   - Respeitar a convenção: com STAFF equipado, mostrar hotbar de magias e esconder hotbar de itens; caso contrário, mostrar hotbar de itens e esconder hotbar de magias.

3. **Integração com o Player:**  
   - No projeto, o Player já instancia cenas de UI (inventory_ui, Skills, hotbar, hotbar_spells). A nova HUD deve **substituir ou agrupar** essas partes em uma única cena `PlayerHUD.tscn` que o Level/Player instancie, de forma que:  
     - Barra de vida, moedas, skills e prompt façam parte da mesma cena.  
     - A hotbar de itens e a hotbar de magias possam ser as atuais (instanciando `hotbar.tscn` e `hotbar_spells.tscn` como filhos da PlayerHUD) ou recriadas dentro da PlayerHUD para layout unificado.  
   - Fornecer instruções curtas de como adicionar a cena ao Player (ex.: adicionar como filho do Player um nó que instancie `PlayerHUD.tscn`) e, se necessário, remover ou ocultar as instâncias antigas de hotbar/Skills para evitar duplicata.

### Estilo visual

- Cores e temas: tons terrosos, verdes escuros, marrons, para combinar com “raízes” e “mundo vivo”.  
- Barras: bordas arredondadas ou texturas simples; cor de vida (ex.: vermelho/âmbar para dano, verde para cura).  
- Slots: fundo semitransparente, ícone do item/magia, label de quantidade.  
- Manter contraste para leitura em qualquer fundo (sombra no texto ou fundo escuro atrás dos números).

### Checklist do que a HUD deve ter

- [ ] Barra de vida (current_health / max_health) ligada ao HealthComponent do player.  
- [ ] Hotbar de 9 itens (slots 0–8 do InventoryManager), teclas 1–9, destaque no slot selecionado (ToolSelectionManager.active_tool_slot para equipamento; para hotbar genérica, selected_slot 0–8).  
- [ ] Hotbar de 9 magias, visível só com cajado equipado; slot selecionado destacado.  
- [ ] Exibição de moedas (InventoryManager.get_coins(), coins_changed).  
- [ ] Área de ícones de skills (SkillsHUD ou equivalente).  
- [ ] Placeholder para prompt de interação (E – …).  
- [ ] Um único script GDScript que conecte todos os sinais e atualize os nós; cena .tscn com estrutura de nós clara e nomes em inglês ou português consistentes.

Gere os arquivos completos: cena .tscn (formato Godot 4) e script .gd, e um breve README ou comentário no topo do script explicando como instanciar a HUD no Player e quais nós devem existir na cena (ex.: PlayerHUD/HealthBar, PlayerHUD/CoinsLabel, etc.).
```

---

## Uso

1. Copie o conteúdo do bloco **Prompt** acima (do “Você vai gerar…” até “…HealthBar, PlayerHUD/CoinsLabel, etc.”).  
2. Cole na conversa do GPT (ou outro modelo).  
3. Use a resposta para criar/atualizar os arquivos no projeto (por exemplo `Scenes/UI/PlayerHUD.tscn` e `Scripts/UI/player_hud.gd`).  
4. Ajuste paths e nomes de nós se o seu projeto usar convenções ligeiramente diferentes (ex.: `Scripts` vs `Scripts/UI`).

## Referências no projeto

- **Player:** `Player/Player.gd`, `Player/player.tscn`  
- **HealthComponent:** `Componentes/HealthComponent.gd`  
- **Inventário / Hotbar:** `Scripts/UI/hotbar.gd`, `Scripts/UI/hotbar_spells.gd`, `Scripts/UI/inventory_ui.gd`, `Scripts/inventory/inventory_manager.gd`  
- **Magias:** `Scripts/SpellManager.gd`, `Scripts/UI/hotbar_spells.gd`  
- **Skills:** `Skills/skills_hud.gd`, `Skills/Skills.tscn`, `Scripts/SkillManager.gd`  
- **Estrutura do player:** `docs/PLAYER_STRUCTURE.md`  
- **Visão do jogo:** `docs/readme.md`, `docs/RELATORIO_ANALISE_PROJETO.md`
