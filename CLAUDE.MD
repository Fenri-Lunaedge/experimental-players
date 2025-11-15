# Experimental Players - Technical Documentation

**Advanced PlayerBot AI for Garry's Mod - Multiplayer Edition**

Created by: Fenri-Lunaedge
Developed with: Claude Code (Anthropic)
License: MIT
Version: 1.0 (In Development)

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Core Systems](#core-systems)
3. [Weapon System](#weapon-system)
4. [Navigation & Movement](#navigation--movement)
5. [AI & States](#ai--states)
6. [File Structure](#file-structure)
7. [Development Guide](#development-guide)
8. [API Reference](#api-reference)

---

## Architecture Overview

### Foundation: GLambda Players

Experimental Players is built on the revolutionary **GLambda Players architecture**, which uses real PlayerBots instead of traditional NextBots.

**Key Difference:**
- **Traditional Bots (Lambda/Zeta):** NPCs that simulate players
- **Experimental Players:** Real `player.CreateNextBot()` entities with actual player physics

### Why PlayerBots?

✅ **Real player physics** - Same weight, acceleration, collision as human players
✅ **Network support** - Built-in multiplayer networking
✅ **Player animations** - Authentic player animation system
✅ **Scoreboard integration** - Bots appear as real players
⚠️ **Multiplayer only** - Requires dedicated server (no singleplayer)

### GLACE Wrapper System

The **GLACE** (GLambda Abstraction Component Entity) wrapper provides a unified interface:

```lua
-- Real player entity
local ply = player.CreateNextBot(name)

-- GLACE wrapper
local GLACE = { _PLY = ply }
setmetatable(GLACE, {
    __index = function(tbl, key)
        if PLAYER[key] then
            return function(self, ...)
                return PLAYER[key](ply, ...)
            end
        end
        return ply[key]
    end
})
```

This allows calling player methods transparently while maintaining the bot's logic layer.

---

## Core Systems

### 1. Initialization System (`experimental_players_autorun.lua`)

**Loading Order:**
1. Check for multiplayer (fail in singleplayer)
2. Load core includes (sh_*)
3. Load player behavior modules (players/*)
4. Load social features (social/*)
5. Load game modes (gamemodes/*)
6. Load compatibility layer (compatibility/*)
7. Load main player class (`exp_player.lua`)
8. Update data files

**Module Loading Pattern:**
```lua
-- Automatically includes based on prefix
for _, luaFile in ipairs(file_Find(dirPath .. "*.lua", "LUA", "nameasc")) do
    if string_StartWith(luaFile, "sv_") then
        include(dirPath .. luaFile)  -- Server only
    elseif string_StartWith(luaFile, "cl_") then
        AddCSLuaFile(dirPath .. luaFile)  -- Client
        if CLIENT then include(dirPath .. luaFile) end
    elseif string_StartWith(luaFile, "sh_") then
        AddCSLuaFile(dirPath .. luaFile)  -- Shared
        include(dirPath .. luaFile)
    end
end
```

### 2. File System (`sh_filesystem.lua`)

**Purpose:** Manage persistent data (JSON files in `data/experimental_players/`)

**Key Functions:**
- `FILE:WriteFile(filename, content, type)` - Write JSON/compressed data
- `FILE:ReadFile(filename, type, path)` - Read data files
- `FILE:UpdateKeyValueFile()` - Merge data into existing files
- `FILE:MergeDirectory()` - Recursively load files from directories

**Data Files:**
- `npclist.json` - Spawnable NPCs
- `entitylist.json` - Spawnable entities
- `proplist.json` - Spawnable props
- `weaponpermissions.json` - Allowed weapons
- `profiles.json` - Bot profiles

### 3. Global Functions (`sh_globals.lua`)

**Player Models:**
```lua
EXP:GetRandomPlayerModel()  -- Returns random model
EXP:UpdatePlayerModels()    -- Scans for addon models
```

**Random Number Generation:**
```lua
EXP:Random(min, max, float)  -- Seeded RNG
EXP:Random(table)            -- Random table element
```

**Hook System:**
```lua
EXP:RunHook("EXP_OnPlayerInitialize", ply)
```

**Available Hooks:**
- `OnPlayerSelectWeapon`
- `OnPlayerKilled`
- `OnPlayerHurt`
- `OnPlayerThink`
- `OnPlayerChangeState`
- `OnPlayerCanTarget`
- `OnPlayerInitialize`
- `OnPlayerRespawn`

### 4. ConVars (`sh_convars.lua`)

**Creating ConVars:**
```lua
EXP:CreateConVar(name, default, description, {
    name = "Display Name",
    category = "Category",
    min = 0,
    max = 100
})
```

**Key ConVars:**
- `exp_combat_range` - Combat engagement distance
- `exp_combat_accuracy` - Aiming accuracy (0-100)
- `exp_nav_updaterate` - Navigation update frequency
- `exp_social_textchat` - Enable text chat
- `exp_building_enabled` - Allow building

---

## Weapon System

### Architecture

**Global Weapon Table:**
```lua
_EXPERIMENTALPLAYERSWEAPONS = {
    ["weaponname"] = {
        model = "models/weapons/w_pistol.mdl",
        prettyname = "Pistol",
        origin = "Half-Life 2",
        holdtype = "pistol",
        ismelee = false,
        islethal = true,

        -- Combat
        damage = 5,
        attackrange = 2000,
        keepdistance = 350,
        rateoffire = 0.2,

        -- Ranged specific
        clip = 18,
        spread = 0.133,
        tracername = "Tracer",
        bulletcount = 1,
        muzzleflash = 1,
        shelleject = "ShellEject",

        -- Reload
        reloadtime = 1.8,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_PISTOL,
        reloadsounds = { {0, "Weapon_Pistol.Reload"} },

        -- Callbacks
        OnAttack = function(ply, wepent, target) end,
        OnDeploy = function(ply, wepent, oldwep) end,
        OnHolster = function(ply, wepent, oldwep, newwep) end,
    }
}
```

### Weapon Handling Functions

**Switching Weapons:**
```lua
bot:SwitchWeapon(weaponname, forceSwitch)
-- Calls: OnHolster → Update properties → OnDeploy → Sounds
```

**Attacking:**
```lua
bot:Attack(target)
-- Melee: Trace → Damage → Hit sound
-- Ranged: FireBullets → Effects → Consume ammo → Auto reload
```

**Reloading:**
```lua
bot:Reload()
-- Play animation → Play sounds → Timer → Refill clip
```

### Lambda Compatibility

**Automatic Import:**
```lua
-- Imports all Lambda weapons on startup
hook.Add("Initialize", "EXP_ImportLambdaWeapons", function()
    timer.Simple(2, function()
        for weaponName, weaponData in pairs(_LAMBDAPLAYERSWEAPONS) do
            if !_EXPERIMENTALPLAYERSWEAPONS[weaponName] then
                _EXPERIMENTALPLAYERSWEAPONS[weaponName] = table.Copy(weaponData)
            end
        end
    end)
end)
```

**Compatible Addons:**
- Lambda Players CSS Weapons
- Lambda Players L4D2 Weapons
- Lambda Players TF2 Weapons
- All other Lambda weapon packs

### Base Weapons Included

**Half-Life 2 Arsenal:**
- Melee: Crowbar, Stun Stick
- Pistols: Pistol, .357 Magnum
- SMGs: SMG1
- Rifles: AR2, Crossbow
- Shotguns: Shotgun

---

## Navigation & Movement

### Dual-Entity Architecture

**Player Bot:** Handles actions, combat, AI
**Navigator Entity:** Handles pathfinding, path storage

```lua
-- Navigator is a separate nextbot
local navigator = ents.Create("exp_navigator")
navigator:SetOwner(playerBot)
navigator:Spawn()

-- Player references navigator
bot.Navigator = navigator
```

### Movement System (`movement.lua`)

**MoveToPos - Main Movement Function:**
```lua
bot:MoveToPos(position, {
    tolerance = 30,      -- Distance to consider "reached"
    sprint = true,       -- Auto-sprint for long distances
    maxage = 15,         -- Timeout in seconds
})

-- Returns: "ok", "failed", "timeout", "stuck", "abort", "dead"
```

**How It Works:**
1. Navigator computes path using Source's Path() system
2. `MoveToPos()` enters coroutine loop
3. Each frame calls `UpdateOnPath()`
4. `UpdateOnPath()` checks current segment, moves towards it
5. When segment reached, advances to next
6. Continues until destination or abort condition

**Input-Based Movement:**
```lua
function PLAYER:MoveTowards(pos)
    -- Calculate direction
    local dir = (pos - self:GetPos()):GetNormalized()
    local targetAng = dir:Angle()

    -- Smooth angle transition
    local newAng = LerpAngle(0.1, self:EyeAngles(), targetAng)
    self:SetEyeAngles(newAng)

    -- Calculate input based on direction
    local forward = dir:Dot(self:EyeAngles():Forward())
    local right = dir:Dot(self:EyeAngles():Right())

    -- Set input keys (THIS IS THE MAGIC!)
    if forward > 0.5 then
        self:SetButtonDown(IN_FORWARD)
    elseif forward < -0.5 then
        self:SetButtonDown(IN_BACK)
    end

    if right > 0.5 then
        self:SetButtonDown(IN_MOVERIGHT)
    elseif right < -0.5 then
        self:SetButtonDown(IN_MOVELEFT)
    end
end
```

**Why This Works:**
- PlayerBots respond to button presses like real players
- `IN_FORWARD`, `IN_BACK`, etc. are actual player inputs
- Source engine handles movement physics
- Result: Bots move EXACTLY like human players

### Locomotion Features

**Jumping:**
```lua
function PLAYER:Jump()
    if self:IsOnGround() then
        self:SetButtonDown(IN_JUMP)
        timer.Simple(0.1, function()
            self:SetButtonUp(IN_JUMP)
        end)
    end
end
```

**Sprinting:**
```lua
bot:SetSprint(true)  -- Sets IN_SPEED button
-- Auto-enabled for distances > 1000 units
```

**Crouching:**
```lua
bot:SetCrouch(true)  -- Sets IN_DUCK button
-- Auto-enabled in tight spaces
```

### Stuck Detection

**Algorithm:**
```lua
function PLAYER:IsStuck()
    -- Check if position hasn't changed in 3 seconds
    if CurTime() < self.exp_StuckTimer then return false end

    local dist = self:GetPos():Distance(self.exp_StuckPosition)
    if dist < 10 then
        return true  -- Stuck!
    end
    return false
end

function PLAYER:ClearStuck()
    self.exp_StuckPosition = self:GetPos()
    self.exp_StuckTimer = CurTime() + 3
    self:Jump()  -- Try to jump out
end
```

### Navigator Entity (`exp_navigator.lua`)

**Path Management:**
```lua
ENT:ComputePath(goal, options)  -- Calculate path
ENT:GetPath()                   -- Get current path
ENT:IsPathValid()               -- Check if path exists
ENT:InvalidatePath()            -- Clear path
ENT:GetCurrentSegment()         -- Get current segment index
ENT:AdvanceSegment()            -- Move to next segment
ENT:RecomputePath()             -- Recalculate path
```

---

## AI & States

### State Machine

**States:**
- `Idle` - Standing still, waiting
- `Wander` - Exploring randomly
- `Combat` - Fighting enemies

**State Structure:**
```lua
function PLAYER:SetState(newState)
    self.exp_State = newState
    self.exp_StateTime = CurTime()
end

function PLAYER:ThreadedThink()
    while true do
        local state = self.exp_State or "Idle"

        if state == "Idle" then
            self:State_Idle()
        elseif state == "Wander" then
            self:State_Wander()
        elseif state == "Combat" then
            self:State_Combat()
        end

        coroutine_wait(0.1)
    end
end
```

### State: Idle

```lua
function PLAYER:State_Idle()
    -- Do nothing for 2-5 seconds
    if CurTime() > self.exp_StateTime + math.random(2, 5) then
        self:SetState("Wander")
    end
    coroutine_wait(1)
end
```

### State: Wander

```lua
function PLAYER:State_Wander()
    -- Pick random position nearby
    local randomPos = self:GetPos() + Vector(
        math.random(-500, 500),
        math.random(-500, 500),
        0
    )

    -- Move there
    local result = self:MoveToPos(randomPos, {
        tolerance = 50,
        sprint = false,
        maxage = 10
    })

    -- Wait at destination
    if result == "ok" then
        coroutine_wait(math.random(2, 4))
    end

    self:SetState("Idle")
end
```

### State: Combat

```lua
function PLAYER:State_Combat()
    if !IsValid(self.exp_Enemy) then
        self:SetState("Idle")
        return
    end

    local enemy = self.exp_Enemy
    local dist = self:GetPos():Distance(enemy:GetPos())
    local keepDist = self.exp_CombatKeepDistance or 200
    local attackRange = self.exp_CombatAttackRange or 500

    -- Tactical positioning
    if dist > attackRange then
        self:MoveTowards(enemy:GetPos())  -- Close in
    elseif dist < keepDist * 0.5 then
        local awayPos = self:GetPos() - (enemy:GetPos() - self:GetPos()):GetNormalized() * 200
        self:MoveTowards(awayPos)  -- Back up
    else
        self:StopMoving()  -- Hold position
    end

    -- Aim at enemy
    local aimDir = (enemy:GetPos() + Vector(0, 0, 40) - self:GetShootPos()):GetNormalized()
    self:SetEyeAngles(aimDir:Angle())

    -- Attack if in range
    if dist <= attackRange then
        self:Attack(enemy)
    end

    -- Reload if needed
    if self:CanReload() and self:GetWeaponClip() <= 2 then
        self:Reload()
    end

    coroutine_wait(0.1)
end
```

---

## File Structure

```
experimental-players/
├── LICENSE                                    # MIT License
├── README.md                                  # User documentation
├── CLAUDE.MD                                  # Technical documentation (this file)
├── SETUP_GITHUB.md                           # GitHub setup instructions
├── addon.json                                # GMod addon metadata
│
├── lua/
│   ├── autorun/
│   │   └── experimental_players_autorun.lua  # Main initialization
│   │
│   ├── entities/
│   │   ├── exp_navigator.lua                 # Navigator nextbot entity
│   │   └── exp_spawner.lua                   # Spawn menu entity
│   │
│   └── experimental_players/
│       ├── exp_player.lua                    # Main PlayerBot class
│       │
│       ├── includes/                         # Core systems
│       │   ├── sh_convars.lua                # Console variables
│       │   ├── sh_filesystem.lua             # File I/O system
│       │   ├── sh_globals.lua                # Global functions
│       │   └── sh_weapons.lua                # Weapon registry
│       │
│       ├── players/                          # Player behavior modules
│       │   ├── movement.lua                  # Movement & navigation
│       │   └── weaponhandling.lua            # Weapon management
│       │
│       ├── weapons/                          # Weapon definitions
│       │   └── hl2_weapons.lua               # Half-Life 2 weapons
│       │
│       ├── social/                           # Social features (TODO)
│       ├── gamemodes/                        # Game modes (TODO)
│       │
│       ├── compatibility/                    # Addon compatibility
│       │   └── sh_lambda_weapons.lua         # Lambda weapon import
│       │
│       └── panels/                           # UI panels (TODO)
│
└── materials/                                # Textures, sprites
    └── sound/                                # Custom sounds
```

---

## Development Guide

### Adding a New Weapon

1. **Create weapon definition:**

```lua
-- In lua/experimental_players/weapons/custom_weapons.lua
table.Merge(_EXPERIMENTALPLAYERSWEAPONS, {
    mygun = {
        model = "models/weapons/w_mygun.mdl",
        prettyname = "My Custom Gun",
        origin = "My Addon",
        holdtype = "pistol",
        killicon = "weapon_mygun",
        ismelee = false,
        islethal = true,

        -- Stats
        damage = 10,
        attackrange = 2000,
        keepdistance = 300,
        clip = 12,
        spread = 0.2,
        rateoffire = 0.3,

        -- Visual
        tracername = "Tracer",
        muzzleflash = 1,
        shelleject = "ShellEject",

        -- Reload
        reloadtime = 2.0,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_PISTOL,
        reloadsounds = { {0.5, "weapons/mygun/reload.wav"} },
    }
})
```

2. **Custom behavior (optional):**

```lua
mygun = {
    -- ... stats ...

    OnAttack = function(ply, wepent, target)
        -- Custom attack logic
        ply:EmitSound("mygun/fire.wav")
        -- Return true to prevent default attack
    end,

    OnDeploy = function(ply, wepent, oldwep)
        -- When equipped
    end,

    OnHolster = function(ply, wepent, oldwep, newwep)
        -- When unequipped
        -- Return true to prevent holster
    end,
}
```

### Adding a New State

```lua
-- In exp_player.lua

function PLAYER:State_MyNewState()
    -- State logic
    local result = self:MoveToPos(somePosition)

    if result == "ok" then
        -- Do something
    end

    -- Change state
    self:SetState("Idle")

    coroutine_wait(0.1)
end

-- In ThreadedThink()
elseif state == "MyNewState" then
    self:State_MyNewState()
```

### Adding Hooks

```lua
-- Somewhere in your code
hook.Add("EXP_OnPlayerInitialize", "MyAddon_Init", function(ply)
    print("Bot spawned:", ply:Nick())
end)

hook.Add("EXP_OnPlayerKilled", "MyAddon_Death", function(ply, attacker, dmginfo)
    print(ply:Nick(), "was killed by", attacker:Nick())
end)
```

### Creating Bot Profiles

```lua
-- data/experimental_players/profiles.json
{
    "Rambo": {
        "name": "Rambo",
        "model": "models/player/urban.mdl",
        "weapon": "ar2",
        "playercolor": "1 0 0",
        "personality": "aggressive"
    },
    "Medic": {
        "name": "Medic",
        "model": "models/player/kleiner.mdl",
        "weapon": "pistol",
        "personality": "defensive"
    }
}
```

---

## API Reference

### EXP (Global Table)

**Core:**
- `EXP:CreateLambdaPlayer(name, profile)` - Spawn a bot
- `EXP:InitializeBot(ply, glace)` - Initialize bot properties
- `EXP:Random(min, max, float)` - Random number/element
- `EXP:RunHook(hookname, ...)` - Run custom hook

**Weapons:**
- `EXP:RegisterWeapon(name, data)` - Register weapon
- `EXP:WeaponExists(name)` - Check if weapon exists
- `EXP:GetWeaponData(name)` - Get weapon table
- `EXP:GetRandomWeapon(lethal, ranged, melee)` - Random weapon
- `EXP:ImportLambdaWeapons()` - Import from Lambda

**ConVars:**
- `EXP:CreateConVar(name, default, desc, data)` - Create CVar
- `EXP:GetConVar(name)` - Get CVar value

### PLAYER (Player Methods)

**Movement:**
- `bot:MoveToPos(pos, options)` - Move to position
- `bot:MoveTowards(pos)` - Move in direction
- `bot:StopMoving()` - Stop all movement
- `bot:Jump()` - Jump
- `bot:SetSprint(bool)` - Enable/disable sprint
- `bot:SetCrouch(bool)` - Enable/disable crouch
- `bot:IsStuck()` - Check if stuck
- `bot:ClearStuck()` - Clear stuck state

**Weapons:**
- `bot:SwitchWeapon(name, force)` - Equip weapon
- `bot:Attack(target)` - Attack target
- `bot:Reload()` - Reload weapon
- `bot:CanAttack()` - Check if can attack
- `bot:CanReload()` - Check if can reload
- `bot:GetCurrentWeapon()` - Get current weapon name
- `bot:GetWeaponClip()` - Get current ammo

**States:**
- `bot:SetState(state)` - Change AI state
- `bot:State_Idle()` - Idle behavior
- `bot:State_Wander()` - Wander behavior
- `bot:State_Combat()` - Combat behavior

**Utility:**
- `bot:GetWeaponENT()` - Get weapon entity
- `bot:SetGoalTolerance(dist)` - Set movement tolerance
- `bot:CancelMovement()` - Abort movement

---

## Credits & Attribution

**Based on:**
- **GLambda Players** by Lolleko - Revolutionary PlayerBot architecture
- **Lambda Players** by Lambda Gaming - Weapon system, clean code structure
- **Zeta Players** by Zetaplayer - Social features inspiration

**Created by:** Fenri-Lunaedge
**Developed with:** Claude Code (Anthropic Claude Sonnet 4.5)
**License:** MIT

---

## Version History

### v1.0 (In Development)
- ✅ Core GLambda architecture
- ✅ Complete weapon system (10 HL2 weapons)
- ✅ Lambda weapon compatibility (100+ weapons)
- ✅ Advanced navigation with input-based movement
- ✅ Combat AI with tactical positioning
- ⏳ Social features (pending)
- ⏳ Building system (pending)
- ⏳ Game modes (pending)

**Current Stats:**
- ~2,800 lines of code
- 15 files
- 2 systems complete (Weapons, Navigation)
- Multiplayer only

---

**Last Updated:** 2025-11-15
**Generated with:** Claude Code
