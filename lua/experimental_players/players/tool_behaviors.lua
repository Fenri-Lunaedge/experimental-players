-- Experimental Players - Tool Using Behaviors
-- AI for using physgun, gravity gun, and building
-- Based on Lambda Players building system

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local math = math
local coroutine_yield = coroutine.yield

local PLAYER = EXP.Player

--[[ Coroutine Helper ]]--

local function CoroutineWait(self, seconds)
    self.exp_CoroutineWaitUntil = CurTime() + seconds
    while CurTime() < self.exp_CoroutineWaitUntil do
        coroutine_yield()
    end
end

--[[ Physgun Behaviors ]]--

function PLAYER:Behavior_UsePhysgun()
    -- Find a prop to interact with
    local prop = self:FindRandomProp(800)
    if !IsValid(prop) then
        CoroutineWait(self, 2)
        return "no_props"
    end

    -- Look at the prop
    self.exp_LookTowards_Pos = prop:GetPos() + Vector(0, 0, 20)
    self.exp_LookTowards_EndT = CurTime() + 1
    CoroutineWait(self, 1)

    -- Pick it up
    if self.SwitchWeapon then
        self:SwitchWeapon("physgun", true)
        CoroutineWait(self, 0.5)
    end

    -- Simulate attack to pick up
    if IsValid(prop) and self:CanSeeEntity(prop) then
        self:PhysgunPickup(prop, prop:GetPos())
        CoroutineWait(self, 0.5)

        -- Hold for a bit, maybe move around
        local holdTime = math.random(2, 5)
        local endTime = CurTime() + holdTime

        while CurTime() < endTime and IsValid(self.exp_PhysgunGrabbedEnt) do
            -- Randomly adjust distance
            if math.random(1, 100) > 80 then
                self:PhysgunAdjustDistance(math.random(-50, 50))
            end

            -- Maybe rotate
            if math.random(1, 100) > 90 then
                self:PhysgunSetRotation(AngleRand(-180, 180))
            end

            CoroutineWait(self, 0.5)
        end

        -- Decide what to do with it
        local action = math.random(1, 3)

        if action == 1 then
            -- Freeze it
            self:PhysgunFreeze()
        elseif action == 2 then
            -- Just drop it
            self:PhysgunDrop()
        else
            -- Move it somewhere and drop
            local randomPos = self:GetPos() + VectorRand(-200, 200)
            self.exp_PhysgunHoldPos = randomPos + Vector(0, 0, 50)
            CoroutineWait(self, 2)
            self:PhysgunDrop()
        end
    end

    CoroutineWait(self, 1)
    return "ok"
end

--[[ Building Behavior ]]--

function PLAYER:Behavior_BuildStructure()
    -- Simple building: spawn and stack props
    if !EXP:GetConVar("building_enabled") then
        return "disabled"
    end

    if !self:IsUnderLimit("Prop") then
        return "at_limit"
    end

    -- Switch to physgun
    if self.SwitchWeapon then
        self:SwitchWeapon("physgun", true)
        CoroutineWait(self, 0.5)
    end

    -- Find or create base prop
    local baseProp = self:FindClosestProp(400)

    if !IsValid(baseProp) and self:IsUnderLimit("Prop") then
        -- Spawn a base prop
        if self.SpawnProp then
            baseProp = self:SpawnProp()
            if IsValid(baseProp) then
                baseProp:GetPhysicsObject():EnableMotion(false)  -- Freeze base
                CoroutineWait(self, 0.5)
            end
        end
    end

    if !IsValid(baseProp) then
        return "no_base"
    end

    -- Build 2-5 props on top
    local propsToAdd = math.random(2, 5)
    for i = 1, propsToAdd do
        if !self:IsUnderLimit("Prop") then break end

        -- Spawn new prop
        local prop = self:SpawnProp()
        if !IsValid(prop) then break end

        CoroutineWait(self, 0.5)

        -- Pick it up
        self:PhysgunPickup(prop, prop:GetPos())
        CoroutineWait(self, 0.3)

        -- Position it on base
        local basePos = baseProp:GetPos()
        local offset = Vector(
            math.random(-30, 30),
            math.random(-30, 30),
            i * 20 + 30  -- Stack upward
        )

        self.exp_PhysgunHoldPos = basePos + offset
        self.exp_PhysgunHoldAng = AngleRand(-30, 30)

        -- Wait for it to settle
        CoroutineWait(self, 2)

        -- Freeze it
        self:PhysgunFreeze()
        CoroutineWait(self, 0.5)
    end

    print("[EXP] " .. self:Nick() .. " built a structure!")
    return "ok"
