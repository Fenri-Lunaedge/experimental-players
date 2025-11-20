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

EXP:CreateConVar( "combat_attackplayers", 0, "Allow bots to attack real players", {
    name = "Attack Players",
    category = "Combat"
} )

EXP:CreateConVar( "combat_attackbots", 0, "Allow bots to attack each other (FFA mode)", {
    name = "Attack Bots",
    category = "Combat"
} )

EXP:CreateConVar( "combat_attacknpcs", 1, "Allow bots to attack NPCs", {
    name = "Attack NPCs",
    category = "Combat"
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

-- Death and Respawn Settings
EXP:CreateConVar( "death_respawntime", 5, "Time in seconds before bot respawns", {
    name = "Respawn Time",
    category = "Death",
    min = 0,
    max = 60
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

-- Additional Combat Settings
EXP:CreateConVar( "combat_attackrate", 0.5, "Time between attacks in seconds", {
    name = "Attack Rate",
    category = "Combat",
    min = 0.1,
    max = 2.0
} )

EXP:CreateConVar( "combat_retreatthreshold", 40, "Health percentage when bots retreat", {
    name = "Retreat Threshold",
    category = "Combat",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "combat_cover", 1, "Enable cover-seeking system", {
    name = "Cover System",
    category = "Combat"
} )

EXP:CreateConVar( "combat_friendlyfire", 0, "Allow friendly fire damage", {
    name = "Friendly Fire",
    category = "Combat"
} )

-- Additional Social Settings
EXP:CreateConVar( "social_chatfrequency", 30, "Chat message frequency (0-100)", {
    name = "Chat Frequency",
    category = "Social",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "social_voice", 1, "Enable voice lines", {
    name = "Voice Lines",
    category = "Social"
} )

EXP:CreateConVar( "social_voicepitchmin", 80, "Minimum voice pitch", {
    name = "Voice Pitch Min",
    category = "Social",
    min = 50,
    max = 150
} )

EXP:CreateConVar( "social_voicepitchmax", 120, "Maximum voice pitch", {
    name = "Voice Pitch Max",
    category = "Social",
    min = 50,
    max = 150
} )

EXP:CreateConVar( "social_tauntonkill", 1, "Bots taunt after kills", {
    name = "Taunt on Kill",
    category = "Social"
} )

-- Additional Building Settings
EXP:CreateConVar( "building_maxentities", 10, "Maximum entities per bot", {
    name = "Max Entities",
    category = "Building",
    min = 0,
    max = 20
} )

EXP:CreateConVar( "building_maxnpcs", 5, "Maximum NPCs per bot", {
    name = "Max NPCs",
    category = "Building",
    min = 0,
    max = 10
} )

EXP:CreateConVar( "building_toolgun", 1, "Enable toolgun for bots", {
    name = "Toolgun Enabled",
    category = "Building"
} )

-- Personality Settings
EXP:CreateConVar( "personality_enabled", 1, "Enable personality system", {
    name = "Personality System",
    category = "Personality"
} )

EXP:CreateConVar( "personality_aggressive", 20, "Aggressive personality weight", {
    name = "Aggressive Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "personality_defensive", 20, "Defensive personality weight", {
    name = "Defensive Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "personality_tactical", 20, "Tactical personality weight", {
    name = "Tactical Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "personality_joker", 10, "Joker personality weight", {
    name = "Joker Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "personality_silent", 15, "Silent personality weight", {
    name = "Silent Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

EXP:CreateConVar( "personality_support", 15, "Support personality weight", {
    name = "Support Weight",
    category = "Personality",
    min = 0,
    max = 100
} )

-- Weapon Permissions
EXP:CreateConVar( "weapon_crowbar", 1, "Allow Crowbar", { category = "Weapons" } )
EXP:CreateConVar( "weapon_stunstick", 1, "Allow Stun Stick", { category = "Weapons" } )
EXP:CreateConVar( "weapon_pistol", 1, "Allow Pistol", { category = "Weapons" } )
EXP:CreateConVar( "weapon_357", 1, "Allow .357 Magnum", { category = "Weapons" } )
EXP:CreateConVar( "weapon_smg1", 1, "Allow SMG1", { category = "Weapons" } )
EXP:CreateConVar( "weapon_ar2", 1, "Allow AR2", { category = "Weapons" } )
EXP:CreateConVar( "weapon_shotgun", 1, "Allow Shotgun", { category = "Weapons" } )
EXP:CreateConVar( "weapon_crossbow", 1, "Allow Crossbow", { category = "Weapons" } )
EXP:CreateConVar( "weapon_rpg", 1, "Allow RPG", { category = "Weapons" } )
EXP:CreateConVar( "weapon_grenade", 1, "Allow Grenade", { category = "Weapons" } )
EXP:CreateConVar( "weapon_slam", 1, "Allow SLAM", { category = "Weapons" } )
EXP:CreateConVar( "weapon_gravgun", 1, "Allow Gravity Gun", { category = "Weapons" } )
EXP:CreateConVar( "weapon_physgun", 1, "Allow Physics Gun", { category = "Weapons" } )
EXP:CreateConVar( "weapon_toolgun", 1, "Allow Tool Gun", { category = "Weapons" } )

-- General Settings
EXP:CreateConVar( "maxbots", 32, "Maximum number of bots allowed", {
    name = "Max Bots",
    category = "General",
    min = 0,
    max = 128
} )

EXP:CreateConVar( "respawn_time", 5, "Bot respawn time in seconds", {
    name = "Respawn Time",
    category = "General",
    min = 0,
    max = 60
} )

EXP:CreateConVar( "ai_thinkrate", 0.1, "AI think rate in seconds", {
    name = "AI Think Rate",
    category = "General",
    min = 0.05,
    max = 1.0
} )

-- Admin Bot Settings
EXP:CreateConVar( "admin_banduration", 10, "Admin ban duration in minutes", {
    name = "Ban Duration",
    category = "Admin",
    min = 1,
    max = 60
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
