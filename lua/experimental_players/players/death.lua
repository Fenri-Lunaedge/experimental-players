-- Experimental Players - Death and Respawn System
-- Based on Lambda Players death system
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local timer_Simple = timer.Simple
local math_random = math.random
local table_RemoveByValue = table.RemoveByValue

local PLAYER = EXP.Player

--[[ Death Handling ]]--

hook.Add("PlayerDeath", "EXP_OnPlayerDeath", function(victim, inflictor, attacker)
    if !IsValid(victim) or !victim.exp_IsExperimentalPlayer then return end

    -- Find GLACE wrapper
    local botWrapper = nil
    if EXP.ActiveBots then
        for _, bot in ipairs(EXP.ActiveBots) do
            if bot._PLY == victim then
                botWrapper = bot
                break
            end
        end
    end

    if !botWrapper then return end

    -- Call death voice/text
    -- FIX: Type check to ensure these are functions
    if type(victim.Voice_Death) == "function" then
        victim:Voice_Death()
    end

    if type(victim.OnDeath) == "function" then
        victim:OnDeath(attacker)
    end

    -- Stop movement
    if botWrapper.StopMoving then
        botWrapper:StopMoving()
    end

    -- Set state to dead
    victim.exp_State = "Dead"
    victim.exp_Enemy = nil
    victim.exp_IsDead = true

    -- Cleanup bot entities to prevent memory leaks
    if IsValid(victim.Navigator) then
        victim.Navigator:Remove()
        victim.Navigator = nil
    end

    if IsValid(victim.exp_WeaponEntity) then
        victim.exp_WeaponEntity:Remove()
        victim.exp_WeaponEntity = nil
    end

    -- Create ragdoll
    local ragdoll = victim:GetRagdollEntity()
    if IsValid(ragdoll) then
        -- Copy velocity from victim to ragdoll for realistic death physics
        local vel = victim:GetVelocity()
        for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
            local phys = ragdoll:GetPhysicsObjectNum(i)
            if IsValid(phys) then
                phys:SetVelocity(vel)
            end
        end

        -- Remove ragdoll after respawn time
        local respawnTime = EXP:GetConVar("death_respawntime") or 5
        timer_Simple(respawnTime + 0.5, function()
            if IsValid(ragdoll) then
                ragdoll:Remove()
            end
        end)
    end

    -- Schedule respawn
    local respawnTime = EXP:GetConVar("death_respawntime") or 5

    timer_Simple(respawnTime, function()
        if IsValid(victim) then
            EXP:RespawnBot(victim)
        end
    end)
end)

--[[ Respawn System ]]--

function EXP:RespawnBot(ply)
    if !IsValid(ply) or !ply.exp_IsExperimentalPlayer then return end

    -- Spawn the player
    ply:Spawn()

    -- Reset state
    ply.exp_State = "Idle"
    ply.exp_StateTime = CurTime()
    ply.exp_Enemy = nil
    ply.exp_IsDead = false

    -- Assign to team if gamemode is active
    if self.GameMode and self.GameMode.Active then
        -- If not on a team yet, auto-assign
        if !ply.exp_Team then
            -- Find team with fewest players
            local smallestTeam = nil
            local smallestCount = math.huge

            for teamID, team in pairs(self.GameMode.Teams) do
                local count = table.Count(team.players)
                if count < smallestCount then
                    smallestCount = count
                    smallestTeam = teamID
                end
            end

            -- Assign to team
            if smallestTeam then
                EXP:AssignPlayerToTeam(ply, smallestTeam)
            end
        end

        -- Find team-specific spawn point
        local spawnPos = self:FindTeamSpawnPosition(ply.exp_Team)
        if spawnPos then
            ply:SetPos(spawnPos)
        end
    else
        -- No gamemode, use regular spawn
        local spawnPos = self:FindSpawnPosition()
        if spawnPos then
            ply:SetPos(spawnPos)
        end
    end

    -- Reset health
    ply:SetHealth(ply:GetMaxHealth())

    -- Give weapon back or random weapon
    local weapon = ply.exp_Weapon or ply.exp_CurrentWeapon
    if weapon and weapon  ~=  "none" and ply.SwitchWeapon then
        timer_Simple(0.1, function()
            if IsValid(ply) and EXP:WeaponExists(weapon) then
                ply:SwitchWeapon(weapon, true)
            else
                -- Fallback to random weapon
                local randomWeapon = EXP:GetRandomWeapon(true, false, false)
                if randomWeapon and randomWeapon  ~=  "none" then
                    ply:SwitchWeapon(randomWeapon, true)
                end
            end
        end)
    else
        -- No previous weapon, give random
        timer_Simple(0.1, function()
            if IsValid(ply) then
                local randomWeapon = EXP:GetRandomWeapon(true, false, false)
                if randomWeapon and randomWeapon  ~=  "none" then
                    ply:SwitchWeapon(randomWeapon, true)
                end
            end
        end)
    end

    -- FIX: Recreate Navigator entity (was removed on death)
    local navigator = ents.Create( "exp_navigator" )
    if IsValid( navigator ) then
        navigator:Spawn()
        navigator:SetOwner( ply )
        ply.Navigator = navigator
    else
        print("[EXP] ERROR: Failed to recreate Navigator for " .. ply:Nick())
    end

    -- FIX: Recreate WeaponEntity (was removed on death)
    if ply.CreateWeaponEntity then
        ply:CreateWeaponEntity()
    end

    -- Reset movement
    if ply.InitializeMovement then
        ply:InitializeMovement()
    end

    -- Reset combat
    if ply.InitializeCombat then
        ply:InitializeCombat()
    end

    -- Call respawn hook
    hook.Run("EXP_OnPlayerRespawn", ply)
