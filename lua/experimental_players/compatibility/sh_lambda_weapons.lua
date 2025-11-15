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

print( "[Experimental Players] Lambda weapon compatibility loaded" )
