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
end

--[[ Main Movement Function ]]--

function PLAYER:MoveToPos( pos, options )
    options = options or {}
    self:SetGoalTolerance( options.tolerance or 30 )

    -- Compute path using navigator
    if !IsValid( self.Navigator ) then
        return "no_navigator"
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
            self:ClearStuck()
            pathResult = "stuck"
            break
        end

        -- Update movement
        self:UpdateOnPath()

        -- DEBUG: Check if path is still valid after UpdateOnPath
        if !self.Navigator:IsPathValid() then
            print("[EXP] Path became invalid after UpdateOnPath!")
            pathResult = "path_invalid"
            break
        end

        coroutine_yield()
    end

    print("[EXP] MoveToPos exited with result:", pathResult)
    self.exp_IsMoving = false
    self.exp_MoveSprint = false
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
    if dist <= self.exp_GoalTolerance then
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
        segment = allSegs[ self.Navigator:GetCurrentSegment() ]
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
end

--[[ Input-based Movement ]]--

function PLAYER:MoveTowards( pos )
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

    -- Sprint
    if self.exp_MoveSprint then
        self:SetButtonDown( IN_SPEED )
    end

    -- Crouch
    if self.exp_MoveCrouch then
        self:SetButtonDown( IN_DUCK )
    end
end

function PLAYER:StopMoving()
    -- Clear all movement
    self:ClearButtons()
    self.exp_IsMoving = false
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
    return self.exp_MoveSprint or self:IsSprinting()
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

    -- Try to unstuck
    if self.exp_IsStuck then
        self:Jump()
    end
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

print( "[Experimental Players] Movement system loaded" )
