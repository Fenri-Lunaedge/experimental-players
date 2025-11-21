-- Experimental Players - Prop Interaction System
-- Physgun, picking up, manipulating props
-- Based on Lambda Players prop system

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local util = util
local math = math
local ents = ents

local PLAYER = EXP.Player

--[[ Helper Functions ]]--

-- Smooth angle approach
local function ApproachAngle(current, target, rate)
    rate = rate or 5
    local p = math.ApproachAngle(current.p, target.p, rate)
    local y = math.ApproachAngle(current.y, target.y, rate)
    local r = math.ApproachAngle(current.r, target.r, rate)
    return Angle(p, y, r)
end

--[[ Prop Permissions ]]--

-- Classes to ignore for physgun
local ignoreClasses = {
    ["func_door"] = true,
    ["func_door_rotating"] = true,
    ["prop_door_rotating"] = true,
    ["prop_dynamic"] = true,
    ["func_button"] = true,
    ["player"] = true,
}

function PLAYER:CanPickupWithPhysgun(ent)
    if !IsValid(ent) then return false end
    if ent == self then return false end

    -- Check class
    if ignoreClasses[ent:GetClass()] then return false end

    -- Must have physics
    local phys = ent:GetPhysicsObject()
    if !IsValid(phys) then return false end

    -- Check if it's owned by someone else (respect building permissions)
    if ent.exp_Owner and ent.exp_Owner  ~=  self then
        if EXP:GetConVar("building_caneditothers")  ~=  1 then
            return false
        end
    end

    -- Check if it's a map entity
    if ent:CreatedByMap() then
        if EXP:GetConVar("building_caneditworld")  ~=  1 then
            return false
        end
    end

    return true
end

--[[ Physgun Functions ]]--

function PLAYER:PhysgunPickup(ent, hitpos)
    if !IsValid(ent) then return end

    -- Store grabbed entity
    self.exp_PhysgunGrabbedEnt = ent

    -- Calculate distance
    local dist = self:GetPos():Distance(ent:GetPos())
    self.exp_PhysgunDistance = math.Clamp(dist, 100, 1000)

    -- Store local hit position for better holding
    self.exp_PhysgunLocalPos = ent:WorldToLocal(hitpos)

    -- Random hold angle for variation
    self.exp_PhysgunHoldAng = nil  -- Will rotate freely unless set

    -- Enable physics
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end

    print("[EXP] " .. self:Nick() .. " picked up " .. ent:GetClass())
end

function PLAYER:PhysgunDrop()
    if !IsValid(self.exp_PhysgunGrabbedEnt) then return end

    print("[EXP] " .. self:Nick() .. " dropped " .. self.exp_PhysgunGrabbedEnt:GetClass())

    -- Clear references
    local ent = self.exp_PhysgunGrabbedEnt
    self.exp_PhysgunGrabbedEnt = nil
    self.exp_PhysgunHoldPos = nil
    self.exp_PhysgunHoldAng = nil
    self.exp_PhysgunLocalPos = nil

    -- Keep physics enabled
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
    end
end

function PLAYER:PhysgunFreeze()
    if !IsValid(self.exp_PhysgunGrabbedEnt) then return end

    local ent = self.exp_PhysgunGrabbedEnt
    local phys = ent:GetPhysicsObject()

    if IsValid(phys) then
        -- Toggle freeze
        phys:EnableMotion(!phys:IsMotionEnabled())

        if !phys:IsMotionEnabled() then
            print("[EXP] " .. self:Nick() .. " froze " .. ent:GetClass())
        else
            print("[EXP] " .. self:Nick() .. " unfroze " .. ent:GetClass())
        end
    end

    -- Drop after freezing
    self:PhysgunDrop()
end

function PLAYER:PhysgunUpdateHold(wepent)
    local ent = self.exp_PhysgunGrabbedEnt
    if !IsValid(ent) then
        self.exp_PhysgunGrabbedEnt = nil
        return
    end

    local phys = ent:GetPhysicsObject()
    if !IsValid(phys) then
        self:PhysgunDrop()
        return
    end

    -- Calculate hold position (in front of weapon)
    local holdDistance = self.exp_PhysgunDistance or 200
    local wepPos = IsValid(wepent) and wepent:GetPos() or self:GetShootPos()
    local wepAng = IsValid(wepent) and wepent:GetAngles() or self:EyeAngles()

    local targetPos = wepPos + wepAng:Forward() * holdDistance

    -- Use custom hold position if set
    if self.exp_PhysgunHoldPos then
        targetPos = self.exp_PhysgunHoldPos
    end

    -- Handle different entity types
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then
        -- For living entities, use TraceEntity for smooth movement
        local traceData = {
            start = ent:GetPos(),
            endpos = targetPos,
            filter = {self, ent},
            mask = MASK_SOLID
        }
        local result = util.TraceEntity(traceData, ent)
        ent:SetPos(result.HitPos)
    else
        -- For physics objects, use velocity-based movement (smoother)
        phys:EnableMotion(true)
        phys:Wake()

        local currentPos = ent:GetPos()
        local dist = targetPos - currentPos
        local dir = dist:GetNormalized()

        -- Calculate smooth velocity
        local speed = math.min(5000 / 2, dist:Dot(dir) * 5)
        local currentVel = ent:GetVelocity()
        local targetVel = (speed * dir + currentVel * 0.5)

        -- Clamp speed
        speed = math.max(math.min(5000, targetVel:Dot(dir)), -1000)

        phys:SetVelocity(speed * dir)

        -- Handle rotation
        if self.exp_PhysgunHoldAng then
            local currentAng = ent:GetAngles()
            local newAng = ApproachAngle(currentAng, self.exp_PhysgunHoldAng, 5)
            phys:SetAngles(newAng)
        end
    end
