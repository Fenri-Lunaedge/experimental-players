# GLua Reference - Quick Guide for Experimental Players

**Source:** [Garry's Mod Wiki](https://wiki.facepunch.com/gmod)
**GLua Version:** Based on Lua 5.1 with GMod-specific extensions

---

## 1. GLua vs Standard Lua

GLua extends standard Lua 5.1 with:
- ✅ Entity and networked variable systems
- ✅ Hook library for event handling
- ✅ Realm-specific execution (client/server/shared)
- ✅ Built-in rendering and physics manipulation
- ✅ Console command integration
- ✅ Prediction system for multiplayer

---

## 2. Core Systems for PlayerBot Development

### 2.1 Hook System

**Documentation:** https://wiki.facepunch.com/gmod/hook

**Key Functions:**
```lua
-- Register a hook
hook.Add("EventName", "UniqueIdentifier", function(params...)
    -- Your code here
    -- Return value can stop further hooks
end)

-- Remove a hook
hook.Remove("EventName", "UniqueIdentifier")

-- Call a hook manually (rare)
hook.Run("EventName", params...)
```

**How Hooks Work:**
- Hooks are called sequentially until one returns non-nil
- Return values can prevent further processing
- Gamemode functions are fallback if no hooks return data

**Important for Bots:**
- Use hooks to intercept game events
- Multiple addons can register same hook without conflict
- Use unique identifiers (e.g., "EXP_PlayerThink")

---

### 2.2 Player.CreateNextBot()

**Documentation:** https://wiki.facepunch.com/gmod/player.CreateNextBot

```lua
Player player.CreateNextBot(string botName)
```

**Key Facts:**
- ✅ Creates Player entities (not NPCs)
- ✅ Uses TF2/CS:S bot base
- ✅ Consumes player slots (requires multiplayer)
- ✅ Returns NULL if no slots available
- ⚠️ Must remove with `Player:Kick()`, NOT `Entity:Remove()`
- ⚠️ Bots are "UnAuthed" (no Steam authentication)

**Example:**
```lua
function CreateBot()
    if not game.SinglePlayer() and player.GetCount() < game.MaxPlayers() then
        local bot = player.CreateNextBot("Bot_" .. math.random(1, 999))
        return bot
    end
    return nil
end
```

---

### 2.3 GM:SetupMove Hook

**Documentation:** https://wiki.facepunch.com/gmod/GM:SetupMove

```lua
GM:SetupMove(Player ply, CMoveData mv, CUserCmd cmd)
```

**When Called:**
- Before engine processes movements
- Predicted hook (server + client in multiplayer)
- ⚠️ NOT called client-side in singleplayer

**Parameters:**
- `Player ply` - Player being moved
- `CMoveData mv` - Movement data (can modify)
- `CUserCmd cmd` - User command (can modify)

**Use Cases:**
- Override movement speed/direction
- Control crouch/sprint/jump states
- Implement custom movement mechanics
- **CRITICAL FOR PLAYERBOTS:** Control bot movement

**Example (Disable Jumping):**
```lua
hook.Add("SetupMove", "DisableJump", function(ply, mv, cmd)
    if mv:KeyDown(IN_JUMP) then
        local buttons = mv:GetButtons()
        buttons = bit.band(buttons, bit.bnot(IN_JUMP))
        mv:SetButtons(buttons)
    end
end)
```

**Example (Control Speed):**
```lua
hook.Add("SetupMove", "CustomSpeed", function(ply, mv, cmd)
    if ply:WaterLevel() >= 2 then
        mv:SetUpSpeed(-100)  -- Sink in water
    end
end)
```

**CMoveData Important Methods:**
- `mv:GetButtons()` / `mv:SetButtons(buttons)`
- `mv:GetForwardSpeed()` / `mv:SetForwardSpeed(speed)`
- `mv:GetSideSpeed()` / `mv:SetSideSpeed(speed)`
- `mv:GetMoveAngles()` / `mv:SetMoveAngles(angle)`
- `mv:KeyDown(key)` - Check if key is pressed

---

### 2.4 GM:StartCommand Hook

**Documentation:** https://wiki.facepunch.com/gmod/GM:StartCommand

```lua
GM:StartCommand(Player ply, CUserCmd cmd)
```

**When Called:**
- When CUserCmd is generated on client
- When CUserCmd is received on server
- **Predicted** - works in both realms

**Parameters:**
- `Player ply` - Player entity
- `CUserCmd cmd` - User command to modify

**Key Difference from CreateMove:**
- CreateMove = Client-only
- StartCommand = Shared (client + server)

**Use Cases for Bots:**
- Control button inputs (attack, reload, jump)
- Set view angles (aiming)
- Weapon selection
- **CRITICAL FOR PLAYERBOTS:** Button control

**Example (Bot Aim):**
```lua
hook.Add("StartCommand", "BotControl", function(ply, cmd)
    if !ply:IsBot() then return end

    -- Find target
    local target = FindNearestEnemy(ply)
    if IsValid(target) then
        -- Calculate aim direction
        local aimDir = (target:GetPos() - ply:GetShootPos()):GetNormalized()
        cmd:SetViewAngles(aimDir:Angle())

        -- Fire weapon
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_ATTACK))
    end
end)
```

**CUserCmd Important Methods:**
- `cmd:GetButtons()` / `cmd:SetButtons(buttons)`
- `cmd:GetViewAngles()` / `cmd:SetViewAngles(angle)`
- `cmd:ClearMovement()` - Reset all movement
- `cmd:ClearButtons()` - Reset all buttons

---

## 3. Important Hooks for Bot AI

### Lifecycle Hooks

**GM:PlayerSpawn(Player ply)**
- Called when player spawns
- Setup initial bot state here

**GM:PlayerDeath(Player victim, Entity inflictor, Player attacker)**
- Called when player dies
- Cleanup bot data here

**GM:EntityTakeDamage(Entity target, CTakeDamageInfo dmg)**
- Called when entity takes damage
- Use for bot damage response

### Movement Hooks

**GM:SetupMove(Player ply, CMoveData mv, CUserCmd cmd)**
- **PRIMARY MOVEMENT CONTROL**
- Modify movement before engine processes

**GM:StartCommand(Player ply, CUserCmd cmd)**
- **PRIMARY BUTTON CONTROL**
- Modify inputs before processing

**GM:Move(Player ply, CMoveData mv)**
- Called after SetupMove
- Final chance to modify movement

### Think Hooks

**GM:Think()**
- Called every tick
- Use for bot AI updates
- ⚠️ Don't do heavy processing here (use timers)

**GM:Tick()**
- Called every game tick
- More reliable than Think for timing

### Weapon Hooks

**GM:PlayerSwitchWeapon(Player ply, Weapon oldWep, Weapon newWep)**
- Called when player switches weapons

**WEAPON:PrimaryAttack()**
- Called when weapon fires
- Override for custom weapon behavior

---

## 4. Entity System

### Player Entity (Player)

**Important Methods:**
```lua
-- Movement
ply:SetPos(Vector pos)
ply:SetVelocity(Vector vel)
ply:SetEyeAngles(Angle ang)
ply:GetVelocity()

-- Health
ply:Health()
ply:SetHealth(number hp)
ply:GetMaxHealth()
ply:Alive()
ply:Kill()

-- Weapons
ply:GetActiveWeapon()
ply:Give(string weaponClass)
ply:StripWeapon(string weaponClass)
ply:SelectWeapon(string weaponClass)

-- Information
ply:Nick() -- Name
ply:IsBot()
ply:IsPlayer()
ply:Team()
ply:GetShootPos()
ply:GetAimVector()
ply:EyePos()
ply:EyeAngles()

-- Special
ply:Kick(string reason) -- For removing bots
```

### CMoveData (Movement Data)

```lua
-- Buttons
mv:GetButtons() -- Returns button bitfield
mv:SetButtons(number buttons)
mv:KeyDown(number key) -- Check if IN_* key is down

-- Speed
mv:GetForwardSpeed()
mv:SetForwardSpeed(number speed)
mv:GetSideSpeed()
mv:SetSideSpeed(number speed)
mv:GetUpSpeed()
mv:SetUpSpeed(number speed)

-- Angles
mv:GetMoveAngles()
mv:SetMoveAngles(Angle ang)

-- Position
mv:GetOrigin()
mv:SetOrigin(Vector pos)

-- Velocity
mv:GetVelocity()
mv:SetVelocity(Vector vel)
```

### CUserCmd (User Command)

```lua
-- Buttons
cmd:GetButtons()
cmd:SetButtons(number buttons)
cmd:ClearButtons()

-- View Angles
cmd:GetViewAngles()
cmd:SetViewAngles(Angle ang)

-- Movement
cmd:GetForwardMove()
cmd:SetForwardMove(number forward)
cmd:GetSideMove()
cmd:SetSideMove(number side)
cmd:GetUpMove()
cmd:SetUpMove(number up)
cmd:ClearMovement()
```

---

## 5. Input Constants (IN_*)

**Important for Button Control:**
```lua
IN_ATTACK       -- Primary fire (Mouse1)
IN_ATTACK2      -- Secondary fire (Mouse2)
IN_JUMP         -- Jump (Space)
IN_DUCK         -- Crouch (Ctrl)
IN_FORWARD      -- Move forward (W)
IN_BACK         -- Move backward (S)
IN_MOVELEFT     -- Move left (A)
IN_MOVERIGHT    -- Move right (D)
IN_SPEED        -- Sprint (Shift)
IN_WALK         -- Walk (Alt)
IN_USE          -- Use (E)
IN_RELOAD       -- Reload (R)
IN_WEAPON1      -- Weapon slot 1
IN_WEAPON2      -- Weapon slot 2
-- ... etc
```

**Bitwise Operations:**
```lua
-- Set button
buttons = bit.bor(buttons, IN_ATTACK)

-- Unset button
buttons = bit.band(buttons, bit.bnot(IN_ATTACK))

-- Check button
if bit.band(buttons, IN_JUMP) != 0 then
    -- Jump is pressed
end
```

---

## 6. Realm System

### File Prefixes

| Prefix | Realm | Description |
|--------|-------|-------------|
| `cl_` | Client | Client-side only |
| `sv_` | Server | Server-side only |
| `sh_` | Shared | Both client and server |

### Realm Checks

```lua
if SERVER then
    -- Server-only code
end

if CLIENT then
    -- Client-only code
end

if game.SinglePlayer() then
    -- Singleplayer check
    -- ⚠️ PlayerBots don't work here!
end
```

### File Loading

```lua
-- Server sending file to clients
if SERVER then
    AddCSLuaFile("path/to/file.lua")
end

-- Including file
include("path/to/file.lua")
```

---

## 7. Networking

### Network Strings

```lua
-- Server: Register network message
if SERVER then
    util.AddNetworkString("MyMessage")
end

-- Server: Send to clients
net.Start("MyMessage")
net.WriteString("Hello")
net.Send(player) -- or net.Broadcast()

-- Client: Receive
net.Receive("MyMessage", function(len, ply)
    local msg = net.ReadString()
    print(msg)
end)
```

### Networked Variables (NW2)

```lua
-- Set (server)
ent:SetNW2String("name", "Bot")
ent:SetNW2Int("kills", 10)
ent:SetNW2Bool("admin", true)

-- Get (client or server)
local name = ent:GetNW2String("name")
local kills = ent:GetNW2Int("kills")
local isAdmin = ent:GetNW2Bool("admin")
```

---

## 8. Common Patterns for Bot Development

### Pattern 1: Bot Think Loop
```lua
hook.Add("Think", "EXP_BotThink", function()
    for _, ply in ipairs(player.GetBots()) do
        if IsValid(ply) and ply:Alive() then
            -- Bot AI logic here
            BotUpdateAI(ply)
        end
    end
end)
```

### Pattern 2: Bot Movement Control
```lua
hook.Add("SetupMove", "EXP_BotMove", function(ply, mv, cmd)
    if !ply:IsBot() then return end

    -- Get target position
    local targetPos = ply.BotTargetPos
    if !targetPos then return end

    -- Calculate direction
    local dir = (targetPos - ply:GetPos()):GetNormalized()

    -- Set movement angles
    mv:SetMoveAngles(dir:Angle())

    -- Set speed
    mv:SetForwardSpeed(ply:GetRunSpeed())
end)
```

### Pattern 3: Bot Button Control
```lua
hook.Add("StartCommand", "EXP_BotButtons", function(ply, cmd)
    if !ply:IsBot() then return end

    -- Clear default inputs
    cmd:ClearButtons()
    cmd:ClearMovement()

    local buttons = 0

    -- Attack if has target
    if IsValid(ply.BotTarget) then
        buttons = bit.bor(buttons, IN_ATTACK)
    end

    -- Jump if needed
    if ply.BotShouldJump then
        buttons = bit.bor(buttons, IN_JUMP)
    end

    cmd:SetButtons(buttons)
end)
```

### Pattern 4: Coroutine-Based AI
```lua
function BotAIThread(ply)
    while IsValid(ply) do
        -- Find target
        local target = FindTarget(ply)

        if IsValid(target) then
            -- Move to target
            MoveToPosition(ply, target:GetPos())

            -- Wait
            coroutine.wait(0.5)

            -- Attack
            AttackTarget(ply, target)
        end

        -- Wait before next iteration
        coroutine.wait(0.1)
    end
end

-- Start thread
ply.BotThread = coroutine.create(function()
    BotAIThread(ply)
end)

-- Resume in Think
hook.Add("Think", "ResumeBotThreads", function()
    for _, ply in ipairs(player.GetBots()) do
        if ply.BotThread then
            coroutine.resume(ply.BotThread)
        end
    end
end)
```

---

## 9. Experimental Players Implementation Notes

### Our Architecture Matches GLua Best Practices:

✅ **Realm Separation**
- Server-only AI logic (sv_*)
- Shared weapon definitions (sh_*)
- Proper AddCSLuaFile usage

✅ **Hook System**
- Clean hook identifiers ("EXP_*")
- Multiple hooks for different systems
- Proper hook removal on cleanup

✅ **SetupMove for Movement**
- Primary movement control in SetupMove
- CMoveData manipulation for positioning
- Button state management

✅ **StartCommand for Buttons**
- Attack/reload/weapon switch control
- View angle control (aiming)
- Input management

✅ **PlayerBot Creation**
- Using player.CreateNextBot()
- Proper removal with Kick()
- Multiplayer-only enforcement

✅ **Coroutine-Based AI**
- Threaded decision making
- Non-blocking wait times
- State machine implementation

---

## 10. Important GLua Gotchas

### ⚠️ PlayerBots Don't Work in Singleplayer
```lua
if game.SinglePlayer() then
    print("ERROR: PlayerBots require multiplayer!")
    return
end
```

### ⚠️ Use Kick() Not Remove()
```lua
-- WRONG
ply:Remove() -- Will cause issues

-- CORRECT
ply:Kick("Bot removed")
```

### ⚠️ SetupMove Not Called Client-Side in SP
```lua
-- SetupMove is predicted
-- In singleplayer, only runs server-side
-- In multiplayer, runs both realms
```

### ⚠️ Hook Return Values Matter
```lua
hook.Add("EntityTakeDamage", "CustomDamage", function(target, dmg)
    if target:IsBot() then
        -- Returning true prevents damage
        return true
    end
    -- Returning nothing allows normal processing
end)
```

### ⚠️ Bitwise Operations Required for Buttons
```lua
-- Don't use regular arithmetic
buttons = buttons + IN_ATTACK -- WRONG

-- Use bitwise OR
buttons = bit.bor(buttons, IN_ATTACK) -- CORRECT
```

---

## 11. Useful Wiki Links

### Core Documentation
- **Main Page:** https://wiki.facepunch.com/gmod
- **Hook Library:** https://wiki.facepunch.com/gmod/hook
- **Player Class:** https://wiki.facepunch.com/gmod/Player
- **Entity Class:** https://wiki.facepunch.com/gmod/Entity

### Bot Development
- **player.CreateNextBot:** https://wiki.facepunch.com/gmod/player.CreateNextBot
- **GM:SetupMove:** https://wiki.facepunch.com/gmod/GM:SetupMove
- **GM:StartCommand:** https://wiki.facepunch.com/gmod/GM:StartCommand
- **CMoveData:** https://wiki.facepunch.com/gmod/CMoveData
- **CUserCmd:** https://wiki.facepunch.com/gmod/CUserCmd

### References
- **Global Functions:** 334 functions documented
- **Classes:** 46 classes with methods
- **Hooks:** Complete hook reference
- **Enums:** All constants (IN_*, MASK_*, etc.)

---

## 12. Community Resources

- **Discord:** Official GMod Discord (#wiki channel)
- **GitHub:** https://github.com/Facepunch/garrysmod
- **Forums:** Facepunch Forums
- **Steam Workshop:** Thousands of addons for reference

---

**Last Updated:** 2025-11-16
**For:** Experimental Players Development
**GLua Version:** Lua 5.1 + GMod Extensions
