-- Experimental Players - Movement System
-- Based on GLambda Players movement
-- Uses input keys to move PlayerBots

if ( CLIENT ) then return end

local coroutine_yield = coroutine.yield
local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local math_max = math.max
local math_min = math.min
local math_Clamp = math.Clamp
local util_TraceLine = util.TraceLine

local PLAYER = EXP.Player

--[[ Movement State ]]--

function PLAYER:InitializeMovement()
    self.exp_IsMoving = false
    self.exp_MoveSprint = false
    self.exp_MoveCrouch = false
    self.exp_AbortMovement = false
    self.exp_GoalTolerance = 30
    self.exp_StuckPosition = self:GetPos()
    self.exp_StuckTimer = CurTime() + 3
    self.exp_IsStuck = false

    -- Input control variables for StartCommand hook
    self.exp_InputButtons = 0
    self.exp_InputAngles = self:EyeAngles()
    self.exp_InputForwardMove = 0
    self.exp_InputSideMove = 0

    -- Ladder climbing
    self:InitializeLadderClimbing()

    -- Swimming
    self:InitializeSwimming()
end

--[[ Main Movement Function ]]--

function PLAYER:MoveToPos( pos, options )
    options = options or {}
    self:SetGoalTolerance( options.tolerance or 30 )

    -- If currently underwater, use swimming instead
    if self:IsInWater() then
        local result = self:SwimToPos(pos, options.maxage or 15)
        return result and "ok" or "failed"
    end

    -- Compute path using navigator
    if !IsValid( self.Navigator ) then
        -- Try to recreate navigator
        print("[EXP] WARNING: Navigator invalid for " .. self:Nick() .. ", attempting to recreate...")
        local navigator = ents.Create( "exp_navigator" )
        if IsValid( navigator ) then
            navigator:Spawn()
            navigator:SetOwner( self )
            self.Navigator = navigator
        else
            return "no_navigator"
        end
    end

    local success = self.Navigator:ComputePath( pos, options )
    if !success then
        return "failed"
    end

    self.exp_IsMoving = true
    self.exp_MovementGoal = pos

    -- Reset stuck detection for this movement
    self.exp_StuckPosition = self:GetPos()
    self.exp_StuckTimer = CurTime() + 3
    self.exp_UnstuckAttempts = 0  -- Reset unstuck attempts

    -- Determine if we should sprint
    local dist = self:GetPos():Distance( pos )
    local shouldSprint = options.sprint
    if shouldSprint == nil then
        shouldSprint = dist > 1000
    end
    self:SetSprint( shouldSprint )

    local pathResult = "ok"
    local timeout = options.maxage or 15
    local startTime = CurTime()

    -- Movement loop
    while IsValid( self.Navigator ) and self.Navigator:IsPathValid() do
        -- Check abort conditions
        if !self:Alive() then
            pathResult = "dead"
            break
        end

        if self.exp_AbortMovement then
            self.exp_AbortMovement = false
            pathResult = "abort"
            break
        end

        if CurTime() - startTime > timeout then
            pathResult = "timeout"
            break
        end

        -- Check if stuck
        if self:IsStuck() then
            -- FIX: Wait for unstuck action to complete before checking again
            if self.exp_UnstuckActionEndTime and CurTime() < self.exp_UnstuckActionEndTime then
                -- Still executing unstuck action, wait
                coroutine_yield()
                -- Continue to next iteration
            else
                -- Unstuck action complete or not started, cleanup
                if self.exp_UnstuckActionEndTime then
                    -- Action completed, clear it
                    self.exp_MoveCrouch = false
                    self.exp_InputForwardMove = 0
                    self.exp_UnstuckActionEndTime = nil
                end

                -- Try to unstuck with more aggressive recovery
                if self:AttemptUnstuck() then
                    -- Successfully started unstuck action, continue
                    self:ClearStuck()
                else
                    -- Can't unstuck, abort movement
                    pathResult = "stuck"
                    break
                end
            end
        end

        -- Update movement
        self:UpdateOnPath()

        -- FIX: Don't check path validity after UpdateOnPath
        -- UpdateOnPath invalidates the path when reaching destination
        -- The loop will naturally exit when path is invalid

        coroutine_yield()
    end

    self.exp_IsMoving = false
    self.exp_MoveSprint = false
    self.exp_FollowPath_Pos = nil  -- Clear path following
    return pathResult
