-- Experimental Players - Console Variables
-- Adapted from GLambda Players

local CreateConVar = CreateConVar
local concommand_Add = concommand.Add
local string_sub = string.sub

--[[ ConVar System ]]--

EXP.ConVars = ( EXP.ConVars or {} )
EXP.ConCommands = ( EXP.ConCommands or {} )

function EXP:CreateConVar( name, default, desc, data )
    local fullName = "exp_" .. name
    local cvar = CreateConVar( fullName, default, FCVAR_ARCHIVE + FCVAR_REPLICATED, desc, data.min, data.max )

    self.ConVars[ name ] = {
        cvar = cvar,
        name = ( data and data.name or name ),
        category = ( data and data.category or "Uncategorized" ),
        desc = desc
    }

    return cvar
end

function EXP:GetConVar( name )
    local cvarData = self.ConVars[ name ]
    if !cvarData then return nil end
    return cvarData.cvar:GetInt()
end

function EXP:CreateConCommand( name, func, isClient, desc, data )
    local fullName = "exp_" .. name
    concommand_Add( fullName, func, nil, desc )

    self.ConCommands[ name ] = {
        name = ( data and data.name or name ),
        category = ( data and data.category or "Uncategorized" ),
        desc = desc,
        isClient = isClient
    }
end

--[[ Core ConVars ]]--

-- Player Settings
EXP:CreateConVar( "player_addonplymdls", 1, "If Experimental Players should use addon player models", {
    name = "Use Addon Player Models",
    category = "Player Settings"
} )

EXP:CreateConVar( "player_onlyaddonpms", 0, "If Experimental Players should only use addon player models", {
    name = "Only Use Addon Player Models",
    category = "Player Settings"
} )

EXP:CreateConVar( "player_voicepopups", 1, "Display voice popups when players speak", {
    name = "Voice Popups",
    category = "Player Settings"
} )

-- Combat Settings
EXP:CreateConVar( "combat_range", 2000, "Maximum combat engagement range", {
    name = "Combat Range",
    category = "Combat",
    min = 100,
    max = 10000
} )

EXP:CreateConVar( "combat_accuracy", 75, "Bot aiming accuracy (0-100)", {
    name = "Accuracy",
    category = "Combat",
    min = 0,
    max = 100
} )

-- Navigation Settings
EXP:CreateConVar( "nav_updaterate", 0.1, "Navigation update rate in seconds", {
    name = "Navigation Update Rate",
    category = "Navigation",
    min = 0.01,
    max = 1.0
} )

EXP:CreateConVar( "nav_jumpgaps", 1, "Allow bots to jump over gaps", {
    name = "Jump Over Gaps",
    category = "Navigation"
} )

-- Social Settings
EXP:CreateConVar( "social_textchat", 1, "Enable text chat", {
    name = "Text Chat",
    category = "Social"
} )

EXP:CreateConVar( "social_voicechat", 1, "Enable voice lines", {
    name = "Voice Chat",
    category = "Social"
} )

EXP:CreateConVar( "social_conversations", 1, "Enable bot conversations", {
    name = "Conversations",
    category = "Social"
} )

-- Building Settings
EXP:CreateConVar( "building_enabled", 1, "Allow bots to build/spawn props", {
    name = "Building Enabled",
    category = "Building"
} )

EXP:CreateConVar( "building_maxprops", 10, "Maximum props per bot", {
    name = "Max Props",
    category = "Building",
    min = 0,
    max = 50
} )

EXP:CreateConVar( "building_caneditworld", 0, "Allow bots to edit map entities", {
    name = "Can Edit World",
    category = "Building"
} )

EXP:CreateConVar( "building_caneditothers", 0, "Allow bots to edit other players' entities", {
    name = "Can Edit Others",
    category = "Building"
} )

-- Admin Settings
EXP:CreateConVar( "admin_enabled", 1, "Enable admin bot system", {
    name = "Admin Enabled",
    category = "Admin"
} )

EXP:CreateConVar( "admin_spawnchance", 10, "Chance for a bot to spawn as admin (0-100)", {
    name = "Admin Spawn Chance",
    category = "Admin",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "admin_strictnessmin", 30, "Minimum strictness for admin bots", {
    name = "Min Strictness",
    category = "Admin",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "admin_strictnessmax", 70, "Maximum strictness for admin bots", {
    name = "Max Strictness",
    category = "Admin",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "admin_detectrdm", 1, "Allow admins to detect RDM", {
    name = "Detect RDM",
    category = "Admin"
} )

EXP:CreateConVar( "admin_detectpropkill", 1, "Allow admins to detect prop killing", {
    name = "Detect Prop Kills",
    category = "Admin"
} )

-- Utility
EXP:CreateConVar( "util_mergelambdafiles", 1, "Merge Lambda Players files (for compatibility)", {
    name = "Merge Lambda Files",
    category = "Utility"
} )

EXP:CreateConVar( "util_debug", 0, "Enable debug mode", {
    name = "Debug Mode",
    category = "Utility"
} )

print( "[Experimental Players] ConVars loaded" )
