-- Experimental Players - Main Player Bot Class
-- Based on GLambda Players architecture
-- Uses real PlayerBots (player.CreateNextBot)

local player_CreateNextBot = player.CreateNextBot
local IsValid = IsValid
local ents_Create = ents.Create
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield
local CurTime = CurTime
local table_Merge = table.Merge

-- Coroutine wait implementation for GMod
local function CoroutineWait(self, seconds)
    self.exp_CoroutineWaitUntil = CurTime() + seconds
    while CurTime() < self.exp_CoroutineWaitUntil do
        coroutine_yield()
    end
end

--[[ Player Bot Class ]]--

EXP.Player = ( EXP.Player or {} )
local PLAYER = EXP.Player

-- Copy toolgun methods if they exist (loaded from toolgun.lua)
if EXP.ToolgunPlayerMethods then
	for k, v in pairs(EXP.ToolgunPlayerMethods) do
		PLAYER[k] = v
	end
end

--[[ Creation Function ]]--

function EXP:CreateLambdaPlayer( name, profile )
    -- Generate random name if not provided
    if !name or name == "" then
        if self.Nicknames and #self.Nicknames > 0 then
            name = self:Random( self.Nicknames )
        else
            name = "Experimental Bot " .. math.random( 1, 999 )
        end
    end

    -- Create the player bot
    local ply = player_CreateNextBot( name )
    if !IsValid( ply ) then
        print( "[Experimental Players] ERROR: Failed to create player bot!" )
        return nil
    end

    -- Mark as experimental player
    ply.exp_IsExperimentalPlayer = true
    ply.exp_Profile = profile

    -- Copy all PLAYER methods to the player entity directly
    -- This allows methods to be called from within coroutines
    for methodName, methodFunc in pairs( EXP.Player ) do
        if type( methodFunc ) == "function" then
            ply[ methodName ] = methodFunc
        end
    end

    -- Create GLACE wrapper (GLambda's abstraction layer)
    local GLACE = { _PLY = ply }
    setmetatable( GLACE, {
        __index = function( tbl, key )
            -- Return player property/method directly
            return ply[ key ]
        end,
        __newindex = function( tbl, key, value )
            ply[ key ] = value
        end
    } )

    -- Create navigator entity
    local navigator = ents_Create( "exp_navigator" )
    if IsValid( navigator ) then
        navigator:Spawn()
        navigator:SetOwner( ply )
        GLACE.Navigator = navigator
    end

    -- Initialize bot properties
    self:InitializeBot( ply, GLACE )

    -- Start thinking thread
    local thread = coroutine_create( function()
        ply:ThreadedThink()
    end )
    ply._Thread = thread

    -- Add to bot list (initialize first!)
    self.ActiveBots = self.ActiveBots or {}
    table.insert( self.ActiveBots, GLACE )

    print( "[Experimental Players] Created bot: " .. name )
    return GLACE
end

function EXP:InitializeBot( ply, glace )
    -- Set random model
    local model = nil
    if self.GetRandomPlayerModel then
        model = self:GetRandomPlayerModel()
    end

    -- Fallback to default model if nil
    if !model or model == "" then
        model = "models/player/group01/male_0" .. math.random(1,9) .. ".mdl"
    end

    ply:SetModel( model )

    -- Set random colors
    local plyColor = Vector( math.Rand( 0, 1 ), math.Rand( 0, 1 ), math.Rand( 0, 1 ) )
    local wepColor = Vector( math.Rand( 0, 1 ), math.Rand( 0, 1 ), math.Rand( 0, 1 ) )
    ply:SetPlayerColor( plyColor )
    ply:SetWeaponColor( wepColor )

    -- Initialize state
    ply.exp_State = "Idle"
    ply.exp_StateTime = CurTime()

    -- Voice properties
    ply.exp_VoicePitch = math.random( 80, 120 )
    ply.exp_NextVoiceTime = 0

    -- Combat properties
    ply.exp_Enemy = nil
    ply.exp_LastSeenEnemy = 0

    -- Admin properties (check if should spawn as admin)
    local isAdmin = false
    if EXP:GetConVar( "admin_enabled" ) == 1 then
        local spawnChance = EXP:GetConVar( "admin_spawnchance" ) or 10
        if math.random( 1, 100 ) <= spawnChance then
            isAdmin = true
        end
    end

    -- Create weapon entity (call on ply, not glace)
    if ply.CreateWeaponEntity then
        ply:CreateWeaponEntity()
    end

    -- Initialize movement system
    if ply.InitializeMovement then
        ply:InitializeMovement()
    end

    -- Initialize combat system
    if ply.InitializeCombat then
        ply:InitializeCombat()
    end

    -- Initialize objective system
    if ply.InitializeObjective then
        ply:InitializeObjective()
    end

    -- Initialize building system
    if ply.InitializeBuilding then
        ply:InitializeBuilding()
    end

    -- Initialize personality system (BEFORE social systems)
    if ply.InitializePersonality then
        ply:InitializePersonality()
    end

    -- Initialize social systems
    if ply.InitializeTextChat then
        ply:InitializeTextChat()
    end

    if ply.InitializeVoice then
        ply:InitializeVoice()
    end

    -- Initialize building
    if ply.InitializeBuilding then
        ply:InitializeBuilding()
    end

    -- Initialize admin
    if ply.InitializeAdmin then
        local strictnessMin = EXP:GetConVar( "admin_strictnessmin" ) or 30
        local strictnessMax = EXP:GetConVar( "admin_strictnessmax" ) or 70
        local strictness = math.random( strictnessMin, strictnessMax )
        ply:InitializeAdmin( isAdmin, strictness )
    end

    -- Assign to team if gamemode is active
    if self.GameMode and self.GameMode.Active then
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

    -- Equip weapon based on personality preferences
    local randomWeapon = nil

    if ply.GetPersonalityData then
        local personalityData = ply:GetPersonalityData()
        if personalityData and personalityData.weaponPreference then
            -- Try to select weapon based on personality preferences
            local weaponTypes = {"melee", "shotgun", "smg", "sniper"}

            -- Sort by preference (highest first)
            table.sort(weaponTypes, function(a, b)
                return (personalityData.weaponPreference[a] or 0) > (personalityData.weaponPreference[b] or 0)
            end)

            -- Try each weapon type in order of preference
            for _, wType in ipairs(weaponTypes) do
                local preference = personalityData.weaponPreference[wType] or 0

                -- Roll for this weapon type
                if math.random() < preference then
                    -- Get weapon of this type
                    if wType == "melee" then
                        randomWeapon = self:GetRandomWeapon(true, false, true)  -- Lethal melee
                    elseif wType == "shotgun" then
                        randomWeapon = "shotgun"
                    elseif wType == "smg" then
                        randomWeapon = math.random() > 0.5 and "smg1" or "ar2"
                    elseif wType == "sniper" then
                        randomWeapon = "crossbow"
                    end

                    if randomWeapon and randomWeapon  ~=  "none" then
                        break  -- Found valid weapon
                    end
                end
            end
        end
    end

    -- Fallback to random if personality didn't pick one
    if !randomWeapon or randomWeapon == "none" then
        randomWeapon = self:GetRandomWeapon( true, false, false )  -- Lethal weapons only
    end

    -- Validate weapon and fallback to crowbar if needed
    if !randomWeapon or randomWeapon == "none" or !EXP:WeaponExists(randomWeapon) then
        randomWeapon = "crowbar"  -- Fallback weapon
        print( "[Experimental Players] WARNING: No valid weapon found, using crowbar for " .. ply:Nick() )
    end

    -- Switch weapon immediately (no timer delay)
    if ply.SwitchWeapon then
        ply:SwitchWeapon( randomWeapon, true )
        print( "[Experimental Players] " .. ply:Nick() .. " equipped " .. randomWeapon .. " (personality-based)" )
    end

    print( "[Experimental Players] Bot initialized: " .. ply:Nick() )
end

--[[ Player Bot Methods ]]--

function PLAYER:Think()
    -- Regular think function (called every tick)
    -- Handle immediate actions here

    -- Update navigator position
    if IsValid( self.Navigator ) then
        self.Navigator:SetPos( self:GetPos() )
    end

    -- Combat think
    if self.Think_Combat then
        self:Think_Combat()
    end

    -- Tool usage think
    if self.Think_ToolUse then
        self:Think_ToolUse()
    end

    -- Contextual tool usage (smart tool decisions)
    if self.Think_ContextualTools then
        self:Think_ContextualTools()
    end

    -- Text chat think
    if self.Think_TextChat then
        self:Think_TextChat()
    end

    -- Voice think
    if self.Think_Voice then
        self:Think_Voice()
    end

    -- Building think
    if self.Think_Building then
        self:Think_Building()
    end

    -- Update physgun hold if holding something
    if self.exp_PhysgunGrabbedEnt and self.PhysgunUpdateHold then
        self:PhysgunUpdateHold(self:GetWeaponENT())
    end

    -- Resume threaded think
    if self.exp_ThreadDisabled then return end  -- Thread disabled due to too many deaths

    if self._Thread then
        -- Check coroutine status before resuming
        local status = coroutine.status( self._Thread )

        if status == "suspended" then
            local ok, err = coroutine_resume( self._Thread )
            if !ok then
                ErrorNoHaltWithStack( "[Experimental Players] Thread error: " .. tostring( err ) )
            end
        elseif status == "dead" then
            -- Thread finished or crashed, recreate it with retry limit
            if !self.exp_ThreadDeathCount then self.exp_ThreadDeathCount = 0 end
            self.exp_ThreadDeathCount = self.exp_ThreadDeathCount + 1

            if self.exp_ThreadDeathCount > 5 then
                ErrorNoHalt("[Experimental Players] Thread for " .. self:Nick() .. " died too many times (" .. self.exp_ThreadDeathCount .. "), disabling bot\n")
                self.exp_ThreadDisabled = true
                return
            end

            print( "[Experimental Players] WARNING: Thread died for " .. self:Nick() .. " (attempt " .. self.exp_ThreadDeathCount .. "/5), recreating..." )
            self._Thread = coroutine_create( function()
                self:ThreadedThink()
            end )
        end
        -- If status is "running", skip (shouldn't happen but prevents errors)
    end
end

function PLAYER:ThreadedThink()
    -- Main AI loop (runs in coroutine)
    while true do
        local state = self.exp_State or "Idle"

        -- Execute current state
        if state == "Idle" then
            self:State_Idle()
        elseif state == "Wander" then
            self:State_Wander()
        elseif state == "Combat" then
            self:State_Combat()
        elseif state == "Retreat" then
            self:State_Retreat()
        elseif state == "Objective" then
            self:State_Objective()
        elseif state == "ToolUse" then
            self:State_ToolUse()
        elseif state == "AdminDuty" then
            if self.State_AdminDuty then
                self:State_AdminDuty()
            else
                self:SetState("Idle")
            end
        elseif state == "UsingCommand" then
            if self.State_UsingCommand then
                self:State_UsingCommand()
            else
                self:SetState("Idle")
            end
        elseif state == "Jailed" then
            -- Being held by admin, do nothing
            CoroutineWait( self, 1 )
        end

        CoroutineWait( self, 0.1 )
    end
end

--[[ State Functions ]]--

function PLAYER:SetState( newState )
    local oldState = self.exp_State

    -- Clean up old state data
    if oldState == "Combat" then
        self.exp_NextStrafeTime = nil
        self.exp_CombatStartTime = nil
    elseif oldState == "Retreat" then
        self.exp_RetreatEndTime = nil
        self.exp_RetreatingFrom = nil
    elseif oldState == "Cover" then
        if self.LeaveCover then
            self:LeaveCover()
        end
    end

    self.exp_State = newState
    self.exp_StateTime = CurTime()

    -- Set state-specific durations
    if newState == "Idle" then
        self.exp_IdleDuration = math.random( 2, 5 )
    end
end

function PLAYER:State_Idle()
    -- Idle state - do nothing for a bit, then pursue objectives or wander
    local idleDuration = self.exp_IdleDuration or 3
    if CurTime() > self.exp_StateTime + idleDuration then
        -- Check for objectives first
        if self.ShouldPursueObjective and self:ShouldPursueObjective() then
            self:SetState( "Objective" )
        else
            self:SetState( "Wander" )
        end
    end
    CoroutineWait( self, 1 )
end

function PLAYER:State_Wander()
    -- Wander state - move to random position
    local randomPos = self:GetPos() + Vector( math.random( -500, 500 ), math.random( -500, 500 ), 0 )

    -- Use movement system
    if self.MoveToPos then
        local result = self:MoveToPos( randomPos, {
            tolerance = 50,
            sprint = false,
            maxage = 10
        } )

        if result == "ok" then
            -- Reached destination, wait a bit
            CoroutineWait( self, math.random( 2, 4 ) )
        end
    else
        -- Fallback
        CoroutineWait( self, math.random( 5, 10 ) )
    end

    self:SetState( "Idle" )
end

function PLAYER:State_Combat()
    -- Combat state - fight enemy
    if !IsValid( self.exp_Enemy ) then
        self:SetState( "Idle" )
        return
    end

    -- Check if we should retreat (panic system)
    if self.ShouldRetreat and self:ShouldRetreat() then
        self:RetreatFrom( self.exp_Enemy, nil, true )
        CoroutineWait( self, 0.1 )
        return
    end

    -- Check if we're in cover and combat from cover
    if self.IsInCover and self:IsInCover() then
        if self.CombatFromCover then
            self:CombatFromCover()
            CoroutineWait( self, 0.1 )
            return
        end
    end

    -- Check if we should seek cover
    if self.ShouldSeekCover and self:ShouldSeekCover() then
        local coverData = self:FindBestCover()
        if coverData then
            print("[EXP] " .. self:Nick() .. " seeking cover!")
            self:MoveToCover(coverData)
            CoroutineWait( self, 0.5 )
            return
        end
    end

    local enemy = self.exp_Enemy
    local dist = self:GetPos():Distance( enemy:GetPos() )

    -- Get weapon data
    local weaponData = self:GetCurrentWeaponData()
    if !weaponData then
        -- No weapon, try to find one
        if self.SwitchWeapon then
            local randomWeapon = EXP:GetRandomWeapon( true, false, false )
            if randomWeapon and randomWeapon  ~=  "none" then
                self:SwitchWeapon( randomWeapon, true )
            end
        end
        CoroutineWait( self, 1 )
        return
    end

    -- Use weapon-specific ranges
    local keepDist = weaponData.keepdistance or 200
    local attackRange = weaponData.attackrange or 500
    local isMelee = weaponData.ismelee or false

    -- Determine if we're reloading
    local isReloading = self.exp_IsReloading or false

    -- Initialize strafe timer if not exists
    if !self.exp_NextStrafeTime then
        self.exp_NextStrafeTime = 0
    end

    -- Tactical positioning with strafing
    local inKeepRange = dist <= keepDist
    local movePos = enemy:GetPos()

    if dist > attackRange then
        -- Too far, move closer directly
        if self.MoveTowards then
            self:MoveTowards( enemy:GetPos() )
        end
    elseif dist < keepDist * 0.5 then
        -- Too close, back up
        local awayDir = ( self:GetPos() - enemy:GetPos() ):GetNormalized()
        local awayPos = self:GetPos() + awayDir * 200
        if self.MoveTowards then
            self:MoveTowards( awayPos )
        end
    else
        -- At optimal distance - strafe!
        if CurTime() >= self.exp_NextStrafeTime then
            -- Calculate strafe position perpendicular to enemy
            local toEnemy = ( enemy:GetPos() - self:GetPos() ):GetNormalized()
            local strafeDir = Vector( -toEnemy.y, toEnemy.x, 0 ):GetNormalized()

            -- Randomly strafe left or right
            if math.random( 1, 2 ) == 1 then
                strafeDir = -strafeDir
            end

            -- Calculate strafe position
            local strafePos = self:GetPos() + strafeDir * math.random( 50, 150 )

            -- Check if strafe position is valid (not in wall)
            if util.IsInWorld( strafePos ) then
                movePos = strafePos
            end

            -- Reset strafe timer
            self.exp_NextStrafeTime = CurTime() + math.random( 1, 3 )
        end

        -- Move to strafe position
        if self.MoveTowards then
            self:MoveTowards( movePos )
        end
    end

    -- Aim at enemy (lead target slightly if moving)
    local aimPos = enemy:GetPos() + Vector( 0, 0, 40 )
    if !isMelee and enemy:GetVelocity():Length() > 100 then
        -- Lead moving targets
        aimPos = aimPos + enemy:GetVelocity() * 0.1
    end
    local aimDir = ( aimPos - self:GetShootPos() ):GetNormalized()
    local aimAng = aimDir:Angle()
    self:SetEyeAngles( aimAng )

    -- Attack if in range and not reloading
    if dist <= attackRange and !isReloading and self.Attack then
        self:Attack( enemy )
    end

    -- Check if we need to reload
    if self.CanReload and self:CanReload() and self:GetWeaponClip() and self:GetWeaponClip() <= 2 then
        self:Reload()
    end

    CoroutineWait( self, 0.1 )
end

function PLAYER:State_Building()
    -- Building state - spawn props/entities
    if !self.ShouldBuild or !self:ShouldBuild() then
        self:SetState( "Idle" )
        return
    end

    -- Choose what to build based on personality
    local action = math.random( 1, 3 )
    if action == 1 and self.SpawnProp then
        self:SpawnProp()
    elseif action == 2 and self.SpawnEntity then
        self:SpawnEntity()
    elseif action == 3 and self.SpawnNPC then
        self:SpawnNPC()
    end

    -- Wait after building
    CoroutineWait( self, math.random( 2, 5 ) )
    self:SetState( "Idle" )
end

function PLAYER:State_Objective()
    -- Objective state - pursue gamemode objectives
    if !EXP.GameMode or !EXP.GameMode.Active then
        self:SetState( "Idle" )
        return
    end

    -- Delegate to gamemode-specific AI
    local gameMode = EXP.GameMode
    if gameMode.BotThink then
        local result = gameMode:BotThink( self )
        if result == "done" then
            self:SetState( "Idle" )
            return
        end
    end

    CoroutineWait( self, 0.5 )
end

function PLAYER:State_ToolUse()
    -- Tool use state - use tool gun for construction
    if !self.exp_ToolUseTarget then
        self:SetState( "Idle" )
        return
    end

    -- Use tool if we have one
    if self.exp_Weapon == "toolgun" then
        -- Tool gun usage logic would go here
        -- For now, just placeholder
        CoroutineWait( self, math.random( 1, 3 ) )
        self:SetState( "Idle" )
    else
        -- Switch to tool gun
        if self.SwitchWeapon and EXP:WeaponExists( "toolgun" ) then
            self:SwitchWeapon( "toolgun", true )
            CoroutineWait( self, 0.5 )
        else
            self:SetState( "Idle" )
        end
    end
end

function PLAYER:State_AdminDuty()
    -- Admin state - enforce rules
    if !self.exp_IsAdminBot then
        self:SetState( "Idle" )
        return
    end

    -- Admin logic would go here
    -- For now, just wander and observe
    self:State_Wander()
end

function PLAYER:State_Retreat()
    -- Retreat state - run away from enemy
    if CurTime() >= (self.exp_RetreatEndTime or 0) then
        -- Retreat timeout reached, return to idle
        self:SetState( "Idle" )
        print( "[EXP] " .. self:Nick() .. " finished retreating" )
        return
    end

    local enemy = self.exp_RetreatingFrom or self.exp_Enemy
    if !IsValid( enemy ) then
        -- Enemy is gone, safe to return to idle
        self:SetState( "Idle" )
        return
    end

    -- Calculate retreat position (away from enemy)
    local awayDir = ( self:GetPos() - enemy:GetPos() ):GetNormalized()
    local retreatPos = self:GetPos() + awayDir * 1000

    -- Move to retreat position with sprint
    if self.MoveToPos then
        local result = self:MoveToPos( retreatPos, {
            tolerance = 100,
            sprint = true,
            maxage = 3
        } )

        if result == "ok" or result == "stuck" then
            -- Reached retreat position or stuck, wait a bit
            CoroutineWait( self, 1 )
        end
    else
        -- Fallback to direct movement
        if self.MoveTowards then
            self:MoveTowards( retreatPos )
        end
        CoroutineWait( self, 0.5 )
    end

    -- Look back occasionally to track enemy
    if math.random( 1, 10 ) > 7 then
        local lookDir = ( enemy:GetPos() - self:GetShootPos() ):GetNormalized()
        self:SetEyeAngles( lookDir:Angle() )
    end

    CoroutineWait( self, 0.1 )
end

--[[ Hooks ]]--

hook.Add( "Think", "EXP_PlayerThink", function()
    if !EXP.ActiveBots then return end

    for _, bot in ipairs( EXP.ActiveBots ) do
        if IsValid( bot._PLY ) then
            bot._PLY:Think()  -- Call Think on the player entity, not the GLACE wrapper
        end
    end
end )

-- Control PlayerBot inputs via StartCommand
hook.Add( "StartCommand", "EXP_PlayerBotInput", function( ply, cmd )
    if !ply.exp_IsExperimentalPlayer then return end
    if !IsValid( ply ) or !ply:Alive() then return end

    -- Apply stored buttons
    if ply.exp_InputButtons and ply.exp_InputButtons > 0 then
        cmd:SetButtons( ply.exp_InputButtons )
        ply.exp_InputButtons = 0  -- Clear after applying
    end
end )

-- Control PlayerBot movement via SetupMove (THIS IS THE KEY!)
hook.Add( "SetupMove", "EXP_PlayerBotMovement", function( ply, mv, cmd )
    if !ply.exp_IsExperimentalPlayer then return end
    if !IsValid( ply ) or !ply:Alive() then return end

    -- Get current buttons
    local buttons = mv:GetButtons()

    -- Handle crouch state
    if ply.exp_MoveCrouch then
        buttons = bit.bor( buttons, IN_DUCK )
    else
        buttons = bit.band( buttons, bit.bnot( IN_DUCK ) )
    end

    -- Handle sprint state
    if ply.exp_MoveSprint then
        buttons = bit.bor( buttons, IN_SPEED )
    else
        buttons = bit.band( buttons, bit.bnot( IN_SPEED ) )
    end

    -- Apply buttons
    mv:SetButtons( buttons )

    -- Apply eye angle changes
    if ply.exp_LookTowards_Pos then
        local lookPos = ply.exp_LookTowards_Pos
        if CurTime() > (ply.exp_LookTowards_EndT or 0) then
            ply.exp_LookTowards_Pos = nil
        else
            local ang = ( lookPos - ply:EyePos() ):Angle()
            ang.z = 0
            ply:SetEyeAngles( LerpAngle( 0.1, ply:EyeAngles(), ang ) )
        end
    end

    -- Apply movement towards position (pathfinding)
    if ply.exp_FollowPath_Pos then
        local targetPos = ply.exp_FollowPath_Pos
        if CurTime() > (ply.exp_FollowPath_EndT or 0) then
            ply.exp_FollowPath_Pos = nil
        else
            -- Point movement direction towards target
            mv:SetMoveAngles( ( targetPos - ply:GetPos() ):Angle() )

            -- Set movement speed
            local speed = ply.exp_MoveSprint and ply:GetRunSpeed() or ply:GetWalkSpeed()
            mv:SetForwardSpeed( speed )
        end
    -- Apply manual movement input (combat/MoveTowards)
    elseif ply.exp_InputForwardMove and ply.exp_InputForwardMove  ~=  0 then
        -- Use input angles if set
        local moveAng = ply.exp_InputAngles or ply:EyeAngles()
        mv:SetMoveAngles( moveAng )

        -- Apply forward/side movement
        mv:SetForwardSpeed( ply.exp_InputForwardMove or 0 )
        mv:SetSideSpeed( ply.exp_InputSideMove or 0 )
    end
end )

print( "[Experimental Players] Player class loaded" )
