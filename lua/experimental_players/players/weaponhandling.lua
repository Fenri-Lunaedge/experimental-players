-- Experimental Players - Weapon Handling
-- Server-side weapon management
-- Based on Lambda Players weapon system

if ( CLIENT ) then return end

local CurTime = CurTime
local IsValid = IsValid
local ents_Create = ents.Create
local Vector = Vector
local Angle = Angle
local util_TraceLine = util.TraceLine
local math_random = math.random
local math_Rand = math.Rand

local PLAYER = EXP.Player

--[[ Weapon Entity Management ]]--

function PLAYER:CreateWeaponEntity()
    local wepEnt = ents_Create( "base_anim" )
    if !IsValid( wepEnt ) then return end

    wepEnt:SetModel( "models/weapons/w_crowbar.mdl" )
    wepEnt:SetSolid( SOLID_NONE )
    wepEnt:SetMoveType( MOVETYPE_NONE )
    wepEnt:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )

    -- Get right hand attachment point (Lambda style)
    local attachPoint = EXP:GetAttachmentPoint( self, "hand" )
    if attachPoint then
        wepEnt:SetPos( attachPoint.Pos )
        wepEnt:SetAngles( attachPoint.Ang )
    end

    wepEnt:Spawn()
    wepEnt:Activate()

    -- Parent to player WITH attachment index (this is critical!)
    if attachPoint and attachPoint.Index > 0 then
        wepEnt:SetParent( self, attachPoint.Index )
    else
        wepEnt:SetParent( self )
        -- Fallback: follow bone if attachment failed
        if attachPoint and attachPoint.Bone then
            wepEnt:FollowBone( self, attachPoint.Bone )
        end
    end

    -- Don't enable bonemerge yet - weapon data will control this
    wepEnt:SetLocalPos( Vector( 0, 0, 0 ) )
    wepEnt:SetLocalAngles( Angle( 0, 0, 0 ) )

    wepEnt:DrawShadow( false )
    wepEnt:SetNoDraw( false )  -- Will be controlled by weapon data

    wepEnt.exp_IsWeaponEntity = true
    wepEnt.exp_Owner = self

    -- Override IsCarriedByLocalPlayer to prevent ground rendering
    wepEnt.IsCarriedByLocalPlayer = function( entity )
        return false
    end

    self.exp_WeaponEntity = wepEnt
    return wepEnt
end

function PLAYER:GetWeaponENT()
    if !IsValid( self.exp_WeaponEntity ) then
        self:CreateWeaponEntity()
    end
    return self.exp_WeaponEntity
end

--[[ Weapon Switching ]]--

