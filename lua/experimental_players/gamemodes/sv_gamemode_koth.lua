-- Experimental Players - King of the Hill
-- Full KOTH implementation with bot AI support
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random
local math_max = math.max

--[[ KOTH Gamemode ]]--

local KOTH = {
    ControlPoint = nil,
    ControlPointPos = nil,
    CaptureRadius = 200,
    ControllingTeam = nil,
    CaptureProgress = {},  -- [teamID] = progress (0-100)
    LastCaptureTick = 0,
}

function KOTH:Initialize()
    -- Create teams
    EXP:CreateTeam(1, "Red Team", Color(255, 50, 50))
    EXP:CreateTeam(2, "Blue Team", Color(50, 100, 255))

    -- Auto-balance teams
    EXP:AutoBalanceTeams()

    -- Find/create control point
    self:SetupControlPoint()

    -- Initialize capture progress
    for teamID, _ in pairs(EXP.GameMode.Teams) do
        self.CaptureProgress[teamID] = 0
    end

    -- Start round
    EXP:StartRound(600)  -- 10 minute rounds

    print("[KOTH] Gamemode initialized")
end

function KOTH:Shutdown()
    -- Remove control point
    if IsValid(self.ControlPoint) then
        self.ControlPoint:Remove()
    end

    print("[KOTH] Gamemode shutdown")
end

function KOTH:SetupControlPoint()
    -- Find control point by name
    local point = ents.FindByName("control_point")[1]

    if !IsValid(point) then
        -- Create control point at map center (or first spawn)
        local spawn = ents.FindByClass("info_player_start")[1]
        if IsValid(spawn) then
            self.ControlPointPos = spawn:GetPos()
        else
            self.ControlPointPos = Vector(0, 0, 0)
        end
    else
        self.ControlPointPos = point:GetPos()
    end

    -- Create visual control point (prop)
    self.ControlPoint = ents.Create("prop_physics")
    self.ControlPoint:SetModel("models/props_junk/wood_crate001a.mdl")
    self.ControlPoint:SetPos(self.ControlPointPos)
    self.ControlPoint:SetColor(Color(200, 200, 200))
    self.ControlPoint:SetMaterial("models/debug/debugwhite")
    self.ControlPoint:Spawn()
    self.ControlPoint.exp_IsControlPoint = true

    -- Make it invulnerable
    self.ControlPoint:SetCollisionGroup(COLLISION_GROUP_WORLD)

    print("[KOTH] Control point created at " .. tostring(self.ControlPointPos))
end

function KOTH:OnRoundStart()
    -- Reset control
    self.ControllingTeam = nil

    -- Reset capture progress
    for teamID, _ in pairs(EXP.GameMode.Teams) do
        self.CaptureProgress[teamID] = 0
    end

    -- Reset team scores
    for teamID, team in pairs(EXP.GameMode.Teams) do
        team.score = 0
    end

    -- Reset visual
    if IsValid(self.ControlPoint) then
        self.ControlPoint:SetColor(Color(200, 200, 200))
    end
end

function KOTH:OnRoundEnd()
    -- Announce winner
    local winningTeam, highestScore = EXP:GetWinningTeam()

    if winningTeam then
        local teamData = EXP.GameMode.Teams[winningTeam]
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply:ChatPrint("╔═══════════════════════════════════")
                ply:ChatPrint("║ " .. teamData.name .. " WINS!")
                ply:ChatPrint("║ Control Time: " .. highestScore .. "s")
                ply:ChatPrint("╚═══════════════════════════════════")
            end
        end
    end
end

function KOTH:Think()
    -- Update capture progress every 0.5 seconds
    if CurTime() - self.LastCaptureTick < 0.5 then return end
    self.LastCaptureTick = CurTime()

    -- Count players on point per team
    local teamCounts = {}
    for teamID, _ in pairs(EXP.GameMode.Teams) do
        teamCounts[teamID] = 0
    end

    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() then continue end

        local dist = ply:GetPos():Distance(self.ControlPointPos)
        if dist <= self.CaptureRadius then
            local team = EXP:GetPlayerTeam(ply)
            if team then
                teamCounts[team] = teamCounts[team] + 1
            end
        end
    end

    -- Determine capturing team (team with most players)
    local capturingTeam = nil
    local maxPlayers = 0
    local contested = false

    for teamID, count in pairs(teamCounts) do
        if count > maxPlayers then
            maxPlayers = count
            capturingTeam = teamID
            contested = false
        elseif count == maxPlayers and count > 0 then
            contested = true  -- Tie
        end
    end

    -- Update capture progress
    if contested or maxPlayers == 0 then
        -- Point is contested or empty, no progress
    elseif self.ControllingTeam == capturingTeam then
        -- Controlling team holds point, add score
        EXP:AddTeamScore(capturingTeam, 1)

        -- Update visual
        local teamColor = EXP.GameMode.Teams[capturingTeam].color
        if IsValid(self.ControlPoint) then
            self.ControlPoint:SetColor(teamColor)
        end
    else
        -- Enemy team on point, reduce progress or capture
        if self.ControllingTeam then
            -- Reduce current team's progress
            self.CaptureProgress[self.ControllingTeam] = math_max(0, self.CaptureProgress[self.ControllingTeam] - 5)

            if self.CaptureProgress[self.ControllingTeam] <= 0 then
                -- Lost control
                self.ControllingTeam = nil

                -- Broadcast
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) then
                        p:ChatPrint("⚠ Control point neutralized!")
                    end
                end

                -- Reset visual
                if IsValid(self.ControlPoint) then
                    self.ControlPoint:SetColor(Color(200, 200, 200))
                end
            end
        else
            -- Neutral point, capturing team gains progress
            self.CaptureProgress[capturingTeam] = (self.CaptureProgress[capturingTeam] or 0) + 5

            if self.CaptureProgress[capturingTeam] >= 100 then
                -- CAPTURED!
                self.ControllingTeam = capturingTeam
                self.CaptureProgress[capturingTeam] = 100

                -- Broadcast
                local teamData = EXP.GameMode.Teams[capturingTeam]
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) then
                        p:ChatPrint("★ " .. teamData.name .. " captured the point! ★")
                        p:EmitSound("ambient/alarms/klaxon1.wav", 75, 110)
                    end
                end

                -- Update visual
                if IsValid(self.ControlPoint) then
                    self.ControlPoint:SetColor(teamData.color)
                end
            end
        end
    end
end

--[[ Bot AI Support ]]--

function KOTH:GetObjectives(bot)
    if !IsValid(bot) then return {} end

    local botTeam = EXP:GetPlayerTeam(bot)
    if !botTeam then return {} end

    local objectives = {}

    -- If point is controlled by enemy, try to capture it
    if self.ControllingTeam  ~=  botTeam then
        table.insert(objectives, {
            type = "capture_point",
            point = self.ControlPoint,
            captureRadius = self.CaptureRadius,
            captureTime = 20,  -- Stay on point for 20s to capture
            priority = 90,
            onCapture = function(ply, point)
                -- Capture handled by Think()
            end
        })
    else
        -- Point is controlled by our team, defend it
        table.insert(objectives, {
            type = "defend_point",
            point = self.ControlPoint,
            priority = 70,
        })
    end

    return objectives
end

-- Register gamemode
EXP:RegisterGameMode("koth", KOTH)

print("[Experimental Players] KOTH gamemode loaded")