end

function EXP:FindSpawnPosition()
    -- FIX: ents.FindByClass doesn't support wildcards, must search each type
    local spawns = {}

    -- Find all player spawn types manually
    table.Add(spawns, ents.FindByClass("info_player_deathmatch"))
    table.Add(spawns, ents.FindByClass("info_player_combine"))
    table.Add(spawns, ents.FindByClass("info_player_rebel"))
    table.Add(spawns, ents.FindByClass("info_player_counterterrorist"))
    table.Add(spawns, ents.FindByClass("info_player_terrorist"))
    table.Add(spawns, ents.FindByClass("gmod_player_start"))
    table.Add(spawns, ents.FindByClass("info_player_start"))

    if #spawns > 0 then
        local spawn = spawns[math_random(#spawns)]
        return spawn:GetPos() + Vector(0, 0, 10)
    end

    -- Fallback: find a random valid position
    local trace = util.TraceLine({
        start = Vector(0, 0, 1000),
        endpos = Vector(0, 0, -1000),
        mask = MASK_SOLID_BRUSHONLY
    })

    if trace.Hit then
        return trace.HitPos + Vector(0, 0, 50)
    end

    return Vector(0, 0, 0)
end

function EXP:FindTeamSpawnPosition(teamID)
    if !teamID then return self:FindSpawnPosition() end

    -- Try to find team-specific spawn points
    local teamSpawns = ents.FindByClass("info_player_team" .. teamID)

    -- Try TDM spawn points
    if #teamSpawns == 0 then
        teamSpawns = ents.FindByClass("info_player_deathmatch")
    end

    -- Try CTF spawn points based on team
    if #teamSpawns == 0 and teamID == 1 then
        teamSpawns = ents.FindByClass("info_player_rebel")
    elseif #teamSpawns == 0 and teamID == 2 then
        teamSpawns = ents.FindByClass("info_player_combine")
    end

    -- Use team spawn if found
    if #teamSpawns > 0 then
        local spawn = teamSpawns[math_random(#teamSpawns)]
        return spawn:GetPos() + Vector(0, 0, 10)
    end

    -- Fallback to regular spawn
    return self:FindSpawnPosition()
end

--[[ Kill Tracking ]]--

hook.Add("OnNPCKilled", "EXP_OnBotKillNPC", function(npc, attacker, inflictor)
    if !IsValid(attacker) or !attacker.exp_IsExperimentalPlayer then return end

    -- Call kill callbacks on the player entity directly
    -- FIX: Type check to ensure these are functions
    if type(attacker.Voice_Kill) == "function" then
        attacker:Voice_Kill()
    end

    if type(attacker.OnKillEnemy) == "function" then
        attacker:OnKillEnemy(npc)
    end

    -- Say kill message
    if type(attacker.SayText) == "function" and math_random(1, 100) < 50 then
        attacker:SayText(nil, "kill")
    end
end)

hook.Add("PlayerDeath", "EXP_OnBotKillPlayer", function(victim, inflictor, attacker)
    if !IsValid(attacker) or !attacker.exp_IsExperimentalPlayer then return end
    if victim == attacker then return end  -- Suicide

    -- Call kill callbacks on the player entity directly
    -- FIX: Type check to ensure these are functions
    if type(attacker.Voice_Kill) == "function" then
        attacker:Voice_Kill()
    end

    if type(attacker.OnKillEnemy) == "function" then
        attacker:OnKillEnemy(victim)
    end

    -- Say kill message
    if type(attacker.SayText) == "function" and math_random(1, 100) < 50 then
        attacker:SayText(nil, "kill")
    end
end)

--[[ Bot Removal ]]--

hook.Add("PlayerDisconnected", "EXP_OnBotRemove", function(ply)
    if !IsValid(ply) or !ply.exp_IsExperimentalPlayer then return end

    -- Remove from active bots list
    if EXP.ActiveBots then
        for i, bot in ipairs(EXP.ActiveBots) do
            if bot._PLY == ply then
                -- FIX: Access properties on player entity, not wrapper
                -- Cleanup navigator
                if IsValid(ply.Navigator) then
                    ply.Navigator:Remove()
                end

                -- Cleanup weapon entity
                if IsValid(ply.exp_WeaponEntity) then
                    ply.exp_WeaponEntity:Remove()
                end

                -- Cleanup entities (call on wrapper since it has the method)
                if type(bot.CleanupEntities) == "function" then
                    bot:CleanupEntities()
                end

                -- Remove from list
                table.remove(EXP.ActiveBots, i)
                break
            end
        end
    end
end)

print("[Experimental Players] Death and respawn system loaded")