function PLAYER:SwitchWeapon( weaponName, forceSwitch )
    if !weaponName or weaponName == "" then weaponName = "none" end
    if !EXP:WeaponExists( weaponName ) then
        print( "[Experimental Players] WARNING: Weapon '" .. weaponName .. "' doesn't exist!" )
        return false
    end

    -- Check if we can switch
    if !forceSwitch and self.exp_NoWeaponSwitch then return false end

    -- FIX: Don't allow weapon switch during reload (unless forced)
    if !forceSwitch and self.exp_IsReloading then
        return false
    end

    -- FIX: If switching to same weapon, preserve ammo
    if self.exp_Weapon == weaponName then
        return false  -- Already have it, don't reset
    end

    -- Cancel any pending auto-reload timer
    local timerName = "EXP_AutoReload_" .. self:EntIndex()
    if timer.Exists( timerName ) then
        timer.Remove( timerName )
    end

    local wepEnt = self:GetWeaponENT()
    if !IsValid( wepEnt ) then return false end

    -- Get weapon data
    local oldWeapon = self.exp_Weapon or "none"
    local oldData = EXP:GetWeaponData( oldWeapon )
    local newData = EXP:GetWeaponData( weaponName )

    -- Call holster function
    if oldData and oldData.OnHolster then
        if oldData.OnHolster( self, wepEnt, oldWeapon, weaponName ) == true then
            return false  -- Holster blocked
        end
    end

    -- Play holster sound
    if oldData and oldData.holstersound then
        self:EmitSound( oldData.holstersound, 70, 100, 0.8, CHAN_WEAPON )
    end

    -- Set new weapon
    self.exp_Weapon = weaponName
    self.exp_WeaponOrigin = newData.origin
    self.exp_WeaponPrettyName = newData.prettyname
    self.exp_HasLethal = newData.islethal
    self.exp_HasMelee = newData.ismelee
    self.exp_HoldType = newData.holdtype or "normal"
    self.exp_CombatKeepDistance = newData.keepdistance or 200
    self.exp_CombatAttackRange = newData.attackrange or 100
    self.exp_WeaponNoDraw = newData.nodraw or false
    self.exp_WeaponSpeedMultiplier = newData.speedmultiplier or 1

    -- FIX: Preserve ammo if switching back to same weapon type
    -- Store ammo per weapon in a table
    if !self.exp_WeaponAmmoStorage then
        self.exp_WeaponAmmoStorage = {}
    end

    -- Save old weapon ammo
    if oldWeapon and oldWeapon ~= "none" and self.exp_Clip then
        self.exp_WeaponAmmoStorage[oldWeapon] = self.exp_Clip
    end

    -- FIX: Limit ammo storage to prevent memory leak (max 10 weapons)
    local storageCount = table.Count(self.exp_WeaponAmmoStorage)
    if storageCount > 10 then
        -- Remove oldest entry (could be improved with LRU cache)
        local toRemove = nil
        for wepName, _ in pairs(self.exp_WeaponAmmoStorage) do
            -- Remove weapon that's not current or old weapon
            if wepName ~= weaponName and wepName ~= oldWeapon then
                toRemove = wepName
                break
            end
        end
        if toRemove then
            self.exp_WeaponAmmoStorage[toRemove] = nil
        end
    end

    -- Restore ammo if we've used this weapon before
    if self.exp_WeaponAmmoStorage[weaponName] then
        self.exp_Clip = self.exp_WeaponAmmoStorage[weaponName]
    else
        self.exp_Clip = newData.clip or -1
    end

    self.exp_MaxClip = newData.clip or -1
    self.exp_WeaponUseCooldown = CurTime() + ( newData.deploydelay or 0.1 )
    self.exp_WeaponDropEntity = newData.dropentity
    self.exp_IsReloading = false
    self.exp_LastWeaponSwitchTime = CurTime()

    -- Update weapon entity model
    wepEnt:SetModel( newData.model or "models/weapons/w_crowbar.mdl" )

    -- Set position offsets (Lambda style)
    wepEnt:SetLocalPos( newData.offpos or Vector( 0, 0, 0 ) )
    wepEnt:SetLocalAngles( newData.offang or Angle( 0, 0, 0 ) )

    -- Bonemerge control (Lambda style)
    if newData.bonemerge then
        wepEnt:AddEffects( EF_BONEMERGE )
        -- Note: SetModelScale doesn't work with bonemerge
    else
        wepEnt:RemoveEffects( EF_BONEMERGE )
        -- Only apply scale if NOT using bonemerge
        wepEnt:SetModelScale( newData.weaponscale or 1, 0 )
    end

    -- Visibility control (Lambda style)
    local noDraw = newData.nodraw or false
    wepEnt:SetNoDraw( noDraw )
    wepEnt:DrawShadow( !noDraw )

    -- Store holdtype for animation gestures (PlayerBots don't have SetHoldType)
    self.exp_CurrentHoldType = newData.holdtype or "normal"

    -- Call deploy function
    if newData.OnDeploy then
        newData.OnDeploy( self, wepEnt, oldWeapon )
    end

    -- Play deploy sound
    if newData.deploysound then
        self:EmitSound( newData.deploysound, 70, 100, 0.8, CHAN_WEAPON )
    end

    -- Play weapon select sound
    if weaponName  ~=  "none" then
        self:EmitSound( "common/wpn_select.wav", 75, 100, 0.32, CHAN_ITEM )
    end

    return true
end

--[[ Weapon Attack ]]--

function PLAYER:CanAttack()
    if self.exp_IsReloading then return false end
    if CurTime() < self.exp_WeaponUseCooldown then return false end
    if !self.exp_Weapon or self.exp_Weapon == "none" then return false end

    -- Check ammo for ranged weapons
    if !self.exp_HasMelee and self.exp_Clip then
        if self.exp_Clip == 0 then return false end
    end

    return true
end

function PLAYER:Attack( target )
    if !self:CanAttack() then return false end

    local weaponData = EXP:GetWeaponData( self.exp_Weapon )
    if !weaponData then
        -- FIX: Clear attack state when weapon data is invalid
        self.exp_WeaponUseCooldown = CurTime() + 1  -- Prevent spam
        return false
    end

    local wepEnt = self:GetWeaponENT()

    -- Call custom attack function
    if weaponData.OnAttack then
        if weaponData.OnAttack( self, wepEnt, target ) == true then
            return true  -- Custom attack handled it
        end
    end

    -- Default attack behavior
    if weaponData.ismelee then
        self:AttackMelee( weaponData, wepEnt, target )
    else
        self:AttackRanged( weaponData, wepEnt, target )
    end

    -- Set cooldown
    local rof = weaponData.rateoffire
    if !rof and weaponData.rateoffiremin and weaponData.rateoffiremax then
        rof = math_Rand( weaponData.rateoffiremin, weaponData.rateoffiremax )
    end
    self.exp_WeaponUseCooldown = CurTime() + ( rof or 0.5 )

    -- Play attack animation
    if weaponData.attackanim then
        self:AddGesture( weaponData.attackanim )
    end

    return true
end

--[[ Melee Attack ]]--

function PLAYER:AttackMelee( weaponData, wepEnt, target )
    -- Play attack animation (gesture)
    local holdtype = self.exp_CurrentHoldType or "normal"
    local attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE

    if holdtype == "melee" or holdtype == "melee2" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE
    elseif holdtype == "fist" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST
    end

    self:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, attackAnim, true )

    -- Play attack sound
    if weaponData.attacksnd then
        self:EmitSound( weaponData.attacksnd, 75, 100, 1, CHAN_WEAPON )
    end

    -- Trace attack
    local tr = util_TraceLine( {
        start = self:GetShootPos(),
        endpos = self:GetShootPos() + self:GetAimVector() * ( weaponData.attackrange or 50 ),
        filter = self,
        mask = MASK_SHOT
    } )

    if tr.Hit and IsValid( tr.Entity ) then
        -- Deal damage
        local dmg = DamageInfo()
        dmg:SetDamage( weaponData.damage or 10 )
        dmg:SetAttacker( self )
        dmg:SetInflictor( wepEnt )
        dmg:SetDamageType( DMG_CLUB )
        dmg:SetDamagePosition( tr.HitPos )
        dmg:SetDamageForce( self:GetAimVector() * 5000 )

        tr.Entity:TakeDamageInfo( dmg )

        -- Play hit sound
        if weaponData.hitsnd then
            self:EmitSound( weaponData.hitsnd, 75, 100, 1, CHAN_WEAPON )
        end

        -- Call OnDealDamage
        if weaponData.OnDealDamage then
            weaponData.OnDealDamage( self, wepEnt, tr.Entity, dmg, true, tr.Entity:Health() <= 0 )
        end
    end
