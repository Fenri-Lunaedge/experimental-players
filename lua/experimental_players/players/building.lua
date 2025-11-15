-- Experimental Players - Building System
-- Based on Lambda Players building
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local ents_Create = ents.Create
local table_insert = table.insert
local table_remove = table.remove
local Angle = Angle
local Vector = Vector
local math_random = math.random
local util_TraceLine = util.TraceLine

local PLAYER = EXP.Player

--[[ Building Initialization ]]--

function PLAYER:InitializeBuilding()
    self.exp_SpawnedEntities = {}
    self.exp_EntityLimits = {
        Prop = 0,
        NPC = 0,
        Entity = 0
    }
    self.exp_NextBuildTime = CurTime() + math_random(10, 30)
end

--[[ Entity Limits ]]--

function PLAYER:GetEntityLimit(entType)
    local maxProps = EXP:GetConVar("building_maxprops") or 10
    return maxProps
end

function PLAYER:IsUnderLimit(entType)
    local current = self.exp_EntityLimits[entType] or 0
    local max = self:GetEntityLimit(entType)
    return current < max
end

function PLAYER:ContributeToLimit(ent, entType)
    self.exp_EntityLimits[entType] = (self.exp_EntityLimits[entType] or 0) + 1

    -- Remove from limit when entity is removed
    ent:CallOnRemove("EXP_RemoveFromLimit", function()
        if IsValid(self) then
            self.exp_EntityLimits[entType] = math.max(0, (self.exp_EntityLimits[entType] or 0) - 1)
        end
    end)
end

--[[ Permission System ]]--

function PLAYER:HasPermissionToEdit(ent)
    if !IsValid(ent) then return false end
    if !IsValid(ent:GetPhysicsObject()) then return false end

    -- Own entities
    if ent.exp_Owner == self then return true end

    -- Map entities (if convar allows)
    if ent:CreatedByMap() then
        return EXP:GetConVar("building_caneditworld") == 1
    end

    -- Other entities
    return EXP:GetConVar("building_caneditothers") == 1
end

--[[ Prop Spawning ]]--

