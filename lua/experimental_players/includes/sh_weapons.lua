-- Experimental Players - Weapon System
-- Based on Lambda Players weapon system
-- Compatible with Lambda weapon addons

--[[ Weapon Registry ]]--

_EXPERIMENTALPLAYERSWEAPONS = ( _EXPERIMENTALPLAYERSWEAPONS or {} )
EXP.WeaponList = _EXPERIMENTALPLAYERSWEAPONS

--[[ Weapon Registration Function ]]--

function EXP:RegisterWeapon( weaponName, weaponData )
    _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] = weaponData

    if ( CLIENT ) and weaponData.killicon then
        local killicon = weaponData.killicon
        local ispath = string.find( killicon, "/" )

        if ispath then
            -- Custom killicon material
            killicons.Add( "exp_weaponkillicons_" .. weaponName, killicon, Color( 255, 80, 0 ) )
        end
    end

    return weaponData
end

--[[ Lambda Compatibility ]]--

function EXP:ImportLambdaWeapons()
    if !_LAMBDAPLAYERSWEAPONS then return end

    local count = 0
    for weaponName, weaponData in pairs( _LAMBDAPLAYERSWEAPONS ) do
        if !_EXPERIMENTALPLAYERSWEAPONS[ weaponName ] then
            _EXPERIMENTALPLAYERSWEAPONS[ weaponName ] = table.Copy( weaponData )
            count = count + 1
        end
    end

    if count > 0 then
        print( "[Experimental Players] Imported " .. count .. " weapons from Lambda Players" )
    end
end

-- Import Lambda weapons immediately after this file loads
-- This runs synchronously, ensuring weapons are available before bots spawn
if _LAMBDAPLAYERSWEAPONS then
    EXP:ImportLambdaWeapons()
else
    -- If Lambda loads later, import when it does
    hook.Add( "LambdaOnModulesLoaded", "EXP_ImportLambdaWeapons", function()
        EXP:ImportLambdaWeapons()
    end )
end

--[[ Weapon Utility Functions ]]--

function EXP:WeaponExists( weaponName )
    return _EXPERIMENTALPLAYERSWEAPONS[ weaponName ]  ~=  nil
end

function EXP:GetWeaponData( weaponName )
    return _EXPERIMENTALPLAYERSWEAPONS[ weaponName ]
end

-- Helper: RandomPairs iterator (from GLambda)
local function RandomPairs( tbl )
    local keys = {}
    for k in pairs( tbl ) do
        table.insert( keys, k )
    end

    -- Shuffle keys
    for i = #keys, 2, -1 do
        local j = math.random( i )
        keys[ i ], keys[ j ] = keys[ j ], keys[ i ]
    end

    local i = 0
    return function()
        i = i + 1
        if keys[ i ] then
            return keys[ i ], tbl[ keys[ i ] ]
        end
    end
end

function EXP:GetRandomWeapon( lethalOnly, rangedOnly, meleeOnly )
    -- Validate weapon table exists and has entries
    if !_EXPERIMENTALPLAYERSWEAPONS or table.Count(_EXPERIMENTALPLAYERSWEAPONS) == 0 then
        print("[Experimental Players] ERROR: Weapon table is empty! Weapons not loaded yet.")
        return "none"
    end

    -- Use GLambda's approach: iterate randomly and return first match
    for weaponName, weaponData in RandomPairs( _EXPERIMENTALPLAYERSWEAPONS ) do
        -- Skip if can't be selected
        if weaponData.cantbeselected then continue end

        -- Filter by lethality
        if lethalOnly and !weaponData.islethal then continue end

        -- Filter by type
        if rangedOnly and weaponData.ismelee then continue end
        if meleeOnly and !weaponData.ismelee then continue end

        -- Found a valid weapon!
        return weaponName
    end

    -- No valid weapons found matching criteria
    print("[Experimental Players] WARNING: No weapons match criteria (lethal=" .. tostring(lethalOnly) .. ", ranged=" .. tostring(rangedOnly) .. ", melee=" .. tostring(meleeOnly) .. ")")
    return "none"
end

function EXP:GetWeaponsByOrigin( origin )
    local weapons = {}

    for weaponName, weaponData in pairs( _EXPERIMENTALPLAYERSWEAPONS ) do
        if weaponData.origin == origin then
            weapons[ weaponName ] = weaponData
        end
    end

    return weapons
end

--[[ Data Update Command ]]--

if EXP.FILE then
    EXP.FILE:CreateUpdateCommand( "weapons", function()
        -- Reload weapon permissions
        local permTbl = EXP.FILE:ReadFile( "experimental_players/weaponpermissions.json", "json" )
        if permTbl then
            EXP.WeaponPermissions = permTbl
        else
            -- Create default permissions (all weapons allowed)
            local defaultPerms = {}
            for weaponName, _ in pairs( _EXPERIMENTALPLAYERSWEAPONS ) do
                defaultPerms[ weaponName ] = true
            end
            EXP.WeaponPermissions = defaultPerms
            EXP.FILE:WriteFile( "experimental_players/weaponpermissions.json", defaultPerms, "json" )
        end

        -- Re-import Lambda weapons
        EXP:ImportLambdaWeapons()
    end, false, "Updates the weapon list and permissions", "Weapons" )
end

--[[ Helper Functions for Weapon Data ]]--

function EXP:GetWeaponModel( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.model or "models/weapons/w_crowbar.mdl"
end

function EXP:GetWeaponHoldType( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.holdtype or "normal"
end

function EXP:GetWeaponRange( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.attackrange or 100
end

function EXP:GetWeaponDamage( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.damage or 10
end

function EXP:IsWeaponMelee( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.ismelee or false
end

function EXP:IsWeaponLethal( weaponName )
    local data = self:GetWeaponData( weaponName )
    return data and data.islethal or false
end

function EXP:CanSelectWeapon( weaponName )
    local data = self:GetWeaponData( weaponName )
    if !data then return false end
    if data.cantbeselected then return false end

    -- Check permissions
    if self.WeaponPermissions and self.WeaponPermissions[ weaponName ] == false then
        return false
    end

    return true
end

print( "[Experimental Players] Weapon system loaded" )