end

--[[ Ranged Attack ]]--

function PLAYER:AttackRanged( weaponData, wepEnt, target )
    -- Play attack animation (gesture) based on holdtype
    local holdtype = self.exp_CurrentHoldType or "normal"
    local attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL

    -- Map holdtype to appropriate attack animation
    if holdtype == "pistol" or holdtype == "revolver" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL
    elseif holdtype == "smg" or holdtype == "ar2" or holdtype == "rifle" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2
    elseif holdtype == "shotgun" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_SHOTGUN
    elseif holdtype == "crossbow" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_CROSSBOW
    elseif holdtype == "rpg" or holdtype == "physgun" or holdtype == "grenade" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_RPG
    elseif holdtype == "slam" or holdtype == "grenade" then
        attackAnim = ACT_HL2MP_GESTURE_RANGE_ATTACK_GRENADE
    end

    self:AnimRestartGesture( GESTURE_SLOT_ATTACK_AND_RELOAD, attackAnim, true )

    -- Play attack sound
    if weaponData.attacksnd then
        self:EmitSound( weaponData.attacksnd, 85, 100, 1, CHAN_WEAPON )
    end

    -- Consume ammo
    if self.exp_Clip and self.exp_Clip > 0 then
        self.exp_Clip = self.exp_Clip - 1
    end

    -- Fire bullets
    local bulletCount = weaponData.bulletcount or 1
    local spread = weaponData.spread or 0.1

    local bullet = {}
    bullet.Num = bulletCount
    bullet.Src = self:GetShootPos()
    bullet.Dir = self:GetAimVector()
    bullet.Spread = Vector( spread, spread, 0 )
    bullet.Tracer = 1
    bullet.TracerName = weaponData.tracername or "Tracer"
    bullet.Force = weaponData.force or 1
    bullet.Damage = weaponData.damage or 10
    bullet.AmmoType = "Pistol"
    bullet.Attacker = self

    -- Capture OnDealDamage callback to avoid stale reference
    local onDealDamage = weaponData.OnDealDamage
    bullet.Callback = function( attacker, tr, dmginfo )
        if onDealDamage and IsValid( tr.Entity ) and IsValid( self ) and IsValid( wepEnt ) then
            onDealDamage( self, wepEnt, tr.Entity, dmginfo, true, tr.Entity:Health() <= 0 )
        end
    end

    self:FireBullets( bullet )

    -- Muzzle flash
    if weaponData.muzzleflash then
        local effectData = EffectData()
        effectData:SetOrigin( wepEnt:GetPos() )
        effectData:SetEntity( wepEnt )
        effectData:SetAttachment( 1 )
        effectData:SetScale( weaponData.muzzleflash )
        util.Effect( "MuzzleFlash", effectData )
    end

    -- Shell eject
    if weaponData.shelleject then
        local effectData = EffectData()
        effectData:SetOrigin( wepEnt:GetPos() + ( weaponData.shelloffpos or Vector( 0, 0, 0 ) ) )
        effectData:SetEntity( wepEnt )
        effectData:SetAttachment( 2 )
        util.Effect( weaponData.shelleject, effectData )
    end

    -- Auto reload if empty
    if self.exp_Clip == 0 then
        local timerName = "EXP_AutoReload_" .. self:EntIndex()
        local currentWeapon = weaponData.name  -- FIX: Capture weapon name to avoid race condition
        timer.Create( timerName, 0.5, 1, function()
            if IsValid( self ) and self:Alive() and self.exp_Weapon == currentWeapon then
                self:Reload()
            end
        end )
    end
