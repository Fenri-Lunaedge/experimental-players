-- Experimental Players - Objective AI
-- Handles game mode objectives (CTF, KOTH, etc.)
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local math_Rand = math.Rand
local util_TraceLine = util.TraceLine
local coroutine_yield = coroutine.yield

local PLAYER = EXP.Player

-- Coroutine wait helper
local function CoroutineWait(self, seconds)
    self.exp_CoroutineWaitUntil = CurTime() + seconds
    while CurTime() < self.exp_CoroutineWaitUntil do
        coroutine_yield()
    end
end

--[[ Objective Initialization ]]--

function PLAYER:InitializeObjective()
    self.exp_CurrentObjective = nil
    self.exp_ObjectiveType = nil
    self.exp_NextObjectiveCheck = 0
    self.exp_ObjectiveFailCount = 0
    self.exp_LastObjectiveTime = 0
end

--[[ Objective Selection ]]--

function PLAYER:ShouldPursueObjective()
    -- Check if in gamemode
    if !EXP.GameMode or !EXP.GameMode.Active then return false end

    -- Check cooldown
    if CurTime() < self.exp_NextObjectiveCheck then return false end

    -- Don't pursue objectives if in combat (unless aggressive personality)
    if self.exp_State == "Combat" then
        if self.GetPersonalityData then
            local personality = self:GetPersonalityData()
            if personality and personality.combatStyle then
                -- Aggressive bots will multitask
                if personality.combatStyle.aggressionMult and personality.combatStyle.aggressionMult > 1.2 then
                    return math_random() < 0.3  -- 30% chance
                end
            end
        end
        return false
    end

    -- Higher chance if idle
    if self.exp_State == "Idle" then
        return math_random() < 0.8  -- 80% chance
    end

    return math_random() < 0.5  -- 50% chance otherwise
end

function PLAYER:SelectObjective()
    if !EXP.GameMode or !EXP.GameMode.Active then return nil end

    local gamemode = EXP:GetGameMode(EXP.GameMode.Name)
    if !gamemode then return nil end

    -- Get objectives from gamemode
    if gamemode.GetObjectives then
        local objectives = gamemode:GetObjectives(self)
        if objectives and #objectives > 0 then
            -- Sort by priority (distance, importance, etc.)
            table.sort(objectives, function(a, b)
                return (a.priority or 0) > (b.priority or 0)
            end)

            -- Pick highest priority objective
            return objectives[1]
        end
    end

    return nil
end

--[[ Objective Execution ]]--

function PLAYER:PursueObjective(objective)
    if !objective then return false end

    self.exp_CurrentObjective = objective
    self.exp_ObjectiveType = objective.type
    self.exp_LastObjectiveTime = CurTime()

    -- Execute objective based on type
    if objective.type == "capture_flag" then
        return self:Objective_CaptureFlag(objective)
    elseif objective.type == "defend_flag" then
        return self:Objective_DefendFlag(objective)
    elseif objective.type == "capture_point" then
        return self:Objective_CapturePoint(objective)
    elseif objective.type == "defend_point" then
        return self:Objective_DefendPoint(objective)
    elseif objective.type == "kill_target" then
        return self:Objective_KillTarget(objective)
    elseif objective.type == "escort_target" then
        return self:Objective_EscortTarget(objective)
    end

    return false
end

--[[ CTF Objectives ]]--

function PLAYER:Objective_CaptureFlag(objective)
    if !IsValid(objective.flag) then
        self:ClearObjective()
        return false
    end

    local flag = objective.flag
    local flagPos = flag:GetPos()

    -- If we're carrying the flag, return to base
    if self.exp_CarryingFlag and IsValid(objective.capturePoint) then
        local capturePoint = objective.capturePoint
        local result = self:MoveToPos(capturePoint:GetPos(), {
            tolerance = 100,
            sprint = true,
            maxage = 20
        })

        if result == "ok" then
            -- Successfully captured!
            self:ClearObjective()
            return true
        end

        return false
    end

    -- Move to flag
    local result = self:MoveToPos(flagPos, {
        tolerance = 100,
        sprint = true,
        maxage = 20
    })

    if result == "ok" then
        -- Try to pick up flag (gamemode specific)
        if objective.onReach then
            objective.onReach(self, flag)
        end

        return true
    end

    return false
