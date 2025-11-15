-- Experimental Players - Main Player Bot Class
-- Based on GLambda Players architecture
-- Uses real PlayerBots (player.CreateNextBot)

local player_CreateNextBot = player.CreateNextBot
local IsValid = IsValid
local ents_Create = ents.Create
local coroutine_create = coroutine.create
local coroutine_resume = coroutine.resume
local coroutine_yield = coroutine.yield
local coroutine_wait = coroutine.wait
local table_Merge = table.Merge

--[[ Player Bot Class ]]--

EXP.Player = ( EXP.Player or {} )
local PLAYER = EXP.Player

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

    -- Create GLACE wrapper (GLambda's abstraction layer)
    local GLACE = { _PLY = ply }
    setmetatable( GLACE, {
        __index = function( tbl, key )
            -- Check if it's a player method
            if PLAYER[ key ] then
                return function( self, ... )
                    return PLAYER[ key ]( ply, ... )
                end
            end
            -- Otherwise return player property
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
        GLACE:ThreadedThink()
    end )
    GLACE._Thread = thread

    -- Add to bot list
    table.insert( self.ActiveBots or {}, GLACE )
    self.ActiveBots = self.ActiveBots or {}

    print( "[Experimental Players] Created bot: " .. name )
    return GLACE
end

function EXP:InitializeBot( ply, glace )
    -- Set random model
    if self.GetRandomPlayerModel then
        local model = self:GetRandomPlayerModel()
        ply:SetModel( model )
    end

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

    -- Resume threaded think
    if self._Thread then
        local ok, err = coroutine_resume( self._Thread )
        if !ok then
            ErrorNoHaltWithStack( "[Experimental Players] Thread error: " .. tostring( err ) )
        end
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
        end

        coroutine_wait( 0.1 )
    end
end

--[[ State Functions ]]--

function PLAYER:SetState( newState )
    self.exp_State = newState
    self.exp_StateTime = CurTime()
end

function PLAYER:State_Idle()
    -- Idle state - do nothing for a bit, then wander
    if CurTime() > self.exp_StateTime + math.random( 2, 5 ) then
        self:SetState( "Wander" )
    end
    coroutine_wait( 1 )
end

function PLAYER:State_Wander()
    -- Wander state - move to random position
    local randomPos = self:GetPos() + Vector( math.random( -500, 500 ), math.random( -500, 500 ), 0 )

    if IsValid( self.Navigator ) then
        self.Navigator:ComputePath( randomPos, {} )
    end

    -- Wait a bit, then go idle
    coroutine_wait( math.random( 5, 10 ) )
    self:SetState( "Idle" )
end

function PLAYER:State_Combat()
    -- Combat state - fight enemy
    if !IsValid( self.exp_Enemy ) then
        self:SetState( "Idle" )
        return
    end

    -- TODO: Implement combat logic
    coroutine_wait( 0.5 )
end

--[[ Hooks ]]--

hook.Add( "Think", "EXP_PlayerThink", function()
    if !EXP.ActiveBots then return end

    for _, bot in ipairs( EXP.ActiveBots ) do
        if IsValid( bot._PLY ) then
            bot:Think()
        end
    end
end )

print( "[Experimental Players] Player class loaded" )