end

--[[ Gravity Gun Behavior ]]--

function PLAYER:Behavior_UseGravityGun()
    -- Find props to punt
    local prop = self:FindRandomProp(300)
    if !IsValid(prop) then
        CoroutineWait(self, 2)
        return "no_props"
    end

    -- Switch to gravity gun
    if self.SwitchWeapon then
        self:SwitchWeapon("gravgun", true)
        CoroutineWait(self, 0.5)
    end

    -- Look at prop
    self.exp_LookTowards_Pos = prop:GetPos() + Vector(0, 0, 20)
    self.exp_LookTowards_EndT = CurTime() + 1
    CoroutineWait(self, 1)

    -- Move closer if needed
    local dist = self:GetPos():Distance(prop:GetPos())
    if dist > 175 then
        if self.MoveToPos then
            self:MoveToPos(prop:GetPos(), {
                tolerance = 100,
                sprint = false,
                maxage = 5
            })
        end
    end

    -- Punt it!
    if IsValid(prop) and self:CanSeeEntity(prop) then
        local weaponData = self:GetCurrentWeaponData()
        if weaponData and weaponData.OnAttack then
            weaponData.OnAttack(self, self:GetWeaponENT(), prop)
        end
    end

    CoroutineWait(self, 1)
    return "ok"
end

--[[ Toolgun Behaviors ]]--