end

--[[ Path Following ]]--

function PLAYER:UpdateOnPath()
    if !IsValid( self.Navigator ) or !self.Navigator:IsPathValid() then
        self:StopMoving()
        return
    end

    local path = self.Navigator:GetPath()
    if !path then
        self:StopMoving()
        return
    end

    -- Get all segments and current segment index
    local curSegIndex = self.Navigator:GetCurrentSegment()
    local allSegs = path:GetAllSegments()
    local segment = allSegs[ curSegIndex ]

    if !segment then
        -- Reached end of path
        self.exp_IsMoving = false
        self.Navigator:InvalidatePath()
        return
    end

    local goalPos = segment.pos
    local myPos = self:GetPos()

    -- Check if we reached this segment (use XY distance only)
    local xypos = goalPos * 1
    xypos.z = 0
    local selfpos = myPos * 1
    selfpos.z = 0

    local dist = selfpos:Distance( xypos )
    local tolerance = self.exp_GoalTolerance

    -- FIX: Don't double tolerance for final segment
    -- This causes bots to stop too far from objectives
    -- Use same tolerance throughout for consistency

    if dist <= tolerance then
        -- Reached segment, go to next one
        if curSegIndex == #allSegs then
            -- Reached final destination!
            self.exp_IsMoving = false
            self.Navigator:InvalidatePath()
            self.exp_FollowPath_Pos = nil
            return
        end

        -- Advance to next segment
        self.Navigator:IncrementSegment()
        local nextSegIndex = self.Navigator:GetCurrentSegment()

        -- Bounds check after increment
        if nextSegIndex > #allSegs then
            -- Somehow went past the end, stop here
            self.exp_IsMoving = false
            self.Navigator:InvalidatePath()
            self.exp_FollowPath_Pos = nil
            return
        end

        segment = allSegs[ nextSegIndex ]
        if !segment then
            -- Segment doesn't exist, stop
            self.exp_IsMoving = false
            self.Navigator:InvalidatePath()
            self.exp_FollowPath_Pos = nil
            return
        end

        goalPos = segment.pos
    end

    -- Set target position for SetupMove hook (GLambda method!)
    self.exp_FollowPath_Pos = goalPos
    self.exp_FollowPath_EndT = CurTime() + 0.5

    -- Look towards goal
    self.exp_LookTowards_Pos = goalPos + Vector( 0, 0, 70 )
    self.exp_LookTowards_EndT = CurTime() + 0.2

    -- Handle jumping
    if segment.type == PATH_JUMP_OVER_GAP then
        self:PressKey( IN_JUMP )
    end

    -- Handle crouching
    if segment.type == PATH_CLIMB_UP then
        self.exp_MoveCrouch = true
    else
        self.exp_MoveCrouch = false
    end

    -- Handle ladders
    self:CheckForLadder()

    -- Handle swimming
    self:UpdateSwimming()
end

--[[ Input-based Movement ]]--

function PLAYER:MoveTowards( pos )
    -- FIX: Add timeout protection to prevent infinite loops
    -- Initialize MoveTowards timer if not set
    if !self.exp_MoveTowardsStartTime then
        self.exp_MoveTowardsStartTime = CurTime()
    end

    -- Check if stuck in MoveTowards for too long (5 seconds)
    if CurTime() - self.exp_MoveTowardsStartTime > 5 then
        -- Clear and reset
        self.exp_MoveTowardsStartTime = nil
        self:StopMoving()
        return false
    end

    local myPos = self:GetPos()
    local myAng = self:EyeAngles()

    -- Calculate direction to target
    local dir = ( pos - myPos ):GetNormalized()
    local targetAng = dir:Angle()

    -- Smooth angle transition
    local newAng = LerpAngle( 0.1, myAng, targetAng )
    self:SetEyeAngles( newAng )
    self.exp_InputAngles = newAng

    -- Calculate movement input based on view direction
    local forward = dir:Dot( newAng:Forward() )
    local right = dir:Dot( newAng:Right() )

    -- Set movement values (simpler and more direct than buttons)
    local maxSpeed = 10000  -- GMod's max movement speed

    -- Forward/back movement
    if forward > 0.1 then
        self.exp_InputForwardMove = maxSpeed * forward
    elseif forward < -0.1 then
        self.exp_InputForwardMove = maxSpeed * forward
    else
        self.exp_InputForwardMove = 0
    end

    -- Left/right movement
    if right > 0.1 then
        self.exp_InputSideMove = maxSpeed * right
    elseif right < -0.1 then
        self.exp_InputSideMove = maxSpeed * right
    else
        self.exp_InputSideMove = 0
    end

    -- Sprint and Crouch are now handled in SetupMove hook
    return true
