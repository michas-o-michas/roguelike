# Plano: Unificar inventário (Passo 1)

> **Status:** Migração concluída. O GameManager já não possui inventário; a fonte de verdade é o InventoryManager. Este doc permanece como referência do que foi feito.

## Objetivo
Ter **um único sistema de inventário**: o **InventoryManager** (slots + Item resource). Remover o inventário por string id do **GameManager** e migrar todos os consumidores para o InventoryManager, usando um registro **id → Item** já existente no CraftingManager.

---

## Situação atual

| Sistema | Onde | Formato | Usado por |
|--------|------|---------|-----------|
| **GameManager** | `Scripts/GameManager.gd` | `inventory: Dictionary` (id string → quantidade) | ResourceNode, CraftSystem, UIManager |
| **InventoryManager** | `Scripts/inventory/inventory_manager.gd` | `slots: Array` (slot → `{ "item": Item, "amount": int }`) | inventory_ui, hotbar, crafting_ui, recipe_card, inventory_slot, **CraftingManager** |

- **GameManager**: `add_item(id, amount)`, `remove_item(id, amount)`, `get_amount(id)`, sinal `inventory_changed`.
- **InventoryManager**: `add_item(item: Item, amount)`, `remove_item(item, amount)`, `has_item(item, amount)`, `get_item_count(item)`, `get_slot(index)`, moedas, sinal `inventory_changed`.
- **CraftingManager** já tem `item_registry: Dictionary` (id string → Item), preenchido por `_register_items_from_folder("res://items/")` (id = nome do arquivo sem `.tres`: `wood`, `stone`, `wood_sword`).

---

## Estratégia

1. Usar o **CraftingManager.item_registry** como única fonte **id → Item**.
2. No **InventoryManager**, adicionar API por **id string**: `add_item_by_id`, `remove_item_by_id`, `has_item_by_id`, `get_item_count_by_id`, e (para a UI legada) `get_all_item_counts()`.
3. Migrar **ResourceNode**, **CraftSystem** e **UIManager** para usar só InventoryManager.
4. Remover do **GameManager** o dict `inventory`, os métodos de item e o sinal `inventory_changed` (manter só loading/mundo se for usado).

---

## Tarefas (ordem de execução)

### Fase 1: API por id no CraftingManager e no InventoryManager

#### 1.1 CraftingManager – expor Item por id e id por Item
- **Arquivo:** `Scripts/inventory/crafting_manager_json.gd`
- **Adicionar:**
  - `get_item_by_id(id: String) -> Item`  
    Retornar `item_registry.get(id, null)`.
  - `get_id_for_item(item: Item) -> String`  
    Percorrer `item_registry`; se `value == item` ou `value.resource_path == item.resource_path`, retornar a chave; senão `""`.

#### 1.2 InventoryManager – API por id e resumo para UI
- **Arquivo:** `Scripts/inventory/inventory_manager.gd`
- **Adicionar:**
  - `add_item_by_id(id: String, amount: int) -> bool`  
    Obter `item = CraftingManager.get_item_by_id(id)`; se `item == null`, retornar `false`; senão `return add_item(item, amount)`.
  - `remove_item_by_id(id: String, amount: int) -> bool`  
    Mesmo com `remove_item(item, amount)`.
  - `has_item_by_id(id: String, amount: int) -> bool`  
    Mesmo com `has_item(item, amount)`.
  - `get_item_count_by_id(id: String) -> int`  
    Mesmo com `get_item_count(item)`; se item null, retornar 0.
  - `get_all_item_counts() -> Dictionary`  
    Retornar `Dictionary` (id string → quantidade total).  
    Percorrer `slots`; para cada slot com item, obter `id = CraftingManager.get_id_for_item(slot["item"])` (ou `resource_path` se id vazio); somar `amount` por id.

**Dependência:** Autoload CraftingManager deve estar disponível quando InventoryManager for usado por id (já está no project.godot). Se `CraftingManager` for null (ex.: em testes), as funções por id devem falhar graciosamente (retornar false/0).

---

### Fase 2: Migrar consumidores do GameManager

#### 2.1 ResourceNode
- **Arquivo:** `Scripts/ResourceNode.gd`
- **Trocar:**  
  `GameManager.add_item(resource_id, drop_amount)`  
  **por**  
  `InventoryManager.add_item_by_id(resource_id, drop_amount)`
