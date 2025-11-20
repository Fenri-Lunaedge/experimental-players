-- Experimental Players - Capture the Flag
-- Full CTF implementation with bot AI support
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local math_random = math.random

--[[ CTF Gamemode ]]--

local CTF = {
    RedFlag = nil,
    BlueFlag = nil,
    RedFlagSpawn = nil,
    BlueFlagSpawn = nil,
    RedBase = nil,
    BlueBase = nil,
}

function CTF:Initialize()
    -- Create teams
    EXP:CreateTeam(1, "Red Team", Color(255, 50, 50))
    EXP:CreateTeam(2, "Blue Team", Color(50, 100, 255))

    -- Auto-balance teams
    EXP:AutoBalanceTeams()

    -- Find flag spawns (or create them)
    self:SetupFlags()

    -- Start round
    EXP:StartRound(600)  -- 10 minute rounds

    print("[CTF] Gamemode initialized")
end

function CTF:Shutdown()
    -- Remove flags
    if IsValid(self.RedFlag) then self.RedFlag:Remove() end
    if IsValid(self.BlueFlag) then self.BlueFlag:Remove() end

    print("[CTF] Gamemode shutdown")
end

function CTF:SetupFlags()
    -- Find flag spawns by name or create default positions
    local redSpawn = ents.FindByName("red_flag_spawn")[1]
    local blueSpawn = ents.FindByName("blue_flag_spawn")[1]

    -- If no named spawns, use team spawns
    if !IsValid(redSpawn) then
        local redTeamSpawn = ents.FindByClass("info_player_teamspawn")[1]
        if IsValid(redTeamSpawn) then
            redSpawn = redTeamSpawn
        end
    end

    if !IsValid(blueSpawn) then
        local blueTeamSpawn = ents.FindByClass("info_player_teamspawn")[2]
        if IsValid(blueTeamSpawn) then
            blueSpawn = blueTeamSpawn
        end
    end

    -- Store spawn positions
    if IsValid(redSpawn) then
        self.RedFlagSpawn = redSpawn:GetPos()
    else
        self.RedFlagSpawn = Vector(0, 0, 0)  -- Fallback
    end

    if IsValid(blueSpawn) then
        self.BlueFlagSpawn = blueSpawn:GetPos()
    else
        self.BlueFlagSpawn = Vector(1000, 1000, 0)  -- Fallback
    end

    -- Create flag entities (props for now, could be custom entities)
    self.RedFlag = ents.Create("prop_physics")
    self.RedFlag:SetModel("models/props_junk/PopCan01a.mdl")  -- Red can as placeholder
    self.RedFlag:SetPos(self.RedFlagSpawn + Vector(0, 0, 20))
    self.RedFlag:SetColor(Color(255, 0, 0))
    self.RedFlag:SetMaterial("models/debug/debugwhite")
    self.RedFlag:Spawn()
    self.RedFlag.exp_FlagTeam = 1
    self.RedFlag.exp_IsFlag = true
    self.RedFlag.exp_FlagCarrier = nil

    self.BlueFlag = ents.Create("prop_physics")
    self.BlueFlag:SetModel("models/props_junk/PopCan01a.mdl")  -- Blue can as placeholder
    self.BlueFlag:SetPos(self.BlueFlagSpawn + Vector(0, 0, 20))
    self.BlueFlag:SetColor(Color(0, 100, 255))
    self.BlueFlag:SetMaterial("models/debug/debugwhite")
    self.BlueFlag:Spawn()
    self.BlueFlag.exp_FlagTeam = 2
    self.BlueFlag.exp_IsFlag = true
    self.BlueFlag.exp_FlagCarrier = nil

    print("[CTF] Flags created at " .. tostring(self.RedFlagSpawn) .. " and " .. tostring(self.BlueFlagSpawn))
end

function CTF:OnRoundStart()
    -- Reset flags
    if IsValid(self.RedFlag) then
        self.RedFlag:SetPos(self.RedFlagSpawn + Vector(0, 0, 20))
        self.RedFlag.exp_FlagCarrier = nil
    end

    if IsValid(self.BlueFlag) then
        self.BlueFlag:SetPos(self.BlueFlagSpawn + Vector(0, 0, 20))
        self.BlueFlag.exp_FlagCarrier = nil
    end

    -- Reset team scores
    for teamID, team in pairs(EXP.GameMode.Teams) do
        team.score = 0
    end
end

function CTF:OnRoundEnd()
    -- Announce winner
    local winningTeam, highestScore = EXP:GetWinningTeam()

    if winningTeam then
        local teamData = EXP.GameMode.Teams[winningTeam]
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply:ChatPrint("╔═══════════════════════════════════")
                ply:ChatPrint("║ " .. teamData.name .. " WINS!")
                ply:ChatPrint("║ Score: " .. highestScore .. " captures")
                ply:ChatPrint("╚═══════════════════════════════════")
            end
        end
    end
end

function CTF:Think()
    -- Check flag pickup
    self:CheckFlagPickup(self.RedFlag)
    self:CheckFlagPickup(self.BlueFlag)

    -- Check flag capture
    self:CheckFlagCapture(self.RedFlag, self.BlueFlagSpawn, 2)
    self:CheckFlagCapture(self.BlueFlag, self.RedFlagSpawn, 1)
