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
    local wepEnt = ents_Create( "prop_physics" )
    if !IsValid( wepEnt ) then return end

    wepEnt:SetModel( "models/weapons/w_crowbar.mdl" )
    wepEnt:SetSolid( SOLID_NONE )
    wepEnt:SetParent( self )
    wepEnt:SetLocalPos( Vector( 0, 0, 0 ) )
    wepEnt:SetLocalAngles( Angle( 0, 0, 0 ) )
    wepEnt:SetCollisionGroup( COLLISION_GROUP_IN_VEHICLE )
    wepEnt:Spawn()
    wepEnt:Activate()
    wepEnt:SetNoDraw( true )
    wepEnt:DrawShadow( false )

    wepEnt.exp_IsWeaponEntity = true
    wepEnt.exp_Owner = self

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
    if self.exp_Weapon == weaponName then return false end  -- Already have it

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
    self.exp_Clip = newData.clip or -1
    self.exp_MaxClip = newData.clip or -1
    self.exp_WeaponUseCooldown = CurTime() + ( newData.deploydelay or 0.1 )
    self.exp_WeaponDropEntity = newData.dropentity
    self.exp_IsReloading = false
    self.exp_LastWeaponSwitchTime = CurTime()

    -- Update weapon entity model
    wepEnt:SetModel( newData.model or "models/weapons/w_crowbar.mdl" )
    wepEnt:SetNoDraw( newData.nodraw or false )
    wepEnt:DrawShadow( !newData.nodraw )
    wepEnt:SetLocalPos( newData.offpos or Vector( 0, 0, 0 ) )
    wepEnt:SetLocalAngles( newData.offang or Angle( 0, 0, 0 ) )
    wepEnt:SetModelScale( newData.weaponscale or 1, 0 )

    -- Bone merge
    if newData.bonemerge then
        wepEnt:AddEffects( EF_BONEMERGE )
    else
        wepEnt:RemoveEffects( EF_BONEMERGE )
    end

    -- Call deploy function
    if newData.OnDeploy then
        newData.OnDeploy( self, wepEnt, oldWeapon )
    end

    -- Play deploy sound
    if newData.deploysound then
        self:EmitSound( newData.deploysound, 70, 100, 0.8, CHAN_WEAPON )
    end

    -- Play weapon select sound
    if weaponName != "none" then
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
    if !weaponData then return false end

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
    bullet.Callback = function( attacker, tr, dmginfo )
        if weaponData.OnDealDamage and IsValid( tr.Entity ) then
            weaponData.OnDealDamage( self, wepEnt, tr.Entity, dmginfo, true, tr.Entity:Health() <= 0 )
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
        timer.Simple( 0.5, function()
            if IsValid( self ) then
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
