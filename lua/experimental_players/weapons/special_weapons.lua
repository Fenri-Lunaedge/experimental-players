-- Experimental Players - Special Weapons
-- RPG, Crossbow, Grenades - Advanced projectile weapons
-- Server-side only

if ( CLIENT ) then return end

--[[ RPG (Rocket Propelled Grenade) ]]--

table.Merge( _EXPERIMENTALPLAYERSWEAPONS, {
	rpg = {
		model = "models/weapons/w_rocket_launcher.mdl",
		prettyname = "RPG",
		origin = "Half-Life 2",
		holdtype = "rpg",
		killicon = "weapon_rpg",
		islethal = true,
		ismelee = false,

		-- Stats
		damage = 150,
		attackrange = 3000,
		keepdistance = 600, -- Stay far from target (RPG is long range)
		clip = 1,
		reloadtime = 3.0,

		-- Visuals
		muzzleflash = 1,

		-- Sounds
		attacksnd = "Weapon_RPG.Single",
		reloadsounds = {
			{0.5, "Weapon_RPG.Reload"},
		},

		-- Animations
		reloadanim = ACT_HL2MP_GESTURE_RELOAD_RPG,

		OnAttack = function( ply, wepent, target )
			if !IsValid( ply ) then return true end

			-- Fire rocket projectile
			local rocket = ents.Create( "rpg_missile" )
			if !IsValid( rocket ) then return true end

			-- Calculate aim with prediction for moving targets
			local aimPos = target and IsValid( target ) and target:GetPos() + target:OBBCenter() or ply:GetPos() + ply:GetAimVector() * 1000

			-- Add target velocity prediction
			if IsValid( target ) then
				local targetVel = target:GetVelocity()
				local dist = ply:GetPos():Distance( target:GetPos() )
				local travelTime = dist / 1500 -- Rocket speed ~1500 units/s
				aimPos = aimPos + targetVel * travelTime
			end

			local aimDir = ( aimPos - ply:GetShootPos() ):GetNormalized()

			rocket:SetPos( ply:GetShootPos() + aimDir * 50 )
			rocket:SetAngles( aimDir:Angle() )
			rocket:SetOwner( ply )
			rocket:Spawn()
			rocket:Activate()

			-- Give it velocity
			local phys = rocket:GetPhysicsObject()
			if IsValid( phys ) then
				phys:SetVelocity( aimDir * 1500 )
			end

			-- Consume ammo
			ply:SetWeaponClip( 0 )

			-- Muzzle effect
			local effectdata = EffectData()
			effectdata:SetOrigin( ply:GetShootPos() )
			effectdata:SetNormal( aimDir )
			effectdata:SetScale( 1 )
			util.Effect( "MuzzleEffect", effectdata )

			-- Backblast effect
			effectdata:SetOrigin( ply:GetShootPos() - aimDir * 50 )
			effectdata:SetNormal( -aimDir )
			util.Effect( "RocketBackblast", effectdata )

			return true -- Custom attack handled
		end,
	},

	--[[ Crossbow (Silent sniper weapon) ]]--

	crossbow = {
		model = "models/weapons/w_crossbow.mdl",
		prettyname = "Crossbow",
		origin = "Half-Life 2",
		holdtype = "crossbow",
		killicon = "weapon_crossbow",
		islethal = true,
		ismelee = false,

		-- Stats
		damage = 100,
		attackrange = 4000,
		keepdistance = 800, -- Sniper range
		clip = 1,
		rateoffire = 2.0, -- Slow reload
		reloadtime = 2.5,

		-- Sounds
		attacksnd = "Weapon_Crossbow.Single",
		reloadsounds = {
			{0.5, "Weapon_Crossbow.Reload"},
			{1.5, "Weapon_Crossbow.BoltLoad"},
		},

		-- Animations
		reloadanim = ACT_HL2MP_GESTURE_RELOAD_CROSSBOW,

		OnAttack = function( ply, wepent, target )
			if !IsValid( ply ) then return true end

			-- Fire bolt projectile
			local bolt = ents.Create( "crossbow_bolt" )
			if !IsValid( bolt ) then return true end

			-- Precise aim
			local aimPos = target and IsValid( target ) and target:GetPos() + target:OBBCenter() or ply:GetPos() + ply:GetAimVector() * 2000
			local aimDir = ( aimPos - ply:GetShootPos() ):GetNormalized()

			bolt:SetPos( ply:GetShootPos() + aimDir * 30 )
			bolt:SetAngles( aimDir:Angle() )
			bolt:SetOwner( ply )
			bolt:Spawn()

			-- Give it high velocity
			local phys = bolt:GetPhysicsObject()
			if IsValid( phys ) then
				phys:SetVelocity( aimDir * 3500 ) -- Fast projectile
				phys:AddAngleVelocity( Vector( 0, 0, 0 ) )
			end

			-- Custom damage on hit
			bolt.exp_Damage = 100
			bolt.exp_Attacker = ply

			-- Consume ammo
			ply:SetWeaponClip( 0 )

			return true -- Custom attack handled
		end,
	},

	--[[ Frag Grenade (Thrown explosive) ]]--

	grenade = {
		model = "models/weapons/w_grenade.mdl",
		prettyname = "Frag Grenade",
		origin = "Half-Life 2",
		holdtype = "grenade",
		killicon = "weapon_frag",
		islethal = true,
		ismelee = false,

		-- Stats
		damage = 150,
		attackrange = 800,
		keepdistance = 400,
		clip = 3, -- 3 grenades
		rateoffire = 1.5,

		-- Sounds
		attacksnd = "WeaponFrag.Throw",

		OnAttack = function( ply, wepent, target )
			if !IsValid( ply ) then return true end

			-- Throw grenade
			local grenade = ents.Create( "npc_grenade_frag" )
			if !IsValid( grenade ) then return true end

			-- Calculate throw arc to target
			local throwPos = ply:GetShootPos() + ply:GetAimVector() * 30
			local targetPos = target and IsValid( target ) and target:GetPos() or ply:GetPos() + ply:GetAimVector() * 500

			-- Arc calculation (lob over obstacles)
			local dist = throwPos:Distance( targetPos )
			local throwDir = ( targetPos - throwPos ):GetNormalized()
			local upBoost = Vector( 0, 0, math.min( dist / 4, 300 ) ) -- Arc height

			grenade:SetPos( throwPos )
			grenade:SetOwner( ply )
			grenade:Spawn()
			grenade:Activate()

			-- Set timer (3 seconds)
			grenade:SetTimer( 3 )

			-- Give it velocity
			local phys = grenade:GetPhysicsObject()
			if IsValid( phys ) then
				local throwVel = throwDir * math.min( dist * 2, 1000 ) + upBoost
				phys:SetVelocity( throwVel )
				phys:AddAngleVelocity( VectorRand() * 500 )
			end

			-- Consume ammo
			ply:SetWeaponClip( ( ply:GetWeaponClip() or 3 ) - 1 )

			return true -- Custom attack handled
		end,
	},

	--[[ SLAM (Sticky mine) ]]--

	slam = {
		model = "models/weapons/w_slam.mdl",
		prettyname = "SLAM",
		origin = "Half-Life 2",
		holdtype = "slam",
		killicon = "weapon_slam",
		islethal = true,
		ismelee = false,

		-- Stats
		damage = 200,
		attackrange = 200, -- Place at close range
		keepdistance = 500, -- Get away after placing!
		clip = 3,
		rateoffire = 2.0,

		-- Sounds
		attacksnd = "Weapon_SLAM.SatchelThrow",

		OnAttack = function( ply, wepent, target )
			if !IsValid( ply ) then return true end

			-- Trace for wall/floor placement
			local trace = util.TraceLine( {
				start = ply:GetShootPos(),
				endpos = ply:GetShootPos() + ply:GetAimVector() * 100,
				filter = ply,
				mask = MASK_SOLID
			} )

			if !trace.Hit then return true end

			-- Place SLAM mine
			local slam = ents.Create( "npc_satchel" )
			if !IsValid( slam ) then return true end

			slam:SetPos( trace.HitPos + trace.HitNormal * 2 )
			slam:SetAngles( trace.HitNormal:Angle() )
			slam:SetOwner( ply )
			slam:Spawn()
			slam:Activate()

			-- Stick to surface
			local phys = slam:GetPhysicsObject()
			if IsValid( phys ) then
				phys:EnableMotion( false )
			end

			-- Detonate on proximity or timer
			timer.Simple( 0.5, function()
				if !IsValid( slam ) then return end

				-- Proximity check every 0.1s
				timer.Create( "SLAM_Proximity_" .. slam:EntIndex(), 0.1, 0, function()
					if !IsValid( slam ) then
						timer.Remove( "SLAM_Proximity_" .. slam:EntIndex() )
						return
					end

					-- Find nearby enemies
					local enemies = ents.FindInSphere( slam:GetPos(), 150 )
					for _, ent in ipairs( enemies ) do
						if IsValid( ent ) and ent  ~=  ply and ( ent:IsPlayer() or ent:IsNPC() ) then
							-- Detonate!
							slam:Fire( "Explode", "", 0 )
							timer.Remove( "SLAM_Proximity_" .. slam:EntIndex() )
							break
						end
					end
				end )
			end )

			-- Auto-detonate after 30 seconds
			timer.Simple( 30, function()
				if IsValid( slam ) then
					slam:Fire( "Explode", "", 0 )
				end
			end )

			-- Consume ammo
			ply:SetWeaponClip( ( ply:GetWeaponClip() or 3 ) - 1 )

			return true -- Custom attack handled
		end,
	},
} )

print( "[Experimental Players] Special weapons loaded (RPG, Crossbow, Grenade, SLAM)" )
