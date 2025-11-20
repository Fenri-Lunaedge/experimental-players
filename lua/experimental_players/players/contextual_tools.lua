-- Experimental Players - Contextual Tool Usage
-- Smart tool usage based on situation
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local math_Rand = math.Rand

local PLAYER = EXP.Player

--[[ Contextual Tool Usage ]]--

-- Use gravgun in combat to throw props at enemies
function PLAYER:ContextualUse_Gravgun()
    if !IsValid(self.exp_Enemy) then return false end
    if !EXP:WeaponExists("gravgun") then return false end

    -- Find nearby props
    if !self.FindNearbyProps then return false end
    local props = self:FindNearbyProps(400)

    if #props == 0 then return false end

    -- Tactical/Joker personalities more likely to use gravgun in combat
    local useChance = 0.2  -- 20% default

    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            if personality.name == "Tactical" then
                useChance = 0.5  -- 50%
            elseif personality.name == "Joker" then
                useChance = 0.6  -- 60%
            elseif personality.name == "Aggressive" then
                useChance = 0.3  -- 30%
            end
        end
    end

    if math_random() > useChance then return false end

    -- Switch to gravgun and use behavior
    self:SwitchWeapon("gravgun", true)

    -- Use gravgun behavior
    if self.Behavior_UseGravgun then
        -- Run in background (don't block combat)
        timer.Simple(0.1, function()
            if IsValid(self) then
                self:Behavior_UseGravgun()
            end
        end)
    end

    return true
end

-- Use toolgun to create cover when taking damage
function PLAYER:ContextualUse_ToolgunCover()
    if !EXP:WeaponExists("toolgun") then return false end
    if !EXP:GetConVar("building_toolgun") then return false end

    -- Check if we're taking damage
    local recentDamage = self.exp_LastDamageTime and (CurTime() - self.exp_LastDamageTime < 3)
    if !recentDamage then return false end

    -- Check health
    local healthRatio = self:Health() / self:GetMaxHealth()
    if healthRatio > 0.6 then return false end  -- Only when low health

    -- Defensive/Support/Tactical personalities use cover
    local useChance = 0.1  -- 10% default

    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            if personality.name == "Defensive" then
                useChance = 0.8  -- 80%
            elseif personality.name == "Tactical" then
                useChance = 0.6  -- 60%
            elseif personality.name == "Support" then
                useChance = 0.5  -- 50%
            end
        end
    end

    if math_random() > useChance then return false end

    -- Spawn quick cover (single prop with weld)
    if self.SpawnProp then
        local coverProp = self:SpawnProp("models/props_c17/FurnitureDrawer001a.mdl", nil, nil, true)

        if IsValid(coverProp) then
            -- Position in front of player
            local coverPos = self:GetPos() + self:GetForward() * 100
            coverPos.z = self:GetPos().z
            coverProp:SetPos(coverPos)
            coverProp:SetAngles(self:GetAngles())

            -- Make it solid cover
            coverProp:GetPhysicsObject():EnableMotion(false)

            print("[EXP] " .. self:Nick() .. " created emergency cover!")
            return true
        end
    end

    return false
end

-- Use physgun to build defenses when idle in gamemode
function PLAYER:ContextualUse_BuildDefense()
    if !EXP:WeaponExists("physgun") then return false end
    if !EXP.GameMode or !EXP.GameMode.Active then return false end

    -- Only Support/Defensive/Tactical
    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            local name = personality.name
            if name  ~=  "Defensive" and name  ~=  "Support" and name  ~=  "Tactical" then
                return false
            end
        else
            return false
        end
    else
        return false
    end

    -- Find team objective (flag, point, etc.)
    local myTeam = EXP:GetPlayerTeam(self)
    if !myTeam then return false end

    -- Get defensive position from gamemode
    local gamemode = EXP:GetGameMode(EXP.GameMode.Name)
    if !gamemode or !gamemode.GetDefensePosition then return false end

    local defensePos = gamemode:GetDefensePosition(self, myTeam)
    if !defensePos then return false end

    -- Build cover near defense position
    if self.BuildWeldedStructure then
        -- Move near defense position first
        local dist = self:GetPos():Distance(defensePos)
        if dist > 300 then
            self:MoveToPos(defensePos, {
                tolerance = 200,
                sprint = true,
                maxage = 15
            })
        end

        -- Build defense structure
        timer.Simple(0.5, function()
            if IsValid(self) then
                self:BuildWeldedStructure()
            end
        end)

        return true
    end

    return false
end

--[[ Integration with Combat/Idle States ]]--

function PLAYER:Think_ContextualTools()
    -- Initialize check time
    if !self.exp_NextContextualToolCheck then
        self.exp_NextContextualToolCheck = CurTime() + math_Rand(5, 15)
        return
    end

    if CurTime() < self.exp_NextContextualToolCheck then return end
    self.exp_NextContextualToolCheck = CurTime() + math_Rand(10, 20)

    -- Priority 1: Emergency cover when taking damage
    if self.exp_State == "Combat" or self.exp_State == "Retreat" then
        if self:ContextualUse_ToolgunCover() then
            return
        end
    end

    -- Priority 2: Gravgun in combat (if has props nearby)
    if self.exp_State == "Combat" then
        if self:ContextualUse_Gravgun() then
            return
        end
    end

    -- Priority 3: Build defenses when idle in gamemode
    if self.exp_State == "Idle" or self.exp_State == "Wander" then
        if self:ContextualUse_BuildDefense() then
            return
        end
    end
end

print("[Experimental Players] Contextual tool usage system loaded")