end

function PLAYER:StopMoving()
    -- Clear all movement
    self:ClearButtons()
    self.exp_IsMoving = false
    self.exp_InputForwardMove = 0
    self.exp_InputSideMove = 0
    self.exp_MoveTowardsStartTime = nil  -- FIX: Clear MoveTowards timer
end

function PLAYER:PressKey( key )
    self.exp_InputButtons = bit.bor( self.exp_InputButtons or 0, key )
end

function PLAYER:HoldKey( key )
    self.exp_InputButtons = bit.bor( self.exp_InputButtons or 0, key )
end

function PLAYER:SetButtonDown( key )
    self:PressKey( key )
end

function PLAYER:SetButtonUp( key )
    self.exp_InputButtons = bit.band( self.exp_InputButtons or 0, bit.bnot( key ) )
end

function PLAYER:ClearButtons()
    self.exp_InputButtons = 0
    self.exp_FollowPath_Pos = nil
    self.exp_LookTowards_Pos = nil
end

--[[ Locomotion ]]--

function PLAYER:Jump()
    if self:IsOnGround() then
        self:SetButtonDown( IN_JUMP )
        timer.Simple( 0.1, function()
            if IsValid( self ) then
                self:SetButtonUp( IN_JUMP )
            end
        end )
    end
end

function PLAYER:SetSprint( bool )
    self.exp_MoveSprint = bool
end

function PLAYER:SetCrouch( bool )
    self.exp_MoveCrouch = bool
end

function PLAYER:IsSprinting()
    return self.exp_MoveSprint or false
end

--[[ Stuck Detection ]]--

function PLAYER:IsStuck()
    if !self.exp_StuckPosition or !self.exp_StuckTimer then
        return false
    end

    if CurTime() < self.exp_StuckTimer then
        return false
    end

    local dist = self:GetPos():Distance( self.exp_StuckPosition )
    if dist < 10 then
        self.exp_IsStuck = true
        return true
    end

    return false
end

function PLAYER:ClearStuck()
    self.exp_StuckPosition = self:GetPos()
    self.exp_StuckTimer = CurTime() + 3
    self.exp_IsStuck = false
end

function PLAYER:AttemptUnstuck()
    -- Track unstuck attempts
    self.exp_UnstuckAttempts = (self.exp_UnstuckAttempts or 0) + 1

    -- Give up after 3 attempts
    if self.exp_UnstuckAttempts > 3 then
        self.exp_UnstuckAttempts = 0
        return false
    end

    -- FIX: Use time-based system instead of async timer
    -- Try different unstuck methods
    local method = self.exp_UnstuckAttempts

    if method == 1 then
        -- Method 1: Jump
        self:Jump()
        self.exp_UnstuckActionEndTime = CurTime() + 0.2  -- Short delay for jump
    elseif method == 2 then
        -- Method 2: Crouch and move backward (synchronous)
        self.exp_MoveCrouch = true
        self.exp_InputForwardMove = -10000
        self.exp_UnstuckActionEndTime = CurTime() + 0.5  -- 0.5 seconds of backing up
    elseif method == 3 then
        -- Method 3: Recompute path
        if IsValid(self.Navigator) then
            self.Navigator:RecomputePath()
        end
        self.exp_UnstuckActionEndTime = CurTime() + 0.1  -- Minimal delay
    end

    return true  -- Continue trying
end

--[[ Utility ]]--

function PLAYER:SetGoalTolerance( dist )
    self.exp_GoalTolerance = dist or 30
end

function PLAYER:GetGoalTolerance()
    return self.exp_GoalTolerance or 30
end

function PLAYER:CancelMovement()
    self.exp_AbortMovement = true
