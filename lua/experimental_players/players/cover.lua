-- Experimental Players - Cover System
-- Tactical cover detection and usage for combat
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local math = math
local util = util
local ents = ents

local PLAYER = EXP.Player

--[[ Cover Detection ]]--

function PLAYER:FindNearbyCovers(radius, fromPos)
    radius = radius or 800
    fromPos = fromPos or self:GetPos()

    -- FIX: Cache cover search to avoid expensive FindInSphere every frame
    local now = CurTime()
    if self.exp_CoverCacheTime and (now - self.exp_CoverCacheTime) < 2 then
        return self.exp_CoverCache or {}
    end

    local covers = {}
    local searchPos = fromPos

    -- Find potential cover objects (props, walls, etc.)
    local nearbyEnts = ents.FindInSphere(searchPos, radius)

    for _, ent in ipairs(nearbyEnts) do
        if ent == self then continue end
        if !IsValid(ent) then continue end

        -- Check if entity can provide cover
        if self:CanProvideCover(ent) then
            local coverData = self:EvaluateCover(ent, fromPos)
            -- FIX: Only insert if coverData is valid (not nil)
            if coverData and coverData.position then
                table.insert(covers, coverData)
            end
        end
    end

    -- Sort by quality (best first)
    table.sort(covers, function(a, b)
        return a.quality > b.quality
    end)

    -- Cache results
    self.exp_CoverCache = covers
    self.exp_CoverCacheTime = now

    return covers
end

function PLAYER:CanProvideCover(ent)
    if !IsValid(ent) then return false end

    local class = ent:GetClass()

    -- Props can provide cover
    if string.StartWith(class, "prop_physics") or string.StartWith(class, "prop_dynamic") then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) and phys:GetMass() > 20 then
            return true
        end
    end

    -- Func brushes (walls, etc.)
    if string.StartWith(class, "func_") then
        return true
    end

    -- NPCs and players can be used as cover (risky!)
    if ent:IsNPC() or ent:IsPlayer() then
        return true
    end

    return false
end

function PLAYER:EvaluateCover(coverEnt, fromPos)
    if !IsValid(coverEnt) then return nil end

    fromPos = fromPos or self:GetPos()

    -- Get cover position
    local coverPos = coverEnt:GetPos()

    -- Calculate position behind cover (away from enemy)
    local enemy = self.exp_Enemy
    if !IsValid(enemy) then return nil end

    local enemyPos = enemy:GetPos()
    local toEnemy = (enemyPos - coverPos):GetNormalized()
    local behindCover = coverPos - toEnemy * 60  -- 60 units behind cover

    -- Trace to check if cover actually blocks line of sight to enemy
    local trace = util.TraceLine({
        start = behindCover + Vector(0, 0, 64),  -- Eye level
        endpos = enemyPos + Vector(0, 0, 64),
        filter = {self, coverEnt},
        mask = MASK_SHOT
    })

    -- If we can see enemy from behind cover, it's not good cover
    if !trace.Hit or trace.Entity == enemy then
        return nil
    end

    -- Calculate cover quality (0-100)
    local quality = 0

    -- Distance factor (closer = better)
    local dist = self:GetPos():Distance(behindCover)
    quality = quality + math.max(0, (800 - dist) / 800 * 40)

    -- Size factor (bigger = better)
    local mins, maxs = coverEnt:GetCollisionBounds()
    local size = (maxs - mins):Length()
    quality = quality + math.min(size / 10, 30)

    -- Height factor (tall cover = better)
    local height = maxs.z - mins.z
    quality = quality + math.min(height / 5, 20)

    -- Enemy distance factor (cover between us and enemy = better)
    local enemyDist = coverPos:Distance(enemyPos)
    local ourDist = coverPos:Distance(self:GetPos())
    if enemyDist > ourDist then
        quality = quality + 10  -- Bonus if cover is between us and enemy
    end

    return {
        entity = coverEnt,
        position = behindCover,
        quality = math.Clamp(quality, 0, 100),  -- Ensure quality is 0-100
        distance = dist,
        blocksEnemy = trace.Hit
    }
end

--[[ Cover Usage ]]--

function PLAYER:FindBestCover()
    if !IsValid(self.exp_Enemy) then return nil end

    local covers = self:FindNearbyCovers(800, self:GetPos())

    if #covers == 0 then return nil end

    -- Return best cover (already sorted by quality)
    return covers[1]
end

