# Experimental Players - Troubleshooting Guide

## Problema: "Os bots não fazem nada / não funcionam"

Este guia vai te ajudar a identificar e corrigir os problemas que impedem os bots de funcionarem.

---

## Passo 1: Execute o Script de Diagnóstico

1. Abra o console do servidor
2. Execute: `lua_openscript diagnostic_test.lua`
3. Leia a saída cuidadosamente

O script vai te dizer exatamente o que está faltando ou quebrado.

---

## Problemas Comuns e Soluções

### ❌ Problema 1: "This addon requires multiplayer mode!"

**Causa:** Você está rodando em singleplayer
**Solução:** O addon usa `player.CreateNextBot()` que SÓ funciona em multiplayer

**Como criar um servidor multiplayer local:**
```
1. Menu principal → Create Multiplayer
2. Escolha map
3. Max players: pelo menos 10 (para ter espaço pros bots)
4. Start
```

OU use o console:
```
map gm_construct
maxplayers 32
```

---

### ❌ Problema 2: "No weapons loaded!"

**Causa:** Os arquivos de armas não carregaram
**Soluções:**

1. Verifique se existe `lua/experimental_players/weapons/hl2_weapons.lua`
2. Verifique o console para erros de sintaxe nos arquivos de armas
3. Execute `exp_listweapons` no console - deve mostrar pelo menos 10 armas

**Se não funcionar:**
```lua
-- No console do servidor:
lua_run PrintTable(_EXPERIMENTALPLAYERSWEAPONS)
```

Se retornar vazio ou nil, os arquivos de armas não carregaram.

---

### ❌ Problema 3: "Thread status: dead"

**Causa:** A coroutine do bot morreu (erro no código)
**Soluções:**

1. **Procure erros no console** - Provavelmente tem um erro Lua
2. Erros comuns:
   - `attempt to call method 'X' (a nil value)` - Método faltando
   - `coroutine.wait() undefined` - Deve usar `CoroutineWait(self, seconds)`
   - Infinity loop sem yield - Precisa de `CoroutineWait` ou `coroutine.yield()`

**Como debugar:**
```lua
-- Adicione prints em exp_player.lua na função ThreadedThink:
function PLAYER:ThreadedThink()
    print("[DEBUG] ThreadedThink started for " .. self:Nick())
    while true do
        local state = self.exp_State or "Idle"
        print("[DEBUG] " .. self:Nick() .. " state: " .. state)  -- ADD THIS

        -- ... resto do código
    end
end
```

---

### ❌ Problema 4: "Bot spawns but doesn't move"

**Causa:** Navigator não está funcionando ou movimento está quebrado

**Diagnóstico:**
```lua
-- Console:
lua_run for k,v in pairs(EXP.ActiveBots) do PrintTable(v) end
```

Verifique se cada bot tem:
- `Navigator` (entidade válida)
- `exp_State` (deve ser "Idle" ou "Wander")
- `_Thread` (existe)

**Soluções:**

1. **Navigator faltando:**
```lua
-- Em exp_player.lua, CreateLambdaPlayer(), verifique se:
local navigator = ents_Create( "exp_navigator" )
navigator:Spawn()  -- IMPORTANTE!
```

2. **Estado preso em "Idle":**
```lua
-- Verifique se State_Idle transiciona para Wander
function PLAYER:State_Idle()
    local idleDuration = self.exp_IdleDuration or 3
    if CurTime() > self.exp_StateTime + idleDuration then
        print("[DEBUG] Transitioning from Idle to Wander")  -- ADD THIS
        self:SetState( "Wander" )
    end
    CoroutineWait( self, 1 )
end
```

3. **MoveToPos retorna "failed":**
```lua
-- Navigator não consegue calcular path
-- Certifique-se que o mapa tem navmesh
-- OU
-- O bot está em posição válida (não spawnou em parede)
```

---

### ❌ Problema 5: "Bot has no weapon / weapon is on ground"

**Causa:** Sistema de attachment quebrado

**Soluções:**

1. **Verifique se CreateWeaponEntity foi chamado:**
```lua
lua_run for k,v in pairs(EXP.ActiveBots) do if IsValid(v._PLY) then print(v._PLY:Nick(), IsValid(v._PLY.exp_WeaponEntity)) end end
```

2. **Se weapon entity não existe:**
```lua
-- Em InitializeBot (exp_player.lua), verifique se está sendo chamado:
if ply.CreateWeaponEntity then
    ply:CreateWeaponEntity()
    print("[DEBUG] Created weapon entity for " .. ply:Nick())  -- ADD THIS
end
```

3. **Se weapon entity existe mas está no chão:**
   - Provavelmente o attachment point falhou
   - Verifique `sh_globals.lua` função `GetAttachmentPoint()`
   - Verifique se `weaponhandling.lua` está usando attachment corretamente

---

### ❌ Problema 6: "Bot spawns, stands still, does nothing"

**Diagnóstico completo:**

```lua
-- Console:
exp_debug_combat

-- OU manualmente:
lua_run for _,bot in pairs(EXP.ActiveBots) do local p = bot._PLY; print(p:Nick(), "State:", p.exp_State, "Thread:", coroutine.status(p._Thread), "Health:", p:Health(), "Weapon:", p.exp_CurrentWeapon) end
```

**Possíveis causas:**

| Sintoma | Causa | Solução |
|---------|-------|---------|
| State é sempre "Idle" | State_Idle não transiciona | Verifique timer/CurTime |
| Thread status = "dead" | Erro na ThreadedThink | Veja console pra erros |
| Thread status = "normal" | Thread não está sendo resumida | Verifique hook "Think" |
| exp_CurrentWeapon = nil | SwitchWeapon falhou | Verifique weapon table |
| Navigator inválido | Entity não spawnou | Veja exp_navigator.lua |