function PLAYER:SpawnProp()
    if !self:IsUnderLimit("Prop") then return end
    if !EXP:GetConVar("building_enabled") then return end

    -- Get spawn position
    local trace = util_TraceLine({
        start = self:GetShootPos(),
        endpos = self:GetShootPos() + self:GetAimVector() * 200,
        filter = self,
        mask = MASK_SOLID
    })

    -- Get random prop model
    local props = EXP.SpawnlistProps
    if !props or #props == 0 then
        -- Default props
        props = {
            "models/props_c17/oildrum001.mdl",
            "models/props_c17/furniturechair001a.mdl",
            "models/props_junk/wood_crate001a.mdl",
            "models/props_junk/PopCan01a.mdl",
        }
    end

    local model = props[math_random(#props)]
    if !model then return end

    -- Create prop
    local prop = ents_Create("prop_physics")
    if !IsValid(prop) then return end

    prop:SetModel(model)
    prop:SetPos(trace.HitPos + Vector(0, 0, 10))
    prop:SetAngles(Angle(0, self:EyeAngles().y, 0))
    prop.exp_Owner = self
    prop.exp_IsSpawned = true
    prop:Spawn()
    prop:Activate()

    -- Physics
    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    -- Sound
    self:EmitSound("ui/buttonclickrelease.wav", 60)

    -- Track entity
    table_insert(self.exp_SpawnedEntities, 1, prop)
    self:ContributeToLimit(prop, "Prop")

    return prop
end

--[[ Entity Spawning ]]--

function PLAYER:SpawnEntity()
    if !self:IsUnderLimit("Entity") then return end
    if !EXP:GetConVar("building_enabled") then return end

    -- Get spawn position
    local trace = util_TraceLine({
        start = self:GetShootPos(),
        endpos = self:GetShootPos() + self:GetAimVector() * 200,
        filter = self,
        mask = MASK_SOLID
    })

    -- Get random entity
    local entities = EXP.SpawnlistENTs
    if !entities or #entities == 0 then
        return  -- No entities to spawn
    end

    local class = entities[math_random(#entities)]
    if !class then return end

    -- Create entity
    local ent = ents_Create(class)
    if !IsValid(ent) then return end

    ent:SetPos(trace.HitPos + Vector(0, 0, 10))
    ent:SetAngles(Angle(0, self:EyeAngles().y, 0))
    ent.exp_Owner = self
    ent.exp_IsSpawned = true
    ent:Spawn()
    ent:Activate()

    -- Sound
    self:EmitSound("ui/buttonclickrelease.wav", 60)

    -- Track entity
    table_insert(self.exp_SpawnedEntities, 1, ent)
    self:ContributeToLimit(ent, "Entity")

    return ent
end

--[[ NPC Spawning ]]--

function PLAYER:SpawnNPC()
    if !self:IsUnderLimit("NPC") then return end
    if !EXP:GetConVar("building_enabled") then return end

    -- Get spawn position
    local trace = util_TraceLine({
        start = self:GetShootPos(),
        endpos = self:GetShootPos() + self:GetAimVector() * 200,
        filter = self,
        mask = MASK_SOLID
    })

    -- Get random NPC
    local npcs = EXP.SpawnlistNPCs
    if !npcs or #npcs == 0 then
        -- Default NPCs
        npcs = {
            "npc_zombie",
            "npc_headcrab",
            "npc_antlion",
        }
    end

    local class = npcs[math_random(#npcs)]
    if !class then return end

    -- Create NPC
    local npc = ents_Create(class)
    if !IsValid(npc) then return end

    npc:SetPos(trace.HitPos + Vector(0, 0, 10))
    npc:SetAngles(Angle(0, self:EyeAngles().y, 0))
    npc.exp_Owner = self
    npc.exp_IsSpawned = true
    npc:Spawn()
    npc:Activate()

    -- Sound
    self:EmitSound("ui/buttonclickrelease.wav", 60)

    -- Track entity
    table_insert(self.exp_SpawnedEntities, 1, npc)
    self:ContributeToLimit(npc, "NPC")

    return npc
end

--[[ Cleanup ]]--

function PLAYER:CleanupEntities()
    for k, ent in ipairs(self.exp_SpawnedEntities) do
        if IsValid(ent) then
            ent:Remove()
        end
        self.exp_SpawnedEntities[k] = nil
    end

    self.exp_EntityLimits = {
        Prop = 0,
        NPC = 0,
        Entity = 0
    }
end

function PLAYER:UndoLastEntity()
    local ent = self.exp_SpawnedEntities[1]
    if IsValid(ent) then
        ent:Remove()
        table_remove(self.exp_SpawnedEntities, 1)
        self:EmitSound("buttons/button15.wav", 60)
    end
end

--[[ Automatic Building ]]--

function PLAYER:ShouldBuild()
    -- TEMPORARILY DISABLED - Causing issues during testing
    return false

    --[[ ORIGINAL CODE:
    if !EXP:GetConVar("building_enabled") then return false end
    if CurTime() < self.exp_NextBuildTime then return false end
    if self.exp_State != "Idle" and self.exp_State != "Wander" then return false end
    if math_random(1, 100) > 20 then return false end  -- 20% chance

    return true
    ]]--
end

function PLAYER:Think_Building()
    if !self.exp_NextBuildTime then
        self:InitializeBuilding()
        return
    end

    if self:ShouldBuild() then
        -- Random action
        local action = math_random(1, 3)
        if action == 1 then
            self:SpawnProp()
        elseif action == 2 and #(EXP.SpawnlistENTs or {}) > 0 then
            self:SpawnEntity()
        elseif action == 3 and #(EXP.SpawnlistNPCs or {}) > 0 then
            self:SpawnNPC()
        end

        self.exp_NextBuildTime = CurTime() + math_random(30, 60)
    end
end

--[[ Cleanup on death ]]--

hook.Add("PlayerDeath", "EXP_CleanupOnDeath", function(victim, inflictor, attacker)
    if !IsValid(victim) or !victim.exp_IsExperimentalPlayer then return end

    -- Find GLACE wrapper
    if EXP.ActiveBots then
        for _, bot in ipairs(EXP.ActiveBots) do
            if bot._PLY == victim and bot.CleanupEntities then
                bot:CleanupEntities()
                break
            end
        end
    end
end)

print("[Experimental Players] Building system loaded")
