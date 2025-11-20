-- Experimental Players - Tool Weapons
-- Physgun, Gravity Gun, Tool Gun
-- Based on Lambda Players implementation

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local util = util
local math = math
local table = table

-- Helper function: ApproachAngle (smooth rotation)
local function ApproachAngle(current, target, rate)
    rate = rate or 5
    local p = math.ApproachAngle(current.p, target.p, rate)
    local y = math.ApproachAngle(current.y, target.y, rate)
    local r = math.ApproachAngle(current.r, target.r, rate)
    return Angle(p, y, r)
end

--[[ PHYSGUN ]]--

table.Merge(_EXPERIMENTALPLAYERSWEAPONS, {
    physgun = {
        model = "models/weapons/w_physics.mdl",
        origin = "Half-Life 2",
        prettyname = "Physics Gun",
        holdtype = "physgun",
        killicon = "weapon_physgun",
        bonemerge = true,
        keepdistance = 150,
        attackrange = 1500,
        islethal = false,
        dropentity = "weapon_physgun",

        -- Physgun specific properties
        isphysgun = true,
        beamcolor = Color(255, 100, 0),

        -- Callbacks
        OnDeploy = function(ply, wepent, oldwep)
            -- Initialize physgun holding variables
            ply.exp_PhysgunGrabbedEnt = nil
            ply.exp_PhysgunDistance = 200
            ply.exp_PhysgunHoldPos = nil
            ply.exp_PhysgunHoldAng = nil
            ply.exp_PhysgunBeamActive = false

            return true
        end,

        OnHolster = function(ply, wepent, oldwep, newwep)
            -- Drop held entity when switching weapons
            if IsValid(ply.exp_PhysgunGrabbedEnt) then
                ply:PhysgunDrop()
            end
            return false
        end,

        OnAttack = function(ply, wepent, target)
            -- Pick up entity
            if IsValid(ply.exp_PhysgunGrabbedEnt) then
                -- Already holding something, drop it
                ply:PhysgunDrop()
                return true
            end

            -- Trace to find entity to pick up
            local trace = util.TraceLine({
                start = ply:GetShootPos(),
                endpos = ply:GetShootPos() + ply:GetAimVector() * 1500,
                filter = ply,
                mask = MASK_SHOT
            })

            if !trace.Hit or !IsValid(trace.Entity) then
                -- Miss sound
                wepent:EmitSound("weapons/physcannon/physcannon_dryfire.wav", 70)
                return true
            end

            local ent = trace.Entity

            -- Check if we can pick this up
            if !ply:CanPickupWithPhysgun(ent) then
                wepent:EmitSound("weapons/physcannon/physcannon_dryfire.wav", 70)
                return true
            end

            -- Pick it up!
            ply:PhysgunPickup(ent, trace.HitPos)

            -- Pickup sound
            wepent:EmitSound("weapons/physcannon/physcannon_pickup.wav", 70)

            return true
        end,

        OnThink = function(ply, wepent)
            -- Update held entity position
            if IsValid(ply.exp_PhysgunGrabbedEnt) then
                ply:PhysgunUpdateHold(wepent)
            end
        end,

        OnSecondaryAttack = function(ply, wepent)
            -- Freeze/unfreeze held entity
            if IsValid(ply.exp_PhysgunGrabbedEnt) then
                ply:PhysgunFreeze()
                wepent:EmitSound("weapons/physcannon/physcannon_claws_close.wav", 70)
                return true
            end
            return false
        end,
    },

    --[[ GRAVITY GUN ]]--

    gravgun = {
        model = "models/weapons/w_physcannon.mdl",
        origin = "Half-Life 2",
        prettyname = "Zero Point Energy Field Manipulator",
        holdtype = "physgun",
        killicon = "weapon_physcannon",
        bonemerge = true,
        keepdistance = 200,
        attackrange = 500,
        islethal = false,
        dropentity = "weapon_physcannon",

        -- Gravity gun specific
        isgravgun = true,
        puntforce = 15000,
        pullforce = 500,
        launchforce = 25000,

        OnDeploy = function(ply, wepent, oldwep)
            ply.exp_GravgunHeldEntity = nil
            ply.exp_GravgunCharging = false
            ply.exp_GravgunHoldDistance = 100
            return true
        end,

        OnHolster = function(ply, wepent, oldwep, newwep)
            -- Drop held entity when switching
            if IsValid(ply.exp_GravgunHeldEntity) then
                ply.exp_GravgunHeldEntity = nil
            end
            return false
        end,

        OnAttack = function(ply, wepent, target)
            -- If holding an entity, LAUNCH it!
            if IsValid(ply.exp_GravgunHeldEntity) then
                local ent = ply.exp_GravgunHeldEntity
                local phys = ent:GetPhysicsObject()

                if IsValid(phys) then
                    -- LAUNCH!
                    wepent:EmitSound("weapons/physcannon/superphys_launch" .. math.random(1, 4) .. ".wav", 75, math.random(95, 105))

                    -- Apply massive launch force
                    local launchVel = ply:GetAimVector() * 2500
                    phys:SetVelocity(launchVel)
                    phys:AddAngleVelocity(VectorRand() * 500)

                    -- Damage on impact
                    ent.exp_GravgunLaunched = true
                    ent.exp_GravgunLauncher = ply

                    -- Release entity
                    ply.exp_GravgunHeldEntity = nil
                end

                return true
            end

            -- Otherwise, punt nearby props
            local trace = util.TraceLine({
                start = ply:GetShootPos(),
                endpos = ply:GetShootPos() + ply:GetAimVector() * 500,
                filter = ply,
                mask = MASK_SHOT
            })

            if !trace.Hit or !IsValid(trace.Entity) then
                wepent:EmitSound("weapons/physcannon/physcannon_dryfire.wav", 70)
                return true
            end

            local ent = trace.Entity
            local phys = ent:GetPhysicsObject()

            if !IsValid(phys) or !phys:IsMoveable() then
                wepent:EmitSound("weapons/physcannon/physcannon_dryfire.wav", 70)
                return true
            end

            -- Check distance
            if ply:GetPos():Distance(ent:GetPos()) > 175 then
                wepent:EmitSound("weapons/physcannon/physcannon_dryfire.wav", 70)
                return true
            end

            -- PUNT!
            wepent:EmitSound("weapons/physcannon/superphys_launch" .. math.random(1, 4) .. ".wav", 70, math.random(110, 120))

            -- Apply force
            local puntForce = 15000
            phys:ApplyForceCenter(ply:GetAimVector() * puntForce)
            phys:ApplyForceOffset(ply:GetAimVector() * math.min(phys:GetMass(), 250) * 600, trace.HitPos)

            -- Visual effects
            local effectdata = EffectData()
            effectdata:SetStart(ply:GetShootPos())
            effectdata:SetOrigin(trace.HitPos)
            effectdata:SetEntity(wepent)
            util.Effect("ManhackSparks", effectdata)

            return true
        end,

        OnSecondaryAttack = function(ply, wepent)
            -- If holding entity, drop it
            if IsValid(ply.exp_GravgunHeldEntity) then
                ply.exp_GravgunHeldEntity = nil
                wepent:EmitSound("weapons/physcannon/physcannon_drop.wav", 70)
                return true
            end

            -- Otherwise, grab nearby prop (like HL2)
            local trace = util.TraceLine({
                start = ply:GetShootPos(),
                endpos = ply:GetShootPos() + ply:GetAimVector() * 400,
                filter = ply,
                mask = MASK_SHOT
            })

            if trace.Hit and IsValid(trace.Entity) then
                local ent = trace.Entity
                local phys = ent:GetPhysicsObject()

                if IsValid(phys) and phys:IsMoveable() and phys:GetMass() < 200 then
                    -- Grab it!
                    ply.exp_GravgunHeldEntity = ent
                    ply.exp_GravgunHoldDistance = math.Clamp(ply:GetPos():Distance(ent:GetPos()), 80, 300)
                    wepent:EmitSound("weapons/physcannon/physcannon_pickup.wav", 70)

                    return true
                end
            end

            -- If nothing to grab, pull nearby props
            wepent:EmitSound("weapons/physcannon/physcannon_charge.wav", 70)

            local nearEnts = ents.FindInSphere(ply:GetPos(), 500)
            for _, ent in ipairs(nearEnts) do
                if ent == ply then continue end
                local phys = ent:GetPhysicsObject()
                if !IsValid(phys) then continue end
                if !phys:IsMoveable() then continue end

                -- Pull towards player
                local dir = (ply:GetPos() - ent:GetPos()):GetNormalized()
                phys:ApplyForceCenter(dir * 5000)
            end

            return true
        end,

        OnThink = function(ply, wepent)
            -- Update held entity position (like HL2)
            if IsValid(ply.exp_GravgunHeldEntity) then
                local ent = ply.exp_GravgunHeldEntity
                local phys = ent:GetPhysicsObject()

                if !IsValid(phys) then
                    ply.exp_GravgunHeldEntity = nil
                    return
                end

                -- Calculate hold position
                local holdDist = ply.exp_GravgunHoldDistance or 100
                local holdPos = ply:GetShootPos() + ply:GetAimVector() * holdDist

                -- Smooth movement towards hold position
                local currentPos = ent:GetPos()
                local toTarget = holdPos - currentPos
                local dir = toTarget:GetNormalized()
                local dist = toTarget:Length()

                -- Velocity-based smooth movement
                local speed = math.min(dist * 10, 500)
                phys:SetVelocity(dir * speed)

                -- Stabilize rotation
                phys:AddAngleVelocity(-phys:GetAngleVelocity() * 0.5)

                return
            end

            -- Auto-target nearby props for punting (original behavior)
            if math.random(1, 100) > 80 then return end

            local nearbyProps = ents.FindInSphere(ply:GetPos(), 150)
            local validProps = {}

            for _, ent in ipairs(nearbyProps) do
                if ent == ply then continue end
                if ent:GetClass()  ~=  "prop_physics" then continue end
                if !IsValid(ent:GetPhysicsObject()) then continue end
                if !ent:GetPhysicsObject():IsMoveable() then continue end
                if ply.CanSee and !ply:CanSee(ent) then continue end

                table.insert(validProps, ent)
            end

            if #validProps > 0 then
                local target = validProps[math.random(#validProps)]
                -- Look at it
                ply.exp_LookTowards_Pos = target:GetPos() + Vector(0, 0, 20)
                ply.exp_LookTowards_EndT = CurTime() + 1
            end
        end,
    },
})

-- Gravity Gun Launched Projectile Damage
hook.Add("PhysicsCollide", "EXP_GravgunLaunchedDamage", function(ent, data)
    if !IsValid(ent) then return end
    if !ent.exp_GravgunLaunched then return end

    local launcher = ent.exp_GravgunLauncher
    if !IsValid(launcher) then return end

    -- Calculate damage based on impact speed
    local impactSpeed = data.Speed
    if impactSpeed > 200 then
        local damage = math.Clamp((impactSpeed - 200) / 10, 10, 150)

        -- Find hit entity
        local hitEnt = data.HitEntity
        if IsValid(hitEnt) and (hitEnt:IsPlayer() or hitEnt:IsNPC()) then
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(damage)
            dmginfo:SetAttacker(launcher)
            dmginfo:SetInflictor(ent)
            dmginfo:SetDamageType(DMG_CRUSH)
            dmginfo:SetDamagePosition(data.HitPos)

            hitEnt:TakeDamageInfo(dmginfo)

            -- Effect
            local effectdata = EffectData()
            effectdata:SetOrigin(data.HitPos)
            effectdata:SetNormal(data.HitNormal)
            util.Effect("MetalSpark", effectdata)

            -- Sound
            ent:EmitSound("physics/metal/metal_box_impact_hard" .. math.random(1, 3) .. ".wav", 75, math.random(90, 110))
        end
    end

    -- Clear launch flag after first hit
    ent.exp_GravgunLaunched = false
    ent.exp_GravgunLauncher = nil
end)

print("[Experimental Players] Tool weapons loaded")