end

function PLAYER:PhysgunAdjustDistance(delta)
    if !IsValid(self.exp_PhysgunGrabbedEnt) then return end

    self.exp_PhysgunDistance = math.Clamp(
        (self.exp_PhysgunDistance or 200) + delta,
        50,
        1500
    )
end

function PLAYER:PhysgunSetRotation(ang)
    if !IsValid(self.exp_PhysgunGrabbedEnt) then return end
    self.exp_PhysgunHoldAng = ang
end

--[[ Prop Finding ]]--

function PLAYER:FindNearbyProps(radius, filter)
    radius = radius or 1500

    local props = {}
    local nearbyEnts = ents.FindInSphere(self:GetPos(), radius)

    for _, ent in ipairs(nearbyEnts) do
        if ent == self then continue end
        if !self:CanPickupWithPhysgun(ent) then continue end
        if !self:CanSeeEntity(ent) then continue end

        -- Custom filter
        if filter and !filter(ent) then continue end

        table.insert(props, ent)
    end

    return props
end

function PLAYER:FindRandomProp(radius)
    local props = self:FindNearbyProps(radius)
    if #props == 0 then return nil end

    return props[math.random(#props)]
end

function PLAYER:FindClosestProp(radius)
    local props = self:FindNearbyProps(radius)
    if #props == 0 then return nil end

    local closest = nil
    local closestDist = math.huge

    for _, prop in ipairs(props) do
        local dist = self:GetPos():Distance(prop:GetPos())
        if dist < closestDist then
            closestDist = dist
            closest = prop
        end
    end

    return closest
end

--[[ Light Prop Pickup (manual carry) ]]--

function PLAYER:PickupLightProp(ent)
    if !IsValid(ent) then return false end

    local phys = ent:GetPhysicsObject()
    if !IsValid(phys) then return false end

    -- Only pick up light props (< 35kg)
    if phys:GetMass() >= 35 then return false end

    self.exp_CarriedProp = ent

    -- Start carry think
    self:CreateThinkFunction("CarryProp", 0, 0, function()
        if !IsValid(self.exp_CarriedProp) then
            self:RemoveThinkFunction("CarryProp")
            return
        end

        local prop = self.exp_CarriedProp
        local propPhys = prop:GetPhysicsObject()

        if !IsValid(propPhys) then
            self.exp_CarriedProp = nil
            self:RemoveThinkFunction("CarryProp")
            return
        end

        propPhys:EnableMotion(true)

        -- Position in front of player (like carrying)
        local eyePos = self:EyePos()
        local eyeAng = self:EyeAngles()
        local targetPos = eyePos + eyeAng:Forward() * 60 + Vector(0, 0, -20)

        local dist = targetPos - prop:GetPos()
        local dir = dist:GetNormalized()
        local speed = math.min(10000 / 2, dist:Dot(dir) * 5)
        local vel = (speed * dir + prop:GetVelocity() * 0.5)

        speed = math.max(math.min(10000, vel:Dot(dir)), -1000)
        propPhys:SetVelocity(speed * dir)
    end)

    print("[EXP] " .. self:Nick() .. " is carrying " .. ent:GetClass())
    return true
end

function PLAYER:DropLightProp()
    if !IsValid(self.exp_CarriedProp) then return end

    print("[EXP] " .. self:Nick() .. " dropped carried prop")

    self.exp_CarriedProp = nil
    self:RemoveThinkFunction("CarryProp")
end

function PLAYER:ThrowLightProp()
    if !IsValid(self.exp_CarriedProp) then return end

    local prop = self.exp_CarriedProp
    local phys = prop:GetPhysicsObject()

    if IsValid(phys) then
        -- FIX: Reduced max throw force to reasonable values
        -- Scale by mass - lighter props go further
        local mass = phys:GetMass()
        local baseForce = math.random(5000, 15000)  -- Max 15k instead of 50k
        local force = baseForce * math.max(1, 35 / mass)  -- Scale inversely with mass
        phys:ApplyForceCenter(self:GetAimVector() * force)
    end

    self:DropLightProp()
end

--[[ Think Function Helper ]]--

function PLAYER:CreateThinkFunction(name, delay, reps, func)
    -- Simple think function system
    local thinkName = "exp_think_" .. name .. "_" .. self:EntIndex()

    timer.Create(thinkName, delay, reps, function()
        -- FIX: Check IsValid before each execution, not just once
        if !IsValid(self) or !self:Alive() then
            timer.Remove(thinkName)
            return
        end

        -- Wrapped function call with error protection
        local success, err = pcall(func)
        if !success then
            print("[EXP] Think function '" .. name .. "' error: " .. tostring(err))
            timer.Remove(thinkName)
        end
    end)
end

function PLAYER:RemoveThinkFunction(name)
    local thinkName = "exp_think_" .. name .. "_" .. self:EntIndex()
    timer.Remove(thinkName)
end

print("[Experimental Players] Prop interaction system loaded")
