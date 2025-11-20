-- Experimental Players - Weapon Alt-Fire Definitions
-- Secondary attack modes for HL2 weapons
-- Server-side only

if ( CLIENT ) then return end

-- Extend existing weapons with alt-fire capabilities

--[[ AR2 - Energy Ball Alt-Fire ]]--

if _EXPERIMENTALPLAYERSWEAPONS.ar2 then
	_EXPERIMENTALPLAYERSWEAPONS.ar2.hasaltfire = true
	_EXPERIMENTALPLAYERSWEAPONS.ar2.altfirecooldown = 5.0
	_EXPERIMENTALPLAYERSWEAPONS.ar2.altfireuses = 3 -- Max 3 energy balls

	_EXPERIMENTALPLAYERSWEAPONS.ar2.OnAltFire = function( ply, wepent, target )
		if !IsValid( ply ) then return end

		-- Check alt-fire ammo
		if !ply.exp_AltFireUses then
			ply.exp_AltFireUses = {}
		end

		if !ply.exp_AltFireUses["ar2"] then
			ply.exp_AltFireUses["ar2"] = 3
		end

		if ply.exp_AltFireUses["ar2"] <= 0 then
			ply:EmitSound( "Weapon_AR2.Empty", 70 )
			return
		end

		-- Fire energy ball
		local ball = ents.Create( "prop_combine_ball" )
		if !IsValid( ball ) then return end

		local aimDir = ply:GetAimVector()
		local spawnPos = ply:GetShootPos() + aimDir * 50

		ball:SetPos( spawnPos )
		ball:SetAngles( aimDir:Angle() )
		ball:SetOwner( ply )
		ball:Spawn()
		ball:Activate()

		-- Launch the ball
		ball:Fire( "Explode", "", 10 ) -- Explode after 10 seconds
		local phys = ball:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetVelocity( aimDir * 1200 )
		end

		-- Sound and effect
		ply:EmitSound( "Weapon_CombineGuard.Special1", 75, 100 )

		-- Visual effect
		local effectdata = EffectData()
		effectdata:SetOrigin( spawnPos )
		effectdata:SetNormal( aimDir )
		effectdata:SetMagnitude( 1 )
		effectdata:SetScale( 1 )
		effectdata:SetRadius( 5 )
		util.Effect( "AR2Impact", effectdata )

		-- Consume alt-fire ammo
		ply.exp_AltFireUses["ar2"] = ply.exp_AltFireUses["ar2"] - 1

		print( "[EXP] " .. ply:Nick() .. " fired AR2 energy ball (" .. ply.exp_AltFireUses["ar2"] .. " remaining)" )
	end
end

--[[ SMG1 - Grenade Launcher Alt-Fire ]]--

if _EXPERIMENTALPLAYERSWEAPONS.smg1 then
	_EXPERIMENTALPLAYERSWEAPONS.smg1.hasaltfire = true
	_EXPERIMENTALPLAYERSWEAPONS.smg1.altfirecooldown = 3.0
	_EXPERIMENTALPLAYERSWEAPONS.smg1.altfireuses = 3 -- 3 grenades

	_EXPERIMENTALPLAYERSWEAPONS.smg1.OnAltFire = function( ply, wepent, target )
		if !IsValid( ply ) then return end

		-- Check alt-fire ammo
		if !ply.exp_AltFireUses then
			ply.exp_AltFireUses = {}
		end

		if !ply.exp_AltFireUses["smg1"] then
			ply.exp_AltFireUses["smg1"] = 3
		end

		if ply.exp_AltFireUses["smg1"] <= 0 then
			ply:EmitSound( "Weapon_SMG1.Empty", 70 )
			return
		end

		-- Fire contact grenade
		local grenade = ents.Create( "grenade_ar2" )
		if !IsValid( grenade ) then return end

		local aimDir = ply:GetAimVector()
		local spawnPos = ply:GetShootPos() + aimDir * 30

		grenade:SetPos( spawnPos )
		grenade:SetAngles( aimDir:Angle() )
		grenade:SetOwner( ply )
		grenade:Spawn()
		grenade:Activate()

		-- Launch the grenade
		local phys = grenade:GetPhysicsObject()
		if IsValid( phys ) then
			phys:SetVelocity( aimDir * 1000 )
			phys:AddAngleVelocity( VectorRand() * 200 )
		end

		-- Sound
		ply:EmitSound( "Weapon_SMG1.Double", 75, 100 )

		-- Consume alt-fire ammo
		ply.exp_AltFireUses["smg1"] = ply.exp_AltFireUses["smg1"] - 1

		print( "[EXP] " .. ply:Nick() .. " fired SMG grenade (" .. ply.exp_AltFireUses["smg1"] .. " remaining)" )
	end
