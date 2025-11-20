-- Experimental Players - File System
-- Adapted from GLambda Players

local file_CreateDir = file.CreateDir
local file_Open = file.Open
local file_Delete = file.Delete
local util_TableToJSON = util.TableToJSON
local util_Compress = util.Compress
local util_JSONToTable = util.JSONToTable
local util_Decompress = util.Decompress
local table_insert = table.insert
local pairs = pairs
local file_Exists = file.Exists
local table_HasValue = table.HasValue
local table_RemoveByValue = table.RemoveByValue
local file_Find = file.Find
local ipairs = ipairs
local IsValid = IsValid
local CurTime = CurTime
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteBool = net.WriteBool
local net_Broadcast = SERVER and net.Broadcast
local table_Add = table.Add
local string_EndsWith = string.EndsWith
local string_Explode = string.Explode
local string_StripExtension = string.StripExtension
local ErrorNoHalt = ErrorNoHalt

--[[ File System ]]--

EXP.FILE = {}
local FILE = EXP.FILE

file_CreateDir( "experimental_players" )

--[[ Core File Operations ]]--

function FILE:WriteFile( filename, content, type )
    local f = file_Open( filename, ( ( type == "binary" or type == "compressed" ) and "wb" or "w" ), "DATA" )
    if !f then return end

    if type == "json" then
        content = util_TableToJSON( content, true )
    elseif type == "compressed" then
        content = util_TableToJSON( content )
        content = util_Compress( content )
    end

    f:Write( content )
    f:Close()
end

function FILE:ReadFile( filename, type, path )
    local f = file_Open( filename, ( type == "compressed" and "rb" or "r" ), ( path or "DATA" ) )
    if !f then return end

    local str = f:Read( f:Size() )
    f:Close()

    if str and #str  ~=  0 then
        if type == "json" then
            str = util_JSONToTable( str ) or {}
        elseif type == "compressed" then
            str = util_Decompress( str ) or ""
            str = util_JSONToTable( str ) or {}
        end
    end
    return str
end

function FILE:DeleteFile( filename )
    file_Delete( filename, "DATA" )
end

--[[ File Update Functions ]]--

function FILE:UpdateSequentialFile( filename, addcontent, type )
    local contents = FILE:ReadFile( filename, type, "DATA" )
    if contents then
        table_insert( contents, addcontent )
        FILE:WriteFile( filename, contents, type )
    else
        FILE:WriteFile( filename, { addcontent }, type )
    end
end

function FILE:UpdateKeyValueFile( filename, addcontent, type )
    local contents = FILE:ReadFile( filename, type, "DATA" )
    if contents then
        for k, v in pairs( addcontent ) do contents[ k ] = v end
        FILE:WriteFile( filename, contents, type )
    else
        local tbl = {}
        for k, v in pairs( addcontent ) do tbl[ k ] = v end
        FILE:WriteFile( filename, tbl, type )
    end
end

function FILE:FileHasValue( filename, value, type )
    if !file_Exists( filename, "DATA" ) then return false end
    local contents = FILE:ReadFile( filename, type, "DATA" )
    return table_HasValue( contents, value )
end

function FILE:FileKeyIsValid( filename, key, type )
    if !file_Exists( filename, "DATA" ) then return false end
    local contents = FILE:ReadFile( filename, type, "DATA" )
    return contents[ key ]  ~=  nil
end

function FILE:RemoveVarFromSQFile( filename, var, type )
    local contents = FILE:ReadFile( filename, type, "DATA" )
    table_RemoveByValue( contents, var )
    FILE:WriteFile( filename, contents, type )
end

function FILE:RemoveVarFromKVFile( filename, key, type )
    local contents = FILE:ReadFile( filename, type, "DATA" )
    contents[ key ] = nil
    FILE:WriteFile( filename, contents, type )
end

--[[ Directory Merging ]]--