end

--[[ Reloading ]]--

function PLAYER:CanReload()
    if self.exp_IsReloading then return false end
    if !self.exp_Weapon or self.exp_Weapon == "none" then return false end
    if self.exp_Clip == -1 then return false end  -- Doesn't use ammo
    if self.exp_Clip == self.exp_MaxClip then return false end  -- Already full

    return true
end

function PLAYER:Reload()
    if !self:CanReload() then return false end

    local weaponData = EXP:GetWeaponData( self.exp_Weapon )
    if !weaponData or !weaponData.reloadtime then return false end

    self.exp_IsReloading = true

    -- Play reload animation
    if weaponData.reloadanim then
        self:AddGesture( weaponData.reloadanim )
    end

    -- Play reload sounds
    if weaponData.reloadsounds then
        for _, sndData in ipairs( weaponData.reloadsounds ) do
            timer.Simple( sndData[ 1 ], function()
                if IsValid( self ) then
                    self:EmitSound( sndData[ 2 ], 70, 100, 0.8, CHAN_ITEM )
                end
            end )
        end
    end

    -- Finish reload
    timer.Simple( weaponData.reloadtime, function()
        if IsValid( self ) then
            self.exp_Clip = self.exp_MaxClip
            self.exp_IsReloading = false
        end
    end )

    return true
end

--[[ Utility ]]--

function PLAYER:GetCurrentWeapon()
    return self.exp_Weapon or "none"
end

function PLAYER:GetCurrentWeaponData()
    return EXP:GetWeaponData( self:GetCurrentWeapon() )
end

function PLAYER:GetWeaponClip()
    return self.exp_Clip or -1
end

function PLAYER:SetWeaponClip( amount )
    self.exp_Clip = amount
end

function PLAYER:HasAmmo()
    if self.exp_HasMelee then return true end
    return self.exp_Clip and self.exp_Clip > 0
end

print( "[Experimental Players] Weapon handling loaded" )