end

function CTF:CheckFlagPickup(flag)
    if !IsValid(flag) then return end
    if flag.exp_FlagCarrier then return end  -- Already carried

    local flagPos = flag:GetPos()

    -- Find players near flag
    for _, ply in ipairs(player.GetAll()) do
        if !IsValid(ply) or !ply:Alive() then continue end

        -- Check distance
        local dist = ply:GetPos():Distance(flagPos)
        if dist > 100 then continue end

        -- Check team (can't pick up own flag)
        local playerTeam = EXP:GetPlayerTeam(ply)
        if playerTeam == flag.exp_FlagTeam then continue end

        -- Pick up flag!
        flag.exp_FlagCarrier = ply
        ply.exp_CarryingFlag = flag
        flag:SetParent(ply)
        flag:SetLocalPos(Vector(0, 0, 60))  -- Above head

        -- Broadcast
        local teamData = EXP.GameMode.Teams[playerTeam]
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                p:ChatPrint("★ " .. ply:Nick() .. " took the " .. (flag.exp_FlagTeam == 1 and "RED" or "BLUE") .. " flag!")
            end
        end

        break
    end
end

function CTF:CheckFlagCapture(flag, capturePos, scoringTeam)
    if !IsValid(flag) then return end
    if !flag.exp_FlagCarrier then return end  -- Not carried

    local carrier = flag.exp_FlagCarrier
    if !IsValid(carrier) then
        -- Carrier disconnected, drop flag
        self:DropFlag(flag)
        return
    end

    -- Check if carrier died
    if !carrier:Alive() then
        self:DropFlag(flag)
        return
    end

    -- Check if carrier reached capture point
    local dist = carrier:GetPos():Distance(capturePos)
    if dist < 150 then
        -- CAPTURED!
        EXP:AddTeamScore(scoringTeam, 1)

        -- Reset flag
        flag:SetParent(nil)
        flag:SetPos(flag.exp_FlagTeam == 1 and self.RedFlagSpawn or self.BlueFlagSpawn)
        flag.exp_FlagCarrier = nil
        carrier.exp_CarryingFlag = nil

        -- Broadcast
        local teamData = EXP.GameMode.Teams[scoringTeam]
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                p:ChatPrint("★★★ " .. carrier:Nick() .. " CAPTURED the flag for " .. teamData.name .. "! ★★★")
                p:EmitSound("ambient/alarms/klaxon1.wav", 75, 100)
            end
        end
    end
end

function CTF:DropFlag(flag)
    if !IsValid(flag) then return end

    local carrier = flag.exp_FlagCarrier
    if IsValid(carrier) then
        -- Drop at carrier position
        flag:SetParent(nil)
        flag:SetPos(carrier:GetPos() + Vector(0, 0, 30))

        carrier.exp_CarryingFlag = nil
    end

    flag.exp_FlagCarrier = nil

    -- Return to spawn after 30 seconds
    timer.Simple(30, function()
        if IsValid(flag) and !flag.exp_FlagCarrier then
            flag:SetPos(flag.exp_FlagTeam == 1 and self.RedFlagSpawn or self.BlueFlagSpawn)
        end
    end)
end

--[[ Bot AI Support ]]--

function CTF:GetObjectives(bot)
    if !IsValid(bot) then return {} end

    local botTeam = EXP:GetPlayerTeam(bot)
    if !botTeam then return {} end

    local objectives = {}

    -- Determine enemy flag and own flag
    local enemyFlag = (botTeam == 1) and self.BlueFlag or self.RedFlag
    local ownFlag = (botTeam == 1) and self.RedFlag or self.BlueFlag
    local capturePoint = (botTeam == 1) and self.RedFlagSpawn or self.BlueFlagSpawn

    -- If carrying flag, prioritize capturing
    if bot.exp_CarryingFlag then
        table.insert(objectives, {
            type = "capture_flag",
            flag = bot.exp_CarryingFlag,
            capturePoint = {GetPos = function() return capturePoint end},
            priority = 100,
        })
        return objectives
    end

    -- If enemy flag is available, try to capture it
    if IsValid(enemyFlag) and !enemyFlag.exp_FlagCarrier then
        table.insert(objectives, {
            type = "capture_flag",
            flag = enemyFlag,
            capturePoint = {GetPos = function() return capturePoint end},
            priority = 80,
            onReach = function(ply, flag)
                -- Flag pickup handled by Think()
            end
        })
    end

    -- If own flag is taken, try to kill carrier
    if IsValid(ownFlag) and IsValid(ownFlag.exp_FlagCarrier) then
        table.insert(objectives, {
            type = "kill_target",
            target = ownFlag.exp_FlagCarrier,
            priority = 90,
        })
    end

    -- Defend own flag
    if IsValid(ownFlag) and !ownFlag.exp_FlagCarrier then
        table.insert(objectives, {
            type = "defend_flag",
            flag = ownFlag,
            priority = 40,
        })
    end

    return objectives
end

-- Register gamemode
EXP:RegisterGameMode("ctf", CTF)

print("[Experimental Players] CTF gamemode loaded")