function FILE:MergeDirectory( dir, tbl, path, addDirs, addFunc )
    if dir[ #dir ]  ~=  "/" then dir = dir .. "/" end
    tbl = ( tbl or {} )

    local files, dirs = file_Find( dir .. "*", ( path or "GAME" ), "nameasc" )
    if files then
        for _, fileName in ipairs( files ) do
            if addFunc then addFunc( fileName, dir, tbl ) continue end
            tbl[ #tbl + 1 ] = dir .. fileName
        end
    end
    if dirs and ( addDirs == nil or addDirs == true ) then
        for _, addDir in ipairs( dirs ) do self:MergeDirectory( dir .. addDir, tbl ) end
    end

    return tbl
end

--[[ Data Update System ]]--

EXP.DataUpdateFuncs = ( EXP.DataUpdateFuncs or {} )

function FILE:CreateUpdateCommand( name, func, isClient, desc, settingName, reloadMenu )
    local dataUpdCooldown = 0
    local function cmdFunc( ply )
        if !isClient and IsValid( ply ) then
            if !ply:IsSuperAdmin() then
                EXP:SendNotification( ply, "You must be a super admin in order to use this!", 1, nil, "buttons/button10.wav" )
                return
            end
            if CurTime() < dataUpdCooldown then
                EXP:SendNotification( ply, "Command is on cooldown! Please wait 3 seconds before trying again", 1, nil, "buttons/button10.wav" )
                return
            end

            dataUpdCooldown = ( CurTime() + 3 )
            EXP:SendNotification( ply, "Updated Data for " .. settingName .. "!", 3, nil, "buttons/button15.wav" )
        end

        func()

        if !isClient and ( SERVER ) then
            net_Start( "exp_updatedata" )
                net_WriteString( name )
                net_WriteBool( reloadMenu )
            net_Broadcast()
        end
    end

    EXP:CreateConCommand( "cmd_updatedata_" .. name, cmdFunc, isClient, desc, { name = "Update " .. settingName, category = "Data Updating" } )
    EXP.DataUpdateFuncs[ name ] = cmdFunc
end

--[[ Default Data Update Commands ]]--

-- Names
FILE:CreateUpdateCommand( "names", function()
    local defaultNames = FILE:ReadFile( "materials/glambdaplayers/data/names.vmt", "json", "GAME" ) or {}
    local customNames = FILE:ReadFile( "experimental_players/customnames.json", "json" ) or {}

    local mergeTbl = table_Add( defaultNames, customNames )
    EXP.Nicknames = mergeTbl
end, false, "Updates the list of nicknames the players will use as names.", "Nicknames" )

-- Profile Pictures
FILE:CreateUpdateCommand( "pfps", function()
    local pfps = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/custompfps/", pfps )
    FILE:MergeDirectory( "materials/lambdaplayers/custom_profilepictures/", pfps )
    EXP.ProfilePictures = pfps
end, false, "Updates the list of profile pictures the players will spawn with.", "Profile Pictures" )

-- Voice Lines
FILE:CreateUpdateCommand( "voicelines", function()
    local voiceLines = {}
    for _, data in ipairs( EXP.VoiceTypes ) do
        local lineTbl = FILE:MergeDirectory( "sound/" .. data.pathCvar:GetString() )
        voiceLines[ data.name ] = lineTbl
    end
    EXP.VoiceLines = voiceLines
end, false, "Updates the list of voicelines the players will use to speak in voice chat.", "Voicelines" )

-- Voice Profiles
local function MergeVoiceProfiles( tbl, path )
    local fullPath = "sound/" .. path
    local _, profileFiles = file_Find( fullPath .. "*", "GAME", "nameasc" )
    if !profileFiles then return end

    for _, profile in ipairs( profileFiles ) do
        local profileTbl = {}

        for _, data in ipairs( EXP.VoiceTypes ) do
            local typeName = data.name
            local typePath = fullPath .. profile .. "/" .. typeName .. "/"

            local voicelines = file_Find( typePath .. "*", "GAME", "nameasc" )
            if !voicelines or #voicelines == 0 then continue end

            local lineTbl = FILE:MergeDirectory( typePath )
            profileTbl[ typeName ] = lineTbl
        end

        tbl[ profile ] = profileTbl
    end
end

FILE:CreateUpdateCommand( "voiceprofiles", function()
    local voiceProfiles = {}
    MergeVoiceProfiles( voiceProfiles, "glambdaplayers/voiceprofiles/" )
    MergeVoiceProfiles( voiceProfiles, "lambdaplayers/voiceprofiles/" )
    EXP.VoiceProfiles = voiceProfiles
end, false, "Updates the list of voice profiles the players will use to speak as.", "Voice Profiles", true )

-- Text Messages
local function MergeTextMessages( fileName, fileDir, tbl )
    local content = FILE:ReadFile( fileDir .. fileName, "json", "GAME" )
    if !content then
        local txtContents = FILE:ReadFile( fileDir .. fileName, nil, "GAME" )
        if !txtContents then return end
        content = string_Explode( "\n", txtContents )
    end

    local name = string_StripExtension( fileName )
    local textType = string_Explode( "_", name )[ 1 ]

    local typeTbl = ( tbl[ textType ] or {} )
    table_Add( typeTbl, content )
    tbl[ textType ] = typeTbl
end

FILE:CreateUpdateCommand( "textmsgs", function()
    local textTbl = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/texttypes/", textTbl, nil, nil, MergeTextMessages )
    FILE:MergeDirectory( "experimental_players/texttypes/", textTbl, "DATA", nil, MergeTextMessages )
    EXP.TextMessages = textTbl
end, false, "Updates the list of text messages the players will use to speak in text chat.", "Text Messages" )

-- Sprays
FILE:CreateUpdateCommand( "sprays", function()
    local sprayTbl = {}
    FILE:MergeDirectory( "materials/glambdaplayers/data/sprays/", sprayTbl )
    FILE:MergeDirectory( "materials/lambdaplayers/sprays/", sprayTbl )
    EXP.Sprays = sprayTbl
end, false, "Updates the list of images and materials the players will use as their spray.", "Sprays" )

-- Player Profiles
FILE:CreateUpdateCommand( "profiles", function()
    EXP.PlayerProfiles = FILE:ReadFile( "experimental_players/profiles.json", "json" ) or {}
end, false, "Updates the list of player profiles.", "Player Profiles" )

-- Spawn Lists
FILE:CreateUpdateCommand( "proplist", function()
    local content = FILE:ReadFile( "experimental_players/proplist.json", "json" )
    if !content or #content == 0 then
        print( "[Experimental Players] Note: No custom props list found. Bots will use default props." )
    end
    EXP.SpawnlistProps = ( content or {} )
end, false, "Updates the spawnlist of props the players can spawn from their spawnmenu.", "Spawnmenu Props" )

FILE:CreateUpdateCommand( "entitylist", function()
    local content = FILE:ReadFile( "experimental_players/entitylist.json", "json" )
    if !content or #content == 0 then
        print( "[Experimental Players] Note: No custom entities list found. Entity spawning disabled." )
    end
    EXP.SpawnlistENTs = ( content or {} )
end, false, "Updates the spawnlist of entities the players can spawn from their spawnmenu.", "Spawnmenu Entities" )

FILE:CreateUpdateCommand( "npclist", function()
    local content = FILE:ReadFile( "experimental_players/npclist.json", "json" )
    if !content or #content == 0 then
        print( "[Experimental Players] Note: No custom NPCs list found. Bots will use default NPCs." )
    end
    EXP.SpawnlistNPCs = ( content or {} )
end, false, "Updates the spawnlist of NPCs the players can spawn from their spawnmenu.", "Spawnmenu NPCs" )

print( "[Experimental Players] File system loaded" )