end

function PLAYER:IsMoving()
    return self.exp_IsMoving or false
end

function PLAYER:GetMoveGoal()
    return self.exp_MovementGoal
end

--[[ Ladder Climbing System ]]--

function PLAYER:CheckForLadder()
    -- Check if we're near a ladder
    local ladder = self:FindNearbyLadder()

    if IsValid(ladder) then
        -- Check if we need to climb up or down
        local myPos = self:GetPos()
        local ladderBottom = ladder:GetPos()
        local ladderTop = ladder:GetPos() + Vector(0, 0, ladder:BoundingRadius() * 2)

        -- If we're climbing a ladder, use the ladder climbing logic
        if self:IsOnLadder() or self:ShouldMountLadder(ladder) then
            self:ClimbLadder(ladder)
        end
    end
end

function PLAYER:FindNearbyLadder()
    -- Search for ladders in a 150 unit radius
    local nearbyEnts = ents.FindInSphere(self:GetPos(), 150)

    for _, ent in ipairs(nearbyEnts) do
        if ent:GetClass() == "func_useableladder" then
            -- Check if ladder is in front of us
            local toLadder = (ent:GetPos() - self:GetPos()):GetNormalized()
            local forward = self:GetForward()

            if toLadder:Dot(forward) > 0.5 then  -- 60 degree cone
                return ent
            end
        end
    end

    return nil
end

function PLAYER:IsOnLadder()
    -- Check if player is currently on a ladder (GMod provides this)
    return self:GetMoveType() == MOVETYPE_LADDER
end

function PLAYER:ShouldMountLadder(ladder)
    if !IsValid(ladder) then return false end

    -- Check if we're close enough to mount
    local dist = self:GetPos():Distance(ladder:GetPos())
    if dist > 60 then return false end

    -- Check if our goal is above or below us (need vertical movement)
    if !self.exp_MovementGoal then return false end

    local verticalDiff = self.exp_MovementGoal.z - self:GetPos().z

    -- Need at least 100 units vertical difference to use ladder
    if math.abs(verticalDiff) > 100 then
        return true
    end

    return false
end

function PLAYER:ClimbLadder(ladder)
    if !IsValid(ladder) then return end

    -- Get ladder properties
    local ladderPos = ladder:GetPos()
    local ladderNormal = ladder:GetForward()

    -- Align with ladder
    local toLadder = (ladderPos - self:GetPos()):GetNormalized()
    local alignAngle = toLadder:Angle()
    self:SetEyeAngles(Angle(0, alignAngle.y, 0))
    self.exp_InputAngles = Angle(0, alignAngle.y, 0)

    -- Determine climb direction
    if !self.exp_MovementGoal then return end

    local verticalDiff = self.exp_MovementGoal.z - self:GetPos().z

    if verticalDiff > 50 then
        -- Climb UP
        self:ClimbUp()
    elseif verticalDiff < -50 then
        -- Climb DOWN
        self:ClimbDown()
    else
        -- At correct height, dismount
        self:DismountLadder()
    end
end

function PLAYER:ClimbUp()
    -- Move forward on ladder (climbs up)
    self.exp_InputForwardMove = 10000
    self.exp_InputSideMove = 0

    -- Look slightly up to help with climbing
    local currentAng = self:EyeAngles()
    self:SetEyeAngles(Angle(math.Clamp(currentAng.p + 5, -89, 89), currentAng.y, 0))
end

function PLAYER:ClimbDown()
    -- Move backward on ladder (climbs down)
    self.exp_InputForwardMove = -10000
    self.exp_InputSideMove = 0

    -- Look slightly down
    local currentAng = self:EyeAngles()
    self:SetEyeAngles(Angle(math.Clamp(currentAng.p - 5, -89, 89), currentAng.y, 0))
end

function PLAYER:DismountLadder()
    -- Move forward to get off ladder
    self.exp_InputForwardMove = 10000
    self.exp_InputSideMove = 0

    -- Small delay before resuming normal movement
    self.exp_LadderDismountTime = CurTime() + 0.5
end

function PLAYER:InitializeLadderClimbing()
    self.exp_OnLadder = false
    self.exp_LadderEntity = nil
    self.exp_LadderDismountTime = 0