function PLAYER:MoveToCover(coverData, options)
    if !coverData or !coverData.position then return "no_cover" end

    options = options or {}
    options.sprint = true  -- Sprint to cover
    options.maxage = options.maxage or 5
    options.tolerance = options.tolerance or 40

    -- Move to cover position
    local result = self:MoveToPos(coverData.position, options)

    if result == "ok" then
        self.exp_InCover = true
        self.exp_CurrentCover = coverData
        self.exp_CoverTime = CurTime()
    end

    return result
end

function PLAYER:IsInCover()
    return self.exp_InCover or false
end

function PLAYER:GetCoverData()
    return self.exp_CurrentCover
end

function PLAYER:LeaveCover()
    self.exp_InCover = false
    self.exp_CurrentCover = nil
    self.exp_CoverTime = nil
end

function PLAYER:ShouldSeekCover()
    -- Don't seek cover if already in cover
    if self:IsInCover() then return false end

    -- Don't seek cover if not in combat
    if self.exp_State  ~=  "Combat" then return false end

    -- Don't seek cover if no enemy
    if !IsValid(self.exp_Enemy) then return false end

    -- Check personality-based cover usage
    if self.ShouldUseCoverWithPersonality then
        if !self:ShouldUseCoverWithPersonality() then
            return false  -- Personality says no cover
        end
    end

    -- Check health (low health = seek cover)
    local healthRatio = self:Health() / self:GetMaxHealth()
    if healthRatio < 0.5 then return true end

    -- Check if taking fire (recently damaged)
    if self.exp_LastDamageTime and CurTime() - self.exp_LastDamageTime < 2 then
        return true
    end

    -- Check threat level
    if self.AssessThreat then
        local threat = self:AssessThreat(self.exp_Enemy)
        if threat > 70 then return true end
    end

    -- Random chance (30%) to seek cover tactically
    if math.random(1, 100) <= 30 then return true end

    return false
end

--[[ Cover Combat Behavior ]]--

function PLAYER:CombatFromCover()
    if !self:IsInCover() then return end
    if !IsValid(self.exp_Enemy) then
        self:LeaveCover()
        return
    end

    local coverData = self:GetCoverData()
    if !coverData then
        self:LeaveCover()
        return
    end

    local enemy = self.exp_Enemy

    -- Stay in cover position
    local dist = self:GetPos():Distance(coverData.position)
    if dist > 50 then
        -- Moved away from cover, reposition
        self:MoveToPos(coverData.position, {tolerance = 30, maxage = 2})
        return
    end

    -- Peek and shoot
    if CurTime() > (self.exp_NextPeekTime or 0) then
        self:PeekFromCover(enemy)
    end

    -- Check if cover is still valid
    if !IsValid(coverData.entity) then
        self:LeaveCover()
        return
    end

    -- Leave cover if enemy is too close
    local enemyDist = self:GetPos():Distance(enemy:GetPos())
    if enemyDist < 200 then
        self:LeaveCover()
        return
    end

    -- Leave cover after 10-15 seconds (reposition)
    if self.exp_CoverTime and CurTime() - self.exp_CoverTime > math.random(10, 15) then
        self:LeaveCover()
        return
    end
end

function PLAYER:PeekFromCover(enemy)
    if !IsValid(enemy) then return end

    -- Look at enemy
    local aimPos = enemy:GetPos() + Vector(0, 0, 40)
    local aimDir = (aimPos - self:GetShootPos()):GetNormalized()
    self:SetEyeAngles(aimDir:Angle())

    -- Shoot if we can see them
    if self:CanSeeEntity(enemy) then
        self:Attack(enemy)
    end

    -- Next peek in 1-3 seconds
    self.exp_NextPeekTime = CurTime() + math.random(1, 3)
end

function PLAYER:InitializeCoverSystem()
    self.exp_InCover = false
    self.exp_CurrentCover = nil
    self.exp_CoverTime = nil
    self.exp_NextPeekTime = 0
    self.exp_LastDamageTime = nil
    self.exp_CoverCache = {}  -- FIX: Initialize cache
    self.exp_CoverCacheTime = 0
end

-- Hook into damage to track when bot is under fire
hook.Add("EntityTakeDamage", "EXP_TrackDamageForCover", function(target, dmg)
    if !IsValid(target) then return end
    if !target.exp_IsExperimentalPlayer then return end

    -- Track last damage time for cover seeking
    target.exp_LastDamageTime = CurTime()
end)

print("[Experimental Players] Cover system loaded")
