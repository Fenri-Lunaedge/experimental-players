-- Experimental Players - Global Functions and Data
-- Adapted from GLambda Players

local table_Empty = table.Empty
local pairs = pairs
local player_manager_AllValidModels = player_manager.AllValidModels
local ipairs = ipairs
local table_remove = table.remove
local string_EndsWith = string.EndsWith
local Material = Material
local CreateMaterial = CreateMaterial
local string_sub = string.sub
local notification_AddLegacy = CLIENT and notification.AddLegacy
local surface_PlaySound = CLIENT and surface.PlaySound
local net_Start = net.Start
local net_WriteString = net.WriteString
local net_WriteUInt = net.WriteUInt
local net_WriteFloat = net.WriteFloat
local net_Send = SERVER and net.Send
local math_randomseed = math.randomseed
local os_time = os.time
local SysTime = SysTime
local math_random = math.random
local math_Rand = math.Rand
local string_upper = string.upper
local pcall = pcall
local hook_GetTable = hook.GetTable
local ErrorNoHaltWithStack = ErrorNoHaltWithStack
local unpack = unpack

--[[ Attachment Point System ]]--
-- Based on Lambda Players attachment system

function EXP:GetAttachmentPoint( ent, pointType )
    if !IsValid( ent ) then return nil end

    -- FIX: Update bones before getting attachments to ensure accurate positions
    ent:SetupBones()

    local attachData = {
        Pos = ent:WorldSpaceCenter(),
        Ang = ent:GetAngles(),
        Index = 0,
        Bone = nil
    }

    if pointType == "hand" then
        -- Try right hand attachment first (preferred method)
        local lookup = ent:LookupAttachment( "anim_attachment_RH" )
        if lookup and lookup > 0 then
            local handAttach = ent:GetAttachment( lookup )
            if handAttach then
                attachData.Pos = handAttach.Pos
                attachData.Ang = handAttach.Ang
                attachData.Index = lookup
                return attachData
            end
        end

        -- Fallback to right hand bone
        local bone = ent:LookupBone( "ValveBiped.Bip01_R_Hand" )
        if bone then
            local bonePos, boneAng = ent:GetBonePosition( bone )
            if bonePos then
                attachData.Pos = bonePos
                attachData.Ang = boneAng
                attachData.Bone = bone
            end
        end
    elseif pointType == "eyes" then
        -- Try eyes attachment first
        local lookup = ent:LookupAttachment( "eyes" )
        if lookup and lookup > 0 then
            local eyeAttach = ent:GetAttachment( lookup )
            if eyeAttach then
                attachData.Pos = eyeAttach.Pos
                attachData.Ang = eyeAttach.Ang
                attachData.Index = lookup
                return attachData
            end
        end

        -- Fallback: use player eye position
        if ent:IsPlayer() then
            attachData.Pos = ent:EyePos()
            attachData.Ang = ent:EyeAngles()
        end
    end

    return attachData
end

--[[ Player Models ]]--