function PLAYER:Behavior_UseToolgun()
    -- Use toolgun to create contraptions
    if !EXP:GetConVar("building_enabled") then
        return "disabled"
    end

    if !self:IsUnderLimit("Prop") then
        return "at_limit"
    end

    -- Switch to toolgun
    if self.SwitchWeapon then
        self:SwitchWeapon("toolgun", true)
        CoroutineWait(self, 0.5)
    end

    -- Decide what to build
    local buildTypes = {
        function() return self:BuildWeldedStructure() end,
        function() return self:BuildRopedStructure() end,
        function() return self:BuildVehicleFrame() end,
        function() return self:BuildElasticStructure() end,
    }

    local buildType = buildTypes[math.random(#buildTypes)]
    local result = buildType()

    CoroutineWait(self, 1)
    return result
end

function PLAYER:BuildWeldedStructure()
    -- Build a simple welded structure (2-4 props welded together)
    print("[EXP] " .. self:Nick() .. " building welded structure...")

    -- Switch to weld tool
    if self.SwitchTool then self:SwitchTool("weld") end

    -- Spawn base prop
    local baseProp = self:SpawnProp(nil, nil, nil, true)
    if !IsValid(baseProp) then return "spawn_failed" end

    CoroutineWait(self, 0.5)

    -- Add 2-4 props and weld them
    local propsToAdd = math.random(2, 4)
    for i = 1, propsToAdd do
        if !self:IsUnderLimit("Prop") then break end

        -- Spawn prop nearby
        local offset = VectorRand(-100, 100)
        offset.z = math.abs(offset.z) -- Keep above ground
        local newProp = self:SpawnProp(nil, baseProp:GetPos() + offset, nil, true)

        if IsValid(newProp) then
            CoroutineWait(self, 0.3)

            -- Look at base prop
            self.exp_LookTowards_Pos = baseProp:GetPos()
            self.exp_LookTowards_EndT = CurTime() + 0.5
            CoroutineWait(self, 0.5)

            -- Use weld tool (stage 1: select base)
            self:UseTool(baseProp)
            CoroutineWait(self, 0.3)

            -- Look at new prop
            self.exp_LookTowards_Pos = newProp:GetPos()
            self.exp_LookTowards_EndT = CurTime() + 0.5
            CoroutineWait(self, 0.5)

            -- Use weld tool (stage 2: weld)
            self:UseTool(newProp)
            CoroutineWait(self, 0.5)
        end
    end

    print("[EXP] " .. self:Nick() .. " completed welded structure!")
    return "ok"
end

function PLAYER:BuildRopedStructure()
    -- Build structure connected with ropes
    print("[EXP] " .. self:Nick() .. " building roped structure...")

    if self.SwitchTool then self:SwitchTool("rope") end

    -- Spawn 2-3 props in a line
    local props = {}
    local basePos = self:GetPos() + self:GetForward() * 200

    for i = 1, math.random(2, 3) do
        if !self:IsUnderLimit("Prop") then break end

        local offset = Vector(i * 100, 0, 0)
        local prop = self:SpawnProp(nil, basePos + offset, nil, true)

        if IsValid(prop) then
            table.insert(props, prop)
            CoroutineWait(self, 0.5)
        end
    end

    -- Connect them with ropes
    for i = 1, #props - 1 do
        local prop1 = props[i]
        local prop2 = props[i + 1]

        if IsValid(prop1) and IsValid(prop2) then
            -- Look at first prop
            self.exp_LookTowards_Pos = prop1:GetPos()
            self.exp_LookTowards_EndT = CurTime() + 0.5
            CoroutineWait(self, 0.5)

            self:UseTool(prop1)
            CoroutineWait(self, 0.3)

            -- Look at second prop
            self.exp_LookTowards_Pos = prop2:GetPos()
            self.exp_LookTowards_EndT = CurTime() + 0.5
            CoroutineWait(self, 0.5)

            self:UseTool(prop2)
            CoroutineWait(self, 0.5)
        end
    end

    print("[EXP] " .. self:Nick() .. " completed roped structure!")
    return "ok"
end

function PLAYER:BuildVehicleFrame()
    -- Build a simple vehicle frame with wheels
    print("[EXP] " .. self:Nick() .. " building vehicle frame...")

    -- Spawn base (chassis)
    local chassis = self:SpawnProp("models/props_phx/construct/metal_plate1.mdl", nil, nil, true)
    if !IsValid(chassis) then return "spawn_failed" end

    CoroutineWait(self, 0.5)

    -- Switch to wheel tool
    if self.SwitchTool then self:SwitchTool("wheel") end

    -- Add 4 wheels at corners
    local wheelPositions = {
        Vector(40, 40, -10),
        Vector(40, -40, -10),
        Vector(-40, 40, -10),
        Vector(-40, -40, -10),
    }

    for _, offset in ipairs(wheelPositions) do
        local wheelPos = chassis:GetPos() + offset

        -- Look at wheel position
        self.exp_LookTowards_Pos = wheelPos
        self.exp_LookTowards_EndT = CurTime() + 0.5
        CoroutineWait(self, 0.5)

        -- Trace to chassis at wheel position
        local trace = util.TraceLine({
            start = self:GetShootPos(),
            endpos = wheelPos,
            filter = self,
            mask = MASK_SOLID
        })

        if trace.Hit and trace.Entity == chassis then
            self:UseTool(chassis)
            CoroutineWait(self, 0.5)
        end
    end

    print("[EXP] " .. self:Nick() .. " completed vehicle frame!")
    return "ok"
end

function PLAYER:BuildElasticStructure()
    -- Build structure with elastic/spring connections
    print("[EXP] " .. self:Nick() .. " building elastic structure...")

    if self.SwitchTool then self:SwitchTool("elastic") end

    -- Spawn 2 props
    local prop1 = self:SpawnProp(nil, nil, nil, true)
    if !IsValid(prop1) then return "spawn_failed" end

    CoroutineWait(self, 0.5)

    local prop2 = self:SpawnProp(nil, prop1:GetPos() + Vector(100, 0, 50), nil, true)
    if !IsValid(prop2) then return "spawn_failed" end

    CoroutineWait(self, 0.5)

    -- Connect with elastic
    self.exp_LookTowards_Pos = prop1:GetPos()
    self.exp_LookTowards_EndT = CurTime() + 0.5
    CoroutineWait(self, 0.5)

    self:UseTool(prop1)
    CoroutineWait(self, 0.3)

    self.exp_LookTowards_Pos = prop2:GetPos()
    self.exp_LookTowards_EndT = CurTime() + 0.5
    CoroutineWait(self, 0.5)

    self:UseTool(prop2)
    CoroutineWait(self, 0.5)

    print("[EXP] " .. self:Nick() .. " completed elastic structure!")
    return "ok"
end

--[[ Tool Selection Intelligence ]]--

function PLAYER:DecideToolToUse()
    -- Analyze nearby props and decide which tool is appropriate
    local nearbyProps = self:FindNearbyProps(500)

    if !nearbyProps or #nearbyProps == 0 then
        -- No props nearby, use weld for basic building
        return "weld"
    end

    if #nearbyProps == 1 then
        -- One prop, good for adding wheels or anchoring
        return math.random() > 0.5 and "wheel" or "axis"
    end

    if #nearbyProps >= 2 then
        -- Multiple props, connect them
        local tools = {"weld", "rope", "elastic", "axis"}
        return tools[math.random(#tools)]
    end

    return "weld" -- Default
end

function PLAYER:AnalyzeStructure()
    -- Look at nearby props and determine what could be built
    local props = self:FindNearbyProps(800)

    if !props or #props == 0 then
        return "build_new" -- No props, build from scratch
    end

    -- Check if props are already connected
    local hasConstraints = false
    for _, prop in ipairs(props) do
        if IsValid(prop) and #constraint.GetTable(prop) > 0 then
            hasConstraints = true
            break
        end
    end

    if hasConstraints then
        return "modify_existing" -- Add to existing structure
    else
        return "connect_existing" -- Connect loose props
    end
end

--[[ AI State: Tool Using ]]--

function PLAYER:State_ToolUse()
    -- Random tool activity
    local activities = {
        function() return self:Behavior_UsePhysgun() end,
        function() return self:Behavior_BuildStructure() end,
        function() return self:Behavior_UseGravityGun() end,
        function() return self:Behavior_UseToolgun() end, -- NEW!
    }

    local activity = activities[math.random(#activities)]
    local result = activity()

    -- Return to idle
    self:SetState("Idle")
end

--[[ Decision Making ]]--

function PLAYER:ShouldUseTools()
    -- Don't use tools if in combat (unless personality allows)
    if self.exp_State == "Combat" then
        if self.GetPersonalityData then
            local personality = self:GetPersonalityData()
            -- Only joker personality multitasks tools + combat
            if personality and personality.name == "Joker" then
                return math.random() < 0.1  -- 10% chance
            end
        end
        return false
    end

    -- Don't use tools if pursuing objectives
    if self.exp_State == "Objective" then return false end

    -- Don't use tools if on admin duty
    if self.exp_State == "AdminDuty" then return false end

    -- Check if building is enabled
    if !EXP:GetConVar("building_enabled") then return false end

    -- Check if we have tool weapons
    local hasPhysgun = EXP:WeaponExists("physgun")
    local hasGravgun = EXP:WeaponExists("gravgun")
    local hasToolgun = EXP:WeaponExists("toolgun") and EXP:GetConVar("building_toolgun")

    if !hasPhysgun and !hasGravgun and !hasToolgun then return false end

    -- Personality-based tool usage chance
    local toolChance = 0.3  -- Default 30%

    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            if personality.name == "Joker" then
                toolChance = 0.6  -- Jokers love messing with props
            elseif personality.name == "Tactical" then
                toolChance = 0.4  -- Tactical builds strategically
            elseif personality.name == "Support" then
                toolChance = 0.5  -- Support builds defenses
            elseif personality.name == "Aggressive" then
                toolChance = 0.1  -- Aggressive doesn't build much
            elseif personality.name == "Silent" then
                toolChance = 0.2  -- Silent prefers observation
            end
        end
    end

    -- Higher chance if idle
    if self.exp_State == "Idle" then
        toolChance = toolChance * 1.5
    end

    -- Random roll
    if math.random() > toolChance then return false end

    return true
end

function PLAYER:Think_ToolUse()
    -- Initialize check time
    if !self.exp_NextToolCheckTime then
        self.exp_NextToolCheckTime = CurTime() + math.random(5, 15)
        return
    end

    -- Check cooldown
    if CurTime() < self.exp_NextToolCheckTime then return end

    -- Personality-based cooldown
    local cooldown = math.random(15, 30)  -- Default 15-30s

    if self.GetPersonalityData then
        local personality = self:GetPersonalityData()
        if personality then
            if personality.name == "Joker" then
                cooldown = math.random(5, 10)  -- Very frequent
            elseif personality.name == "Tactical" or personality.name == "Support" then
                cooldown = math.random(10, 20)  -- Moderate
            elseif personality.name == "Aggressive" then
                cooldown = math.random(30, 60)  -- Rare
            end
        end
    end

    self.exp_NextToolCheckTime = CurTime() + cooldown

    -- Decide if we should use tools
    if self:ShouldUseTools() then
        self:SetState("ToolUse")
    end
end

print("[Experimental Players] Tool behaviors loaded")