end

--[[ Swimming System ]]--

function PLAYER:InitializeSwimming()
    self.exp_IsSwimming = false
    self.exp_SwimTarget = nil
    self.exp_SwimSurfaceTime = 0
    self.exp_LastAirTime = CurTime()
end

-- Check if bot is in water
function PLAYER:IsInWater()
    return self:WaterLevel() >= 2
end

-- Check if bot needs air
function PLAYER:NeedsAir()
    if !self:IsInWater() then
        self.exp_LastAirTime = CurTime()
        return false
    end

    -- Check breath meter (players drown after ~10 seconds underwater)
    local underwaterTime = CurTime() - self.exp_LastAirTime
    return underwaterTime > 8  -- Surface before drowning
end

-- Swim towards position
function PLAYER:SwimTowards(pos)
    if !self:IsInWater() then return end

    local myPos = self:GetPos()
    local dir = (pos - myPos):GetNormalized()
    local targetAng = dir:Angle()

    -- Smooth angle transition
    local currentAng = self:EyeAngles()
    local newAng = LerpAngle(0.15, currentAng, targetAng)
    self:SetEyeAngles(newAng)

    -- Swimming uses forward movement
    self.exp_InputForwardMove = 10000
    self.exp_InputSideMove = 0

    -- Jump button swims upward
    if dir.z > 0.3 then
        self:SetButtonDown(IN_JUMP)
    else
        self:SetButtonUp(IN_JUMP)
    end

    -- Duck button swims downward
    if dir.z < -0.3 then
        self:SetButtonDown(IN_DUCK)
    else
        self:SetButtonUp(IN_DUCK)
    end
end

-- Surface for air
function PLAYER:SwimToSurface()
    if !self:IsInWater() then return end

    -- Find water surface
    local myPos = self:GetPos()
    local trace = util_TraceLine({
        start = myPos,
        endpos = myPos + Vector(0, 0, 10000),
        filter = self,
        mask = MASK_WATER
    })

    if trace.Hit then
        local surfacePos = trace.HitPos - Vector(0, 0, 20)  -- Just below surface
        self:SwimTowards(surfacePos)
        return true
    end

    -- If trace failed, just swim upward
    local upPos = myPos + Vector(0, 0, 500)
    self:SwimTowards(upPos)
    return false
end

-- Handle underwater navigation
function PLAYER:UpdateSwimming()
    if !self:IsInWater() then
        self.exp_IsSwimming = false
        return
    end

    self.exp_IsSwimming = true

    -- Check if we need air
    if self:NeedsAir() then
        self:SwimToSurface()
        return
    end

    -- If we have a swim target, swim towards it
    if self.exp_SwimTarget then
        local targetPos = self.exp_SwimTarget
        local dist = self:GetPos():Distance(targetPos)

        if dist < 50 then
            -- Reached target
            self.exp_SwimTarget = nil
        else
            self:SwimTowards(targetPos)
        end
    end
end

-- Navigate through water to destination
function PLAYER:SwimToPos(pos, timeout)
    if !self:IsInWater() then return false end

    self.exp_SwimTarget = pos
    local startTime = CurTime()
    timeout = timeout or 15

    while IsValid(self) and self:IsInWater() do
        self:UpdateSwimming()

        -- Check if reached
        if !self.exp_SwimTarget then
            return true  -- Success
        end

        -- Check timeout
        if CurTime() - startTime > timeout then
            self.exp_SwimTarget = nil
            return false  -- Timeout
        end

        -- Check if need air (priority override)
        if self:NeedsAir() then
            return false  -- Must surface
        end

        coroutine_yield()
    end

    self.exp_SwimTarget = nil
    return false
end

-- Check if path requires swimming
function PLAYER:PathRequiresSwimming(targetPos)
    -- Trace from current position to target
    local myPos = self:GetPos() + Vector(0, 0, 32)
    local trace = util_TraceLine({
        start = myPos,
        endpos = targetPos + Vector(0, 0, 32),
        filter = self,
        mask = MASK_WATER
    })

    -- If trace hits water, swimming required
    return trace.StartSolid or trace.HitTexture == "**water**" or trace.MatType == MAT_SLOSH
end

print( "[Experimental Players] Movement system loaded" )