- **Nota:** `resource_id` já é string (ex.: `"wood"`). Os nós de recurso em cena devem usar ids que existam em `res://items/` (ex.: `wood.tres`, `stone.tres`).

#### 2.2 CraftSystem
- **Arquivo:** `Scripts/CraftSystem.gd`
- **Trocar:**
  - `GameManager.remove_item("wood", 5)` → `InventoryManager.remove_item_by_id("wood", 5)`
  - `GameManager.add_item("axe", 1)` → `InventoryManager.add_item_by_id("axe", 1)`
  - Idem para stone/pickaxe.
- **Nota:** Se não existirem `axe.tres` e `pickaxe.tres` em `res://items/`, criar ou usar ids que existam no registro (ex.: `wood_sword` para teste). Caso contrário, `add_item_by_id` retornará false e nada será adicionado.

#### 2.3 UIManager (label de inventário legado)
- **Arquivo:** `Scripts/UIManager.gd`
- **Trocar:**
  - Conectar a `InventoryManager.inventory_changed` em vez de `GameManager.inventory_changed`.
  - Em `update_ui()`: usar `var counts = InventoryManager.get_all_item_counts()` e montar o texto iterando `counts` (ex.: para cada `id` e `count`, linha `id + ": " + str(count)`).
- **Resultado:** A label continua mostrando “id: quantidade”, agora com dados do InventoryManager.

---

### Fase 3: Limpar o GameManager

#### 3.1 GameManager
- **Arquivo:** `Scripts/GameManager.gd`
- **Remover:**
  - Variável `inventory := {}`
  - Sinal `inventory_changed`
  - Funções `add_item(id, amount)`, `remove_item(id, amount)`, `get_amount(id)`
- **Manter:**  
  Tudo relacionado a loading (loading_screen, world_generator, sinais de progresso/complete, etc.).

---

### Fase 4: Verificação e edge cases

1. **Ordem de autoload:**  
   Garantir que CraftingManager está registrado antes de qualquer cena que chame `add_item_by_id` no primeiro frame (project.godot já define a ordem).

2. **Itens sem id no registro:**  
   Recursos que não estão em `res://items/` (ou cujo id não está no `item_registry`) não serão adicionados por id; `add_item_by_id` retorna false. ResourceNode e CraftSystem devem usar apenas ids registrados (ex.: `wood`, `stone`; criar `axe`/`pickaxe` em `items/` se forem usados).

3. **Moedas:**  
   Continuam só no InventoryManager (`add_coins`, `spend_coins`, `get_coins`). Nenhuma mudança necessária.

4. **CraftingManager e receitas:**  
   Já usam InventoryManager com Item; não é preciso alterar receitas nem JSON, só garantir que os ids usados no JSON existam no registro (nome do .tres em `items/`).

---

## Resumo dos arquivos alterados

| Arquivo | Ação |
|---------|------|
| `Scripts/inventory/crafting_manager_json.gd` | Adicionar `get_item_by_id(id)`, `get_id_for_item(item)` |
| `Scripts/inventory/inventory_manager.gd` | Adicionar `add_item_by_id`, `remove_item_by_id`, `has_item_by_id`, `get_item_count_by_id`, `get_all_item_counts()` |
| `Scripts/ResourceNode.gd` | Trocar `GameManager.add_item` por `InventoryManager.add_item_by_id` |
| `Scripts/CraftSystem.gd` | Trocar `GameManager.remove_item`/`add_item` por `InventoryManager.remove_item_by_id`/`add_item_by_id` |
| `Scripts/UIManager.gd` | Conectar a `InventoryManager.inventory_changed` e usar `get_all_item_counts()` |
| `Scripts/GameManager.gd` | Remover `inventory`, `inventory_changed`, `add_item`, `remove_item`, `get_amount` |

---

## Após a unificação

- **Única fonte de verdade:** InventoryManager (slots + moedas).
- **Único registro id → Item:** CraftingManager.item_registry (preenchido por `res://items/`).
- Novos recursos no mundo: usar `InventoryManager.add_item_by_id(id, amount)` com id existente em `items/`.
- Novas receitas: usar os mesmos ids no JSON e itens em `items/`; CraftingManager e InventoryManager seguem compatíveis.
