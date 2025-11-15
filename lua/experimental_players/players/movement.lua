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

        coroutine_yield()
    end

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

    -- Get current path segment
    local curSegment = path:GetCurrentGoal()
    if !curSegment then
        -- Reached end of path
        self.exp_IsMoving = false
        self.Navigator:InvalidatePath()
        return
    end

    local goalPos = curSegment.pos
    local myPos = self:GetPos()

    -- Check if we reached this segment
    local dist = myPos:Distance( goalPos )
    if dist <= self.exp_GoalTolerance then
        path:Advance()
        return
    end

    -- Move towards goal
    self:MoveTowards( goalPos )

    -- Handle jumping
    if curSegment.type == PATH_JUMP_OVER_GAP then
        self:Jump()
    end

    -- Handle crouching
    local needsCrouch = curSegment.type == PATH_CLIMB_UP or dist < 100
    self:SetCrouch( needsCrouch )
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

function PLAYER:SetButtonDown( key )
    self.exp_InputButtons = bit.bor( self.exp_InputButtons or 0, key )
end

function PLAYER:SetButtonUp( key )
    self.exp_InputButtons = bit.band( self.exp_InputButtons or 0, bit.bnot( key ) )
end

function PLAYER:ClearButtons()
    self.exp_InputButtons = 0
    self.exp_InputForwardMove = 0
    self.exp_InputSideMove = 0
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