---

## Passo 2: Teste Manualmente

Depois de spawnar um bot, teste cada sistema individualmente:

### Teste 1: Thread está rodando?
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; print("Thread status:", coroutine.status(bot._Thread))
```
**Esperado:** "suspended"
**Se "dead":** Tem um erro quebrando a thread!

### Teste 2: Bot consegue trocar de estado?
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; bot:SetState("Wander"); print("Set to Wander")
```
Aguarde 2 segundos. O bot deveria começar a andar.

### Teste 3: Bot consegue se mover?
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; local target = bot:GetPos() + Vector(300, 0, 0); bot:MoveToPos(target)
```
**O bot deveria caminhar para frente.**

Se não funcionar:
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; print("Navigator valid:", IsValid(bot.Navigator))
```

### Teste 4: Bot consegue trocar de arma?
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; bot:SwitchWeapon("pistol", true)
```
**A arma deveria aparecer na mão direita do bot.**

Se aparecer no chão, o attachment está quebrado.

### Teste 5: Bot consegue atirar?
```lua
lua_run local bot = EXP.ActiveBots[1]._PLY; local target = Entity(1); bot.exp_Enemy = target; bot:SetState("Combat")
```
**O bot deveria atirar em você.**

---

## Checklist de Problemas Críticos

Execute todos esses testes:

- [ ] Rodando em **multiplayer** (não singleplayer)
- [ ] `_EXPERIMENTALPLAYERSWEAPONS` tem pelo menos 10 armas
- [ ] `EXP.Player.ThreadedThink` existe
- [ ] `EXP.Player.MoveToPos` existe
- [ ] `EXP.Player.SwitchWeapon` existe
- [ ] Hook "Think" está registrado e chamando `bot:Think()`
- [ ] Hook "SetupMove" está registrado
- [ ] Thread do bot está "suspended" (não "dead")
- [ ] Bot tem `Navigator` válido
- [ ] Bot tem `exp_WeaponEntity` válido
- [ ] Bot consegue transicionar de "Idle" → "Wander"
- [ ] Console não mostra erros Lua

---

## Erros Conhecidos e Fixes

### Erro: "attempt to call method 'StartWith' (a nil value)"
**Local:** `cover.lua`
**Fix:**
```lua
-- ERRADO:
if class:StartWith("prop_") then

-- CORRETO:
if string.StartWith(class, "prop_") then
```

### Erro: "coroutine.wait is not defined"
**Local:** Qualquer arquivo usando coroutines
**Fix:** Use `CoroutineWait(self, seconds)` ao invés de `coroutine.wait(seconds)`

### Erro: "SetEnemy is not a function"
**Local:** `objective.lua`, `combat.lua`
**Fix:**
```lua
-- ERRADO:
self:SetEnemy(enemy)

-- CORRETO:
self.exp_Enemy = enemy
```

### Erro: "Weapon entity falls through floor"
**Local:** `weaponhandling.lua`
**Fix:** Certifique-se que `CreateWeaponEntity` usa attachment points:
```lua
local attachPoint = EXP:GetAttachmentPoint( self, "hand" )
if attachPoint and attachPoint.Index then
    wepEnt:SetParent( self, attachPoint.Index )
end
```

---

## Debug Mode

Ative prints de debug adicionando no topo do `exp_player.lua`:

```lua
local DEBUG_MODE = true

function PLAYER:DebugPrint(...)
    if DEBUG_MODE then
        print("[EXP DEBUG " .. self:Nick() .. "]", ...)
    end
end
```

Então adicione em lugares críticos:
```lua
function PLAYER:SetState(newState)
    self:DebugPrint("State change:", self.exp_State, "→", newState)
    -- resto do código...
end

function PLAYER:MoveToPos(pos, options)
    self:DebugPrint("MoveToPos called, target:", pos)
    -- resto do código...
end
```

---

## Ainda Não Funciona?

Se após todos esses testes os bots ainda não funcionam:

1. **Copie TODO o output do console** (incluindo erros)
2. **Execute `diagnostic_test.lua` e copie a saída**
3. **Execute esses comandos:**
```lua
lua_run PrintTable(EXP)
lua_run for k,v in pairs(EXP.ActiveBots) do PrintTable(v) end
lua_run if EXP.ActiveBots[1] then local p = EXP.ActiveBots[1]._PLY; print("Name:", p:Nick(), "State:", p.exp_State, "Thread:", coroutine.status(p._Thread), "Weapon:", p.exp_CurrentWeapon, "Navigator:", IsValid(p.Navigator)) end
```

4. **Verifique arquivos críticos existem:**
```
lua/experimental_players/exp_player.lua
lua/experimental_players/players/movement.lua
lua/experimental_players/players/combat.lua
lua/experimental_players/players/weaponhandling.lua
lua/experimental_players/weapons/hl2_weapons.lua
lua/experimental_players/includes/sh_globals.lua
lua/entities/exp_navigator.lua
```

---

## Último Recurso: Fresh Install Test

Se nada funcionar, teste se o problema é no addon ou no seu servidor:

1. Crie uma pasta nova `garrysmod/addons/experimental-players-test/`
2. Copie APENAS estes arquivos essenciais:
   - `addon.json`
   - `lua/autorun/experimental_players_autorun.lua`
   - `lua/experimental_players/` (pasta inteira)
   - `lua/entities/` (pasta inteira)
3. Remova/rename o addon original
4. Restart servidor
5. Tente spawnar bot

Se funcionar: problema estava em arquivo corrompido/modificado
Se não funcionar: problema é no ambiente (GMod versão, sistema operacional, etc.)

---

**Boa sorte! Se encontrar o problema, documente aqui para ajudar outros.**
