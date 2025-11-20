-- Experimental Players - Lambda Weapons Compatibility
-- Automatically imports weapons from Lambda Players and addons

--[[ Lambda Weapon Import ]]--

local function ImportLambdaWeapons()
    if !_LAMBDAPLAYERSWEAPONS then
        print( "[Experimental Players] Lambda Players weapons table not found (yet)" )
        return
    end

    local imported = 0
    local skipped = 0

    for weaponName, weaponData in pairs( _LAMBDAPLAYERSWEAPONS ) do
        -- Skip if we already have this weapon
        if _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] then
            skipped = skipped + 1
            continue
        end

        -- Import the weapon
        _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] = table.Copy( weaponData )
        imported = imported + 1
    end

    if imported > 0 then
        print( "[Experimental Players] Imported " .. imported .. " weapons from Lambda Players" )
    end
    if skipped > 0 then
        print( "[Experimental Players] Skipped " .. skipped .. " duplicate weapons" )
    end

    return imported
end

--[[ Auto Import on Initialize ]]--

hook.Add( "Initialize", "EXP_ImportLambdaWeapons", function()
    -- Wait a bit for Lambda Players to load
    timer.Simple( 2, function()
        ImportLambdaWeapons()

        -- Update weapon permissions
        if ( SERVER ) and EXP.FILE then
            local permTbl = EXP.FILE:ReadFile( "experimental_players/weaponpermissions.json", "json" )
            if !permTbl then
                permTbl = {}
            end

            -- Add permissions for new weapons
            local updated = false
            for weaponName, _ in pairs( _EXPERIMENTALPLAYERSWEAPONS ) do
                if permTbl[ weaponName ] == nil then
                    permTbl[ weaponName ] = true
                    updated = true
                end
            end

            if updated then
                EXP.FILE:WriteFile( "experimental_players/weaponpermissions.json", permTbl, "json" )
                print( "[Experimental Players] Updated weapon permissions" )
            end
        end
    end )
end )

--[[ Manual Import Command ]]--

if ( SERVER ) then
    concommand.Add( "exp_importweapons", function( ply, cmd, args )
        if IsValid( ply ) and !ply:IsSuperAdmin() then
            print( "You must be a super admin to use this command!" )
            return
        end

        local count = ImportLambdaWeapons()
        if count and count > 0 then
            print( "[Experimental Players] Manually imported " .. count .. " weapons" )
        else
            print( "[Experimental Players] No new weapons to import" )
        end
    end )
end

--[[ Addon Detection ]]--

function EXP:DetectLambdaAddons()
    local addons = {}

    -- Detect Lambda weapon addons
    if file.Exists( "lua/lambdaplayers/lambda/weapons/", "GAME" ) then
        local files = file.Find( "lua/lambdaplayers/lambda/weapons/*.lua", "GAME" )
        for _, fileName in ipairs( files ) do
            table.insert( addons, fileName )
        end
    end

    return addons
end

--[[ Compatibility Check ]]--

function EXP:CheckLambdaCompatibility()
    if !_LAMBDAPLAYERSWEAPONS then
        return false, "Lambda Players not installed"
    end

    local lambdaWeapons = table.Count( _LAMBDAPLAYERSWEAPONS )
    local expWeapons = table.Count( _EXPERIMENTALPLAYERSWEAPONS )

    return true, "Compatible - " .. lambdaWeapons .. " Lambda weapons available, " .. expWeapons .. " total weapons"
end

--[[ Zeta Players Weapon Compatibility ]]--

local function ImportZetaWeapons()
    if !ZetaWeaponConfigTable then
        print( "[Experimental Players] Zeta Players weapons table not found (yet)" )
        return 0
    end

    local imported = 0

    for weaponClass, weaponConfig in pairs( ZetaWeaponConfigTable ) do
        local weaponName = string.lower( weaponClass:gsub( "weapon_", "" ) )

        if !_EXPERIMENTALPLAYERSWEAPONS[ weaponName ] then
            _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] = {
                model = weaponConfig.mdl or "models/weapons/w_pistol.mdl",
                prettyname = weaponConfig.name or weaponName,
                origin = "Zeta Players",
                holdtype = weaponConfig.holdtype or "pistol",
                islethal = weaponConfig.lethal or true,
                ismelee = weaponConfig.melee or false,

                damage = weaponConfig.damage or 10,
                attackrange = weaponConfig.range or 2000,
                keepdistance = weaponConfig.keepdistance or 300,
                clip = weaponConfig.clip or 30,
                rateoffire = weaponConfig.firerate or 0.2,

                tracername = weaponConfig.tracer or "Tracer",
                muzzleflash = weaponConfig.muzzleflash or 1,

                dropentity = weaponClass,
            }

            imported = imported + 1
        end
    end

    if imported > 0 then
        print( "[Experimental Players] Imported " .. imported .. " weapons from Zeta Players" )
    end

    return imported
end

hook.Add( "Initialize", "EXP_ImportZetaWeapons", function()
    timer.Simple( 2.5, function()
        ImportZetaWeapons()
    end )
end )

--[[ Generic SWEP Auto-Import ]]--

local function ImportGenericSWEPs()
    local imported = 0

    -- Skip list for base HL2 weapons
    local skipList = {
        weapon_pistol = true,
        weapon_357 = true,
        weapon_smg1 = true,
        weapon_ar2 = true,
        weapon_shotgun = true,
        weapon_crossbow = true,
        weapon_rpg = true,
        weapon_crowbar = true,
        weapon_stunstick = true,
        weapon_physcannon = true,
        weapon_frag = true,
        weapon_slam = true,
        weapon_bugbait = true,
        gmod_tool = true,
        gmod_camera = true,
    }

    for _, weaponTable in pairs( weapons.GetList() ) do
        if !weaponTable or !weaponTable.ClassName or !weaponTable.WorldModel then continue end

        local className = weaponTable.ClassName
        if skipList[ className ] then continue end

        local weaponName = string.lower( className:gsub( "weapon_", "" ) )
        if _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] then continue end

        -- Import SWEP
        _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] = {
            model = weaponTable.WorldModel,
            prettyname = weaponTable.PrintName or weaponName,
            origin = "External Addon",
            holdtype = weaponTable.HoldType or "pistol",
            islethal = true,
            ismelee = weaponTable.Primary and weaponTable.Primary.ClipSize == -1 or false,

            damage = weaponTable.Primary and weaponTable.Primary.Damage or 10,
            attackrange = 2000,
            keepdistance = 300,
            clip = weaponTable.Primary and weaponTable.Primary.ClipSize or 30,
            rateoffire = weaponTable.Primary and weaponTable.Primary.Delay or 0.2,

            dropentity = className,
        }

        imported = imported + 1
    end

    if imported > 0 then
        print( "[Experimental Players] Auto-imported " .. imported .. " external SWEP weapons" )
    end

    return imported
end

hook.Add( "Initialize", "EXP_ImportGenericWeapons", function()
    timer.Simple( 3, function()
        ImportGenericSWEPs()
    end )
end )

print( "[Experimental Players] Weapon compatibility loaded (Lambda, Zeta, SWEP)" )