end

function PLAYER:Objective_DefendFlag(objective)
    if !IsValid(objective.flag) then
        self:ClearObjective()
        return false
    end

    local flag = objective.flag
    local flagPos = flag:GetPos()

    -- Move to defensive position near flag
    local defendPos = flagPos + Vector(math.random(-300, 300), math.random(-300, 300), 0)
    defendPos.z = flagPos.z  -- Same height as flag

    local result = self:MoveToPos(defendPos, {
        tolerance = 200,
        sprint = false,
        maxage = 15
    })

    if result == "ok" then
        -- Look for enemies near flag
        local enemies = self:FindNearbyEnemies(500)
        if #enemies > 0 then
            self.exp_Enemy = enemies[1]
            self:SetState("Combat")
        else
            -- Patrol around flag
            CoroutineWait(self, math_Rand(3, 5))
        end

        return true
    end

    return false
end

--[[ KOTH Objectives ]]--

function PLAYER:Objective_CapturePoint(objective)
    if !IsValid(objective.point) then
        self:ClearObjective()
        return false
    end

    local point = objective.point
    local pointPos = point:GetPos()

    -- Move to point
    local result = self:MoveToPos(pointPos, {
        tolerance = objective.captureRadius or 150,
        sprint = true,
        maxage = 20
    })

    if result == "ok" then
        -- Stay on point to capture
        local captureTime = objective.captureTime or 5
        local startTime = CurTime()

        while CurTime() - startTime < captureTime do
            -- Check if still on point
            local dist = self:GetPos():Distance(pointPos)
            if dist > (objective.captureRadius or 150) then
                -- Moved off point, restart
                return self:Objective_CapturePoint(objective)
            end

            -- Check for enemies
            if IsValid(self.exp_Enemy) then
                -- Engage enemy while on point
                local aimDir = (self.exp_Enemy:GetPos() + Vector(0, 0, 40) - self:GetShootPos()):GetNormalized()
                self:SetEyeAngles(aimDir:Angle())
                self:Attack(self.exp_Enemy)
            end

            CoroutineWait(self, 0.5)
        end

        -- Captured!
        if objective.onCapture then
            objective.onCapture(self, point)
        end

        return true
    end

    return false
end

function PLAYER:Objective_DefendPoint(objective)
    if !IsValid(objective.point) then
        self:ClearObjective()
        return false
    end

    local point = objective.point
    local pointPos = point:GetPos()

    -- Move to defensive position near point
    local defendPos = pointPos + Vector(math.random(-200, 200), math.random(-200, 200), 0)
    defendPos.z = pointPos.z

    local result = self:MoveToPos(defendPos, {
        tolerance = 150,
        sprint = false,
        maxage = 15
    })

    if result == "ok" then
        -- Look for enemies near point
        local enemies = self:FindNearbyEnemies(400)
        if #enemies > 0 then
            self.exp_Enemy = enemies[1]
            self:SetState("Combat")
        else
            -- Watch point
            self:SetEyeAngles((pointPos - self:GetPos()):Angle())
            CoroutineWait(self, math_Rand(2, 4))
        end

        return true
    end

    return false
end

--[[ General Objectives ]]--

function PLAYER:Objective_KillTarget(objective)
    if !IsValid(objective.target) then
        self:ClearObjective()
        return false
    end

    local target = objective.target

    -- Set as enemy and engage
    self.exp_Enemy = target
    self:SetState("Combat")

    -- Wait for combat to resolve
    while IsValid(self) and IsValid(target) and target:Health() > 0 do
        CoroutineWait(self, 1)
    end

    -- Check if killed
    if !IsValid(target) or target:Health() <= 0 then
        if objective.onKill then
            objective.onKill(self, target)
        end

        self:ClearObjective()
        return true
    end

    return false
