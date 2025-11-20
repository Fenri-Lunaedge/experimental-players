-- Experimental Players - Advanced PlayerBot AI for Garry's Mod
-- Based on GLambda Players architecture with enhancements
-- Author: Fenri-Lunaedge
-- License: MIT

local game_SinglePlayer = game.SinglePlayer
local IsValid = IsValid
local PrintMessage = PrintMessage
local file_Find = file.Find
local ipairs = ipairs
local string_StartWith = string.StartWith
local include = include
local print = print
local AddCSLuaFile = AddCSLuaFile
local net_Start = net.Start
local net_Broadcast = SERVER and net.Broadcast
local file_Exists = file.Exists
local pairs = pairs
local list_Set = list.Set
local concommand_Add = concommand.Add

--

if game_SinglePlayer() then
    print("[Experimental Players] ERROR: This addon requires multiplayer mode!")
    print("[Experimental Players] Please run a dedicated server or use multiplayer to use this addon.")
    return
end

EXPERIMENTAL_PLAYERS = ( EXPERIMENTAL_PLAYERS or {} )
EXP = EXPERIMENTAL_PLAYERS -- Shorthand alias

-- Network strings
if ( SERVER ) then
    util.AddNetworkString( "exp_reloadfiles" )
    util.AddNetworkString( "exp_updatedata" )
end

--

local initialized = false
function EXP:LoadFiles( caller )
    if ( SERVER ) and IsValid( caller ) then
        if !caller:IsSuperAdmin() then return end -- Nuh uh.
        PrintMessage( HUD_PRINTTALK, "SERVER is reloading all Experimental Players files..." )
    end

    -- Core include files
    local dirPath = "experimental_players/includes/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Server-Side: " .. luaFile )
        elseif string_StartWith( luaFile, "cl_" ) then
            if ( SERVER ) then
                AddCSLuaFile( dirPath .. luaFile )
            else
                include( dirPath .. luaFile )
                print( "[Experimental Players] Loaded Client-Side: " .. luaFile )
            end
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Shared: " .. luaFile )
        end
    end

    print( "[Experimental Players] Core files loaded" )

    -- Weapon definitions (MUST load before player class)
    local dirPath = "experimental_players/weapons/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Weapon Definition (Server): " .. luaFile )
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Weapon Definition (Shared): " .. luaFile )
        elseif ( SERVER ) then
            -- No prefix = shared for weapons
            AddCSLuaFile( dirPath .. luaFile )
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Weapon Definition: " .. luaFile )
        end
    end

    print( "[Experimental Players] Weapon definitions loaded" )

    -- Validate weapon table
    if _EXPERIMENTALPLAYERSWEAPONS and table.Count(_EXPERIMENTALPLAYERSWEAPONS) > 0 then
        print( "[Experimental Players] Weapon registry validated: " .. table.Count(_EXPERIMENTALPLAYERSWEAPONS) .. " weapons available" )
    else
        print( "[Experimental Players] WARNING: No weapons loaded! Bots may not function correctly." )
    end

    -- Load main player class (defines PLAYER table)
    if ( SERVER ) then AddCSLuaFile( "experimental_players/exp_player.lua" ) end
    include( "experimental_players/exp_player.lua" )
    print( "[Experimental Players] Main player class loaded" )

    -- Player behavior modules (need PLAYER to exist)
    local dirPath = "experimental_players/players/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if ( SERVER ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Player Module: " .. luaFile )
        end
    end

    -- Social features (chat, voice, voting, etc.)
    local dirPath = "experimental_players/social/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Social Module (Server): " .. luaFile )
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Social Module (Shared): " .. luaFile )
        end
    end

    -- Game modes (CTF, KOTH, TDM)
    -- Load base system first
    local dirPath = "experimental_players/gamemodes/"
    if ( SERVER ) then
        include( dirPath .. "sv_gamemode_base.lua" )
        print( "[Experimental Players] Loaded Gamemode Base System" )
    end

    -- Then load individual gamemodes
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if luaFile == "sv_gamemode_base.lua" then continue end  -- Already loaded

        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Gamemode: " .. luaFile )
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Gamemode (Shared): " .. luaFile )
        end
    end

    -- Admin system (needs PLAYER)
    local dirPath = "experimental_players/admin/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Admin Module: " .. luaFile )
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Admin Module (Shared): " .. luaFile )
        end
    end

    -- Compatibility layer for Lambda addons
    local dirPath = "experimental_players/compatibility/"
    for _, luaFile in ipairs( file_Find( dirPath .. "*.lua", "LUA", "nameasc" ) ) do
        if string_StartWith( luaFile, "sv_" ) then
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Compatibility Module (Server): " .. luaFile )
        elseif string_StartWith( luaFile, "sh_" ) then
            if ( SERVER ) then AddCSLuaFile( dirPath .. luaFile ) end
            include( dirPath .. luaFile )
            print( "[Experimental Players] Loaded Compatibility Module (Shared): " .. luaFile )
        end
    end

    print( "[Experimental Players] All extension modules loaded" )

    if ( SERVER ) then
        if IsValid( caller ) then
            PrintMessage( HUD_PRINTTALK, "SERVER has reloaded all Experimental Players files" )
        end

        if initialized then
            net_Start( "exp_reloadfiles" )
            net_Broadcast()
        end
        initialized = true
    end

    print( "[Experimental Players] Initialization complete!" )