if ( SERVER ) then

    EXP.PlayerModels = ( EXP.PlayerModels or {
        Default = {
            "models/player/alyx.mdl",
            "models/player/arctic.mdl",
            "models/player/barney.mdl",
            "models/player/breen.mdl",
            "models/player/charple.mdl",
            "models/player/combine_soldier.mdl",
            "models/player/combine_soldier_prisonguard.mdl",
            "models/player/combine_super_soldier.mdl",
            "models/player/corpse1.mdl",
            "models/player/dod_american.mdl",
            "models/player/dod_german.mdl",
            "models/player/eli.mdl",
            "models/player/gasmask.mdl",
            "models/player/gman_high.mdl",
            "models/player/guerilla.mdl",
            "models/player/kleiner.mdl",
            "models/player/leet.mdl",
            "models/player/odessa.mdl",
            "models/player/phoenix.mdl",
            "models/player/police.mdl",
            "models/player/police_fem.mdl",
            "models/player/riot.mdl",
            "models/player/skeleton.mdl",
            "models/player/soldier_stripped.mdl",
            "models/player/swat.mdl",
            "models/player/urban.mdl",
            "models/player/hostage/hostage_01.mdl",
            "models/player/hostage/hostage_02.mdl",
            "models/player/hostage/hostage_03.mdl",
            "models/player/hostage/hostage_04.mdl",
            "models/player/Group01/female_01.mdl",
            "models/player/Group01/female_02.mdl",
            "models/player/Group01/female_03.mdl",
            "models/player/Group01/female_04.mdl",
            "models/player/Group01/female_05.mdl",
            "models/player/Group01/female_06.mdl",
            "models/player/Group01/male_01.mdl",
            "models/player/Group01/male_02.mdl",
            "models/player/Group01/male_03.mdl",
            "models/player/Group01/male_04.mdl",
            "models/player/Group01/male_05.mdl",
            "models/player/Group01/male_06.mdl",
            "models/player/Group01/male_07.mdl",
            "models/player/Group01/male_08.mdl",
            "models/player/Group01/male_09.mdl",
            "models/player/Group02/male_02.mdl",
            "models/player/Group02/male_04.mdl",
            "models/player/Group02/male_06.mdl",
            "models/player/Group02/male_08.mdl",
            "models/player/Group03/female_01.mdl",
            "models/player/Group03/female_02.mdl",
            "models/player/Group03/female_03.mdl",
            "models/player/Group03/female_04.mdl",
            "models/player/Group03/female_05.mdl",
            "models/player/Group03/female_06.mdl",
            "models/player/Group03/male_01.mdl",
            "models/player/Group03/male_02.mdl",
            "models/player/Group03/male_03.mdl",
            "models/player/Group03/male_04.mdl",
            "models/player/Group03/male_05.mdl",
            "models/player/Group03/male_06.mdl",
            "models/player/Group03/male_07.mdl",
            "models/player/Group03/male_08.mdl",
            "models/player/Group03/male_09.mdl",
            "models/player/Group03m/female_01.mdl",
            "models/player/Group03m/female_02.mdl",
            "models/player/Group03m/female_03.mdl",
            "models/player/Group03m/female_04.mdl",
            "models/player/Group03m/female_05.mdl",
            "models/player/Group03m/female_06.mdl",
            "models/player/Group03m/male_01.mdl",
            "models/player/Group03m/male_02.mdl",
            "models/player/Group03m/male_03.mdl",
            "models/player/Group03m/male_04.mdl",
            "models/player/Group03m/male_05.mdl",
            "models/player/Group03m/male_06.mdl",
            "models/player/Group03m/male_07.mdl",
            "models/player/Group03m/male_08.mdl",
            "models/player/Group03m/male_09.mdl",
            "models/player/zombie_soldier.mdl",
            "models/player/p2_chell.mdl",
            "models/player/mossman.mdl",
            "models/player/mossman_arctic.mdl",
            "models/player/magnusson.mdl",
            "models/player/monk.mdl",
            "models/player/zombie_classic.mdl",
            "models/player/zombie_fast.mdl"
        },
        Addons = {}
    } )

    function EXP:UpdatePlayerModels()
        table_Empty( self.PlayerModels.Addons )
        local blockList = self.FILE:ReadFile( "experimental_players/pmblocklist.json", "json" )

        for _, mdl in pairs( player_manager_AllValidModels() ) do
            local isDefaultMdl = false
            for _, defMdl in ipairs( self.PlayerModels.Default ) do
                if mdl  ~=  defMdl then continue end
                isDefaultMdl = true; break
            end
            if isDefaultMdl then continue end

            if blockList then
                local isBlocked = false
                for k, blockedMdl in ipairs( blockList ) do
                    if mdl  ~=  blockedMdl then continue end
                    table_remove( blockList, k )
                    isBlocked = true; break
                end
                if isBlocked then continue end
            end

            self.PlayerModels.Addons[ #self.PlayerModels.Addons + 1 ] = mdl
        end
    end

    function EXP:GetRandomPlayerModel()
        local mdlTbl = self.PlayerModels
        if !mdlTbl or !mdlTbl.Default then
            -- Fallback if PlayerModels not initialized
            return "models/player/group01/male_0" .. math.random(1,9) .. ".mdl"
        end

        local mdlList = mdlTbl.Default

        local defCount = #mdlList
        if defCount == 0 then
            -- No models in list, use fallback
            return "models/player/group01/male_0" .. math.random(1,9) .. ".mdl"
        end

        local mdlCount = defCount
        local useConVar = self.GetConVar and self:GetConVar( "player_addonplymdls" )
        if useConVar and useConVar == 1 then
            local onlyAddons = self:GetConVar( "player_onlyaddonpms" )
            if onlyAddons and onlyAddons == 1 then
                mdlList = mdlTbl.Addons
                if #mdlList  ~=  0 then return EXP:Random( mdlList ) end
            end

            mdlCount = ( mdlCount + #mdlTbl.Addons )
        end

        local mdlIndex = EXP:Random( mdlCount )
        if mdlIndex > defCount then
            mdlIndex = ( mdlIndex - defCount )
            mdlList = mdlTbl.Addons
        end

        local selectedModel = mdlList[ mdlIndex ]

        -- Safety check
        if !selectedModel or selectedModel == "" then
            return mdlTbl.Default[ 1 ] or "models/player/group01/male_01.mdl"
        end

        return selectedModel
    end

end

--[[ Client Initialization ]]--

if ( CLIENT ) then

    function EXP:InitializeLambda( ply, pfp )
        ply.exp_IsExperimentalPlayer = true
        ply.exp_IsVoiceMuted = false

        if !string_EndsWith( pfp, ".vtf" ) then
            pfp = Material( pfp )
        else
            pfp = CreateMaterial( "EXP_PfpMaterial_" .. pfp, "UnlitGeneric", {
                [ "$baseTexture" ] = pfp,
                [ "$translucent" ] = 1,

                [ "Proxies" ] = {
                    [ "AnimatedTexture" ] = {
                        [ "animatedTextureVar" ] = "$baseTexture",
                        [ "animatedTextureFrameNumVar" ] = "$frame",
                        [ "animatedTextureFrameRate" ] = 10
                    }
                }
            } )

            if !pfp or pfp:IsError() then
                local plyMdl = ply:GetModel()
                pfp = Material( "spawnicons/" .. string_sub( plyMdl, 1, #plyMdl - 4 ) .. ".png" )
            end
        end
        ply.exp_ProfilePicture = pfp

        self:RunHook( "EXP_OnPlayerInitialize", ply )
    end

end

--[[ Profile Information ]]--

local infoTranslations = {
    [ "Name" ]              = "name",
    [ "PlayerModel" ]       = "model",
    [ "ProfilePicture" ]    = "profilepicture",
    [ "PlayerColor" ]       = "plycolor",
    [ "WeaponColor" ]       = "physcolor",
    [ "VoicePitch" ]        = "voicepitch",
    [ "VoiceProfile" ]      = "voiceprofile",
    [ "TextProfile" ]       = "textprofile",
    [ "Personality" ]       = "personality",
    [ "SkinGroup" ]         = "mdlSkin",
    [ "BodyGroups" ]        = "bodygroups",
    [ "Toolgun" ]           = "Tool",
    [ "Cowardness" ]        = "Cowardly",
}

function EXP:GetProfileInfo( tbl, infoName )
    if !tbl then return end
    local info = tbl[ infoName ]
    if !info then info = tbl[ infoTranslations[ infoName ] ] end
    return info
end

--[[ Notifications ]]--

function EXP:SendNotification( ply, text, notifyType, length, snd )
    if ( CLIENT ) then
        notification_AddLegacy( text, ( notifyType or 0 ), ( length or 3 ) )
        if snd and #snd  ~=  0 then surface_PlaySound( snd ) end
    end
    if ( SERVER ) then
        net_Start( "exp_sendnotify" )
            net_WriteString( text )
            net_WriteUInt( ( notifyType or 0 ), 3 )
            net_WriteFloat( length or 3 )
            net_WriteString( snd or "" )
        net_Send( ply )
    end
end

--[[ Random Number Generation ]]--

local rngCalled = 0
function EXP:Random( min, max, float )
    rngCalled = ( rngCalled + 1 )
    if rngCalled > 32768 then rngCalled = 0 end
    math_randomseed( os_time() + SysTime() + rngCalled )

    if !min and !max then return math_random() end
    if istable( min ) then return min[ math_random( #min ) ] end
    return ( float and math_Rand( min, max ) or ( max and math_random( min, max ) or math_random( min ) ) )
end

--[[ Hook System ]]--

EXP.HookTable = {
    "OnPlayerSelectWeapon",
    "OnPlayerOtherKilled",
    "OnPlayerKilled",
    "OnPlayerHurt",
    "OnPlayerThink",
    "OnPlayerChangeState",
    "OnPlayerCanTarget",
    "OnPlayerCanSelectWeapon",
    "OnPlayerGetTextLine",
    "OnPlayerPlayVoiceLine",
    "OnPlayerInitialize",
    "OnPlayerRespawn",
}

function EXP:RunHook( hookName, ... )
    local hookTbl = hook_GetTable()[ hookName ]
    if !hookTbl then return end

    local args = { ... }
    local a, b, c, d, e, f

    for _, func in pairs( hookTbl ) do
        local ok, msg = pcall( function() a, b, c, d, e, f = func( unpack( args ) ) end )
        if !ok then ErrorNoHaltWithStack( msg ) end
        if a or b or c or d or e or f then break end
    end
    return a, b, c, d, e, f
end

--[[ Voice Types ]]--

EXP.VoiceTypes = {}

function EXP:AddVoiceType( typeName, defPath, voiceDesc )
    local cvar = self:CreateConVar( "voice_path_" .. typeName, defPath, "The filepath for the " .. typeName .. " voice type voicelines.\n" .. voiceDesc, {
        name = string_upper( typeName[ 1 ] ) .. string_sub( typeName, 2, #typeName ) .. " Voice Type",
        category = "Voice Type Paths"
    } )

    self.VoiceTypes[ #self.VoiceTypes + 1 ] = {
        name = typeName,
        pathCvar = cvar
    }
end

-- Default voice types
EXP:AddVoiceType( "idle",       "lambdaplayers/vo/idle/",       "Played when the player is idle and not panicking and in combat." )
EXP:AddVoiceType( "taunt",      "lambdaplayers/vo/taunt/",      "Played when the player starts attacking someone and/or is in combat." )
EXP:AddVoiceType( "death",      "lambdaplayers/vo/death/",      "Played when the player dies." )
EXP:AddVoiceType( "panic",      "lambdaplayers/vo/panic/",      "Played when the player is panicking and running away." )
EXP:AddVoiceType( "kill",       "lambdaplayers/vo/kill/",       "Played when the player kills its enemy." )
EXP:AddVoiceType( "witness",    "lambdaplayers/vo/witness/",    "Played when the player sees someone die." )
EXP:AddVoiceType( "assist",     "lambdaplayers/vo/assist/",     "Played when the player's enemy is killed by someone else." )
EXP:AddVoiceType( "laugh",      "lambdaplayers/vo/laugh/",      "Played when the player sees someone get killed and does \"act laugh\"." )
EXP:AddVoiceType( "fall",       "lambdaplayers/vo/fall/",       "Played when the player is falling." )

print( "[Experimental Players] Global functions loaded" )