end

--[[ Shotgun - Double Shot Alt-Fire ]]--

if _EXPERIMENTALPLAYERSWEAPONS.shotgun then
	_EXPERIMENTALPLAYERSWEAPONS.shotgun.hasaltfire = true
	_EXPERIMENTALPLAYERSWEAPONS.shotgun.altfirecooldown = 1.5

	_EXPERIMENTALPLAYERSWEAPONS.shotgun.OnAltFire = function( ply, wepent, target )
		if !IsValid( ply ) then return end

		-- Check ammo (requires 2 shells)
		local clip = ply:GetWeaponClip() or 0
		if clip < 2 then
			ply:EmitSound( "Weapon_Shotgun.Empty", 70 )
			return
		end

		-- Fire both barrels simultaneously
		for i = 1, 2 do
			local bullet = {}
			bullet.Num = 7 -- 7 pellets per barrel
			bullet.Src = ply:GetShootPos()
			bullet.Dir = ply:GetAimVector()
			bullet.Spread = Vector( 0.15, 0.15, 0 ) -- Wider spread than single shot
			bullet.Tracer = 1
			bullet.TracerName = "Tracer"
			bullet.Force = 2
			bullet.Damage = 8
			bullet.AmmoType = "Buckshot"
			bullet.Attacker = ply

			ply:FireBullets( bullet )
		end

		-- Massive recoil (visual feedback)
		ply:ViewPunch( Angle( -10, 0, 0 ) )

		-- Sound (louder, double report)
		ply:EmitSound( "Weapon_Shotgun.Double", 80, 95 )

		-- Muzzle flash (bigger)
		local effectdata = EffectData()
		effectdata:SetOrigin( ply:GetShootPos() )
		effectdata:SetAngles( ply:GetAngles() )
		effectdata:SetEntity( wepent )
		effectdata:SetAttachment( 1 )
		effectdata:SetScale( 3 ) -- Triple size flash
		util.Effect( "MuzzleEffect", effectdata )

		-- Consume 2 shells
		ply:SetWeaponClip( clip - 2 )

		print( "[EXP] " .. ply:Nick() .. " fired shotgun double-shot" )
	end
end

--[[ .357 Magnum - Penetrating Shot (experimental) ]]--

if _EXPERIMENTALPLAYERSWEAPONS["357"] then
	_EXPERIMENTALPLAYERSWEAPONS["357"].hasaltfire = true
	_EXPERIMENTALPLAYERSWEAPONS["357"].altfirecooldown = 2.0

	_EXPERIMENTALPLAYERSWEAPONS["357"].OnAltFire = function( ply, wepent, target )
		if !IsValid( ply ) then return end

		-- Check ammo
		local clip = ply:GetWeaponClip() or 0
		if clip < 1 then
			ply:EmitSound( "Weapon_Pistol.Empty", 70 )
			return
		end

		-- Penetrating shot (goes through multiple enemies)
		local bullet = {}
		bullet.Num = 1
		bullet.Src = ply:GetShootPos()
		bullet.Dir = ply:GetAimVector()
		bullet.Spread = Vector( 0, 0, 0 ) -- Perfect accuracy
		bullet.Tracer = 3
		bullet.TracerName = "AR2Tracer" -- Bright tracer
		bullet.Force = 10
		bullet.Damage = 75 -- Massive damage
		bullet.AmmoType = ".357"
		bullet.Attacker = ply

		-- Penetrate through multiple targets
		for i = 1, 5 do -- Up to 5 penetrations
			ply:FireBullets( bullet )
		end

		-- Loud sound
		ply:EmitSound( "Weapon_357.Single", 90, 80 ) -- Lower pitch = more powerful

		-- Consume ammo
		ply:SetWeaponClip( clip - 1 )

		print( "[EXP] " .. ply:Nick() .. " fired penetrating .357 shot" )
	end
end

print( "[Experimental Players] Alt-fire weapons loaded (AR2, SMG, Shotgun, .357)" )