end
EXP:LoadFiles()

--

EXP.InitUpdatedData = false
EXP.ActiveBots = {}

function EXP:UpdateData()
    if ( SERVER ) then
        -- Create default data files if they don't exist
        if !file_Exists( "experimental_players/npclist.json", "DATA" ) then
            -- Will be populated later
            self.FILE:WriteFile( "experimental_players/npclist.json", {} )
        end

        if !file_Exists( "experimental_players/entitylist.json", "DATA" ) then
            self.FILE:WriteFile( "experimental_players/entitylist.json", {} )
        end

        if !file_Exists( "experimental_players/proplist.json", "DATA" ) then
            self.FILE:WriteFile( "experimental_players/proplist.json", {} )
        end
    end

    -- Run data update functions
    if self.DataUpdateFuncs then
        for name, func in pairs( self.DataUpdateFuncs ) do
            if name == "weapons" and !self.InitUpdatedData then continue end
            func()
        end
    end

    if ( SERVER ) then
        -- Update player models
        if self.UpdatePlayerModels then
            self:UpdatePlayerModels()
        end

        -- Create weapon permissions file
        if !file_Exists( "experimental_players/weaponpermissions.json", "DATA" ) then
            if self.WeaponList then
                local permTbl = {}
                for wepClass, _ in pairs( self.WeaponList ) do
                    permTbl[ wepClass ] = true
                end
                self.FILE:WriteFile( "experimental_players/weaponpermissions.json", permTbl, "json" )
            end
        end
    end

    self.InitUpdatedData = true
end
if EXP.FILE then
    EXP:UpdateData()
end

--

-- Register in spawn menu
list_Set( "NPC", "exp_spawner", {
    Name = "Experimental Player",
    Class = "exp_spawner",
    Category = "Experimental Players"
} )

-- Console commands
concommand_Add( "exp_debug_reloadfiles", function(ply, cmd, args)
    EXP:LoadFiles(ply)
end )

concommand_Add( "exp_spawn", function(ply, cmd, args)
    if !IsValid(ply) or !ply:IsSuperAdmin() then return end
    if ( SERVER ) and EXP.CreateLambdaPlayer then
        local name = args[1] or "Experimental Bot"
        EXP:CreateLambdaPlayer(name)
    end
end )

concommand_Add( "exp_killall", function(ply, cmd, args)
    if !IsValid(ply) or !ply:IsSuperAdmin() then return end
    if ( SERVER ) and EXP.ActiveBots then
        local count = 0
        for _, bot in ipairs(EXP.ActiveBots) do
            if IsValid(bot._PLY) then
                bot._PLY:Kill()
                count = count + 1
            end
        end
        print("[Experimental Players] Killed " .. count .. " bots")
    end
end )

concommand_Add( "exp_removeall", function(ply, cmd, args)
    if !IsValid(ply) or !ply:IsSuperAdmin() then return end
    if ( SERVER ) and EXP.ActiveBots then
        local count = 0
        for _, bot in ipairs(EXP.ActiveBots) do
            if IsValid(bot._PLY) then
                bot._PLY:Kick("Removed by admin")
                count = count + 1
            end
        end
        EXP.ActiveBots = {}
        print("[Experimental Players] Removed " .. count .. " bots")
    end
end )

concommand_Add( "exp_listweapons", function(ply, cmd, args)
    if !IsValid(ply) or !ply:IsSuperAdmin() then return end
    if ( SERVER ) then
        print("[Experimental Players] Available Weapons:")
        local count = 0
        for weaponName, weaponData in pairs(_EXPERIMENTALPLAYERSWEAPONS or {}) do
            if !weaponData.cantbeselected then
                local wepType = weaponData.ismelee and "Melee" or "Ranged"
                local lethal = weaponData.islethal and "Lethal" or "Non-Lethal"
                print("  - " .. weaponName .. " (" .. weaponData.prettyname .. ") [" .. wepType .. ", " .. lethal .. "]")
                count = count + 1
            end
        end
        print("[Experimental Players] Total: " .. count .. " weapons")
    end
end )

concommand_Add( "exp_debug_combat", function(ply, cmd, args)
    if !IsValid(ply) or !ply:IsSuperAdmin() then return end
    if ( SERVER ) and EXP.ActiveBots then
        for _, bot in ipairs(EXP.ActiveBots) do
            if IsValid(bot._PLY) then
                local ply_bot = bot._PLY
                print("[EXP DEBUG] " .. ply_bot:Nick() .. ":")
                print("  State: " .. tostring(ply_bot.exp_State))
                print("  Enemy: " .. tostring(ply_bot.exp_Enemy))
                print("  Health: " .. ply_bot:Health() .. "/" .. ply_bot:GetMaxHealth())
                print("  Weapon: " .. tostring(ply_bot.exp_CurrentWeapon))
                if IsValid(ply_bot.exp_Enemy) then
                    local threat = ply_bot:AssessThreat(ply_bot.exp_Enemy)
                    print("  Threat Level: " .. math.floor(threat))
                end
            end
        end
    end
end )

print( "[Experimental Players] v1.0 - PlayerBot AI System Loaded" )
print( "[Experimental Players] Type 'exp_spawn <name>' to spawn a bot" )