end

function PLAYER:Objective_EscortTarget(objective)
    if !IsValid(objective.target) then
        self:ClearObjective()
        return false
    end

    local target = objective.target
    local escortDist = objective.distance or 200

    -- Follow target
    local result = self:MoveToPos(target:GetPos(), {
        tolerance = escortDist,
        sprint = false,
        maxage = 10
    })

    if result == "ok" then
        -- Look for threats
        local enemies = self:FindNearbyEnemies(500)
        if #enemies > 0 then
            -- Prioritize enemies near escort target
            table.sort(enemies, function(a, b)
                local distA = a:GetPos():Distance(target:GetPos())
                local distB = b:GetPos():Distance(target:GetPos())
                return distA < distB
            end)

            self.exp_Enemy = enemies[1]
            self:SetState("Combat")
        end

        return true
    end

    return false
end

--[[ Helper Functions ]]--

function PLAYER:ClearObjective()
    self.exp_CurrentObjective = nil
    self.exp_ObjectiveType = nil
    self.exp_NextObjectiveCheck = CurTime() + math_Rand(5, 10)
end

function PLAYER:HasObjective()
    return self.exp_CurrentObjective  ~=  nil
end

function PLAYER:GetCurrentObjective()
    return self.exp_CurrentObjective
end

function PLAYER:FindNearbyEnemies(radius)
    radius = radius or 1000
    local enemies = {}

    -- Get my team
    local myTeam = EXP:GetPlayerTeam(self)

    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or ply == self then continue end
        if !ply:Alive() then continue end

        -- Check team
        local theirTeam = EXP:GetPlayerTeam(ply)
        if myTeam and theirTeam and myTeam == theirTeam then continue end

        -- Check distance
        local dist = self:GetPos():Distance(ply:GetPos())
        if dist > radius then continue end

        -- Check line of sight
        if !self:CanSeeEntity(ply) then continue end

        table.insert(enemies, ply)
    end

    return enemies
end

--[[ Objective Think ]]--

function PLAYER:Think_Objective()
    -- Check if should pursue objectives
    if !self:ShouldPursueObjective() then
        return
    end

    -- If we have an objective, pursue it
    if self:HasObjective() then
        local success = self:PursueObjective(self:GetCurrentObjective())

        if !success then
            self.exp_ObjectiveFailCount = self.exp_ObjectiveFailCount + 1

            -- Give up after 3 failures
            if self.exp_ObjectiveFailCount >= 3 then
                self:ClearObjective()
                self.exp_ObjectiveFailCount = 0
            end
        else
            self.exp_ObjectiveFailCount = 0
        end
    else
        -- Select new objective
        local objective = self:SelectObjective()
        if objective then
            self:PursueObjective(objective)
        else
            -- No objectives available
            self.exp_NextObjectiveCheck = CurTime() + math_Rand(10, 20)
        end
    end
end

--[[ Objective State ]]--

function PLAYER:State_Objective()
    -- Select objective
    local objective = self:SelectObjective()

    if !objective then
        -- No objectives available
        self:SetState("Idle")
        return
    end

    -- Pursue objective
    local success = self:PursueObjective(objective)

    if success then
        -- Objective complete, wait a bit then look for new one
        CoroutineWait(self, math_Rand(1, 3))
        self:SetState("Idle")
    else
        -- Objective failed, try again or give up
        self.exp_ObjectiveFailCount = (self.exp_ObjectiveFailCount or 0) + 1

        if self.exp_ObjectiveFailCount >= 3 then
            -- Give up
            self:ClearObjective()
            self.exp_ObjectiveFailCount = 0
            self:SetState("Idle")
        else
            -- Try again
            CoroutineWait(self, 1)
        end
    end
end

print("[Experimental Players] Objective AI system loaded")
