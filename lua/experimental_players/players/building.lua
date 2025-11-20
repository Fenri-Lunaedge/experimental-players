-- Experimental Players - Building System
-- Based on Lambda Players building
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
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

function PLAYER:SpawnProp(model, pos, ang, freeze)
    if !self:IsUnderLimit("Prop") then return end
    if !EXP:GetConVar("building_enabled") then return end

    -- Get spawn position and angle with precision
    local spawnPos, spawnAng

    if pos and ang then
        -- Manual position/angle (for precise building)
        spawnPos = pos
        spawnAng = ang
    else
        -- Auto-position with surface detection
        local trace = util_TraceLine({
            start = self:GetShootPos(),
            endpos = self:GetShootPos() + self:GetAimVector() * 200,
            filter = self,
            mask = MASK_SOLID
        })

        if trace.Hit then
            -- Snap to surface with proper alignment
            spawnPos = trace.HitPos + trace.HitNormal * 5
            spawnAng = trace.HitNormal:Angle()
            spawnAng:RotateAroundAxis(spawnAng:Right(), -90) -- Align to surface
        else
            spawnPos = self:GetPos() + self:GetForward() * 100
            spawnAng = self:GetAngles()
        end
    end

    -- Get prop model
    if !model then
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
        model = props[math_random(#props)]
    end

    if !model then return end

    -- Create prop
    local prop = ents_Create("prop_physics")
    if !IsValid(prop) then return end

    prop:SetModel(model)
    prop:SetPos(spawnPos)
    prop:SetAngles(spawnAng)
    prop.exp_Owner = self
    prop.exp_IsSpawned = true
    prop:Spawn()
    prop:Activate()

    -- Physics
    local phys = prop:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()

        -- Freeze if requested (for precise placement)
        if freeze then
            phys:EnableMotion(false)
        end
    end

    -- Sound
    self:EmitSound("ui/buttonclickrelease.wav", 60)

    -- Track entity
    table_insert(self.exp_SpawnedEntities, 1, prop)
    self:ContributeToLimit(prop, "Prop")

    print("[EXP] " .. self:Nick() .. " spawned prop: " .. model)
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

--[[ Advanced Building Functions ]]--

function PLAYER:DuplicateProp(originalProp)
    if !IsValid(originalProp) then return nil end
    if !self:IsUnderLimit("Prop") then return nil end

    local model = originalProp:GetModel()
    local pos = originalProp:GetPos() + Vector(50, 0, 0) -- Offset to side
    local ang = originalProp:GetAngles()

    -- Spawn duplicate
    local duplicate = self:SpawnProp(model, pos, ang, false)

    if IsValid(duplicate) then
        -- Copy physical properties
        local origPhys = originalProp:GetPhysicsObject()
        local dupPhys = duplicate:GetPhysicsObject()

        if IsValid(origPhys) and IsValid(dupPhys) then
            dupPhys:SetMaterial(origPhys:GetMaterial())
        end

        -- Copy color
        duplicate:SetColor(originalProp:GetColor())
        duplicate:SetMaterial(originalProp:GetMaterial())

        print("[EXP] " .. self:Nick() .. " duplicated prop")
    end

    return duplicate
end

function PLAYER:StackPropOnTop(baseProp, model)
    if !IsValid(baseProp) then return nil end
    if !self:IsUnderLimit("Prop") then return nil end

    -- Calculate position on top of base prop
    local basePos = baseProp:GetPos()
    local baseOBB = baseProp:OBBMaxs()
    local stackPos = basePos + Vector(0, 0, baseOBB.z + 5)
    local stackAng = baseProp:GetAngles()

    -- Spawn on top
    local stackedProp = self:SpawnProp(model, stackPos, stackAng, false)

    if IsValid(stackedProp) then
        print("[EXP] " .. self:Nick() .. " stacked prop on top")
    end

    return stackedProp
end

function PLAYER:BuildWall(width, height, model)
    if !self:IsUnderLimit("Prop") then return end

    model = model or "models/props_junk/wood_crate001a.mdl"
    width = math.min(width or 3, 5) -- Max 5 wide
    height = math.min(height or 2, 4) -- Max 4 high

    local startPos = self:GetPos() + self:GetForward() * 100
    local rightVec = self:GetRight()
    local ang = self:GetAngles()

    local props = {}

    for h = 1, height do
        for w = 1, width do
            if !self:IsUnderLimit("Prop") then break end

            local offset = rightVec * (w - 1) * 50 + Vector(0, 0, (h - 1) * 50)
            local pos = startPos + offset

            local prop = self:SpawnProp(model, pos, ang, true) -- Freeze wall props

            if IsValid(prop) then
                table.insert(props, prop)
            end
        end
    end

    print("[EXP] " .. self:Nick() .. " built a " .. width .. "x" .. height .. " wall (" .. #props .. " props)")
    return props
end

--[[ Automatic Building ]]--

function PLAYER:ShouldBuild()
    -- Check if building is enabled
    if !EXP:GetConVar("building_enabled") then return false end

    -- Check cooldown
    if CurTime() < self.exp_NextBuildTime then return false end

    -- Only build when idle or wandering
    if self.exp_State  ~=  "Idle" and self.exp_State  ~=  "Wander" then return false end

    -- Personality-based building chance
    local buildChance = 0.1  -- Default 10%

    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            if personality.name == "Joker" then
                buildChance = 0.3  -- Jokers spawn random stuff
            elseif personality.name == "Tactical" then
                buildChance = 0.15  -- Tactical builds strategically
            elseif personality.name == "Support" then
                buildChance = 0.2  -- Support builds defenses/utilities
            elseif personality.name == "Defensive" then
                buildChance = 0.25  -- Defensive builds cover
            elseif personality.name == "Aggressive" then
                buildChance = 0.05  -- Aggressive rarely builds
            elseif personality.name == "Silent" then
                buildChance = 0.08  -- Silent prefers observation
            end
        end
    end

    -- Random roll
    if math_random() > buildChance then return false end

    return true
end

function PLAYER:Think_Building()
    if !self.exp_NextBuildTime then
        self:InitializeBuilding()
        return
    end

    if self:ShouldBuild() then
        -- Personality-based action selection
        local personality = self.GetPersonalityData and self:GetPersonalityData()
        local action = math_random(1, 3)

        if personality then
            if personality.name == "Joker" then
                -- Jokers prefer props and random stuff
                action = math_random(1, 2) == 1 and 1 or 3
            elseif personality.name == "Tactical" or personality.name == "Support" then
                -- Tactical/Support prefer useful entities
                action = 2
            elseif personality.name == "Defensive" then
                -- Defensive spawns cover (props)
                action = 1
            end
        end

        -- Execute chosen action
        if action == 1 then
            self:SpawnProp()
        elseif action == 2 and #(EXP.SpawnlistENTs or {}) > 0 then
            self:SpawnEntity()
        elseif action == 3 and #(EXP.SpawnlistNPCs or {}) > 0 then
            self:SpawnNPC()
        else
            -- Fallback to props if other options unavailable
            self:SpawnProp()
        end

        -- Personality-based cooldown
        local cooldown = math_random(30, 60)  -- Default

        if personality then
            if personality.name == "Joker" then
                cooldown = math_random(15, 30)  -- More frequent
            elseif personality.name == "Support" or personality.name == "Defensive" then
                cooldown = math_random(20, 40)  -- Moderate
            elseif personality.name == "Aggressive" then
                cooldown = math_random(60, 120)  -- Rare
            end
        end

        self.exp_NextBuildTime = CurTime() + cooldown
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
