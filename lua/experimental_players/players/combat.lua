-- Experimental Players - Combat System
-- Based on Lambda Players combat
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local ents_FindInSphere = ents.FindInSphere
local util_TraceLine = util.TraceLine
local math_random = math.random
local Vector = Vector

local PLAYER = EXP.Player

--[[ Combat Initialization ]]--

function PLAYER:InitializeCombat()
    self.exp_Enemy = nil
    self.exp_LastSeenEnemy = 0
    self.exp_LastAttackTime = 0
    self.exp_CombatRange = 2000  -- How far to detect enemies
    self.exp_CombatKeepDistance = 200  -- Preferred distance from enemy
    self.exp_CombatAttackRange = 500  -- Max attack range
    self.exp_NextTargetScanTime = 0

    -- Initialize cover system
    if self.InitializeCoverSystem then
        self:InitializeCoverSystem()
    end
end

--[[ Target Detection ]]--

function PLAYER:IsValidTarget(ent)
    if !IsValid(ent) then return false end
    if ent == self then return false end
    if !ent:Health() or ent:Health() <= 0 then return false end

    -- Check if hostile
    local class = ent:GetClass()

    -- Players (check friendly fire)
    if ent:IsPlayer() then
        -- Check team system if gamemode is active
        if EXP.GameMode and EXP.GameMode.Active then
            -- Don't attack teammates
            if self.exp_Team and ent.exp_Team then
                if self.exp_Team == ent.exp_Team then
                    return false  -- Same team, don't attack
                else
                    return true  -- Different team, attack!
                end
            end
        end

        -- No gamemode active - check experimental player flag
        if ent.exp_IsExperimentalPlayer then
            -- Attack other bots only if FFA mode
            if EXP:GetConVar("combat_attackbots") == 1 then
                return true
            end
            return false
        end

        -- Attack real players if PVP is enabled
        if EXP:GetConVar("combat_attackplayers") == 1 then
            return true
        end
        return false
    end

    -- NPCs
    if ent:IsNPC() then
        -- Attack all NPCs if convar enabled
        if EXP:GetConVar("combat_attacknpcs") == 1 then
            return true
        end

        -- Otherwise only attack hostile NPCs by class
        local class = ent:GetClass()
        local hostileNPCs = {
            ["npc_zombie"] = true,
            ["npc_zombie_torso"] = true,
            ["npc_fastzombie"] = true,
            ["npc_poisonzombie"] = true,
            ["npc_zombine"] = true,
            ["npc_headcrab"] = true,
            ["npc_headcrab_fast"] = true,
            ["npc_headcrab_black"] = true,
            ["npc_antlion"] = true,
            ["npc_antlionguard"] = true,
            ["npc_combine_s"] = true,
            ["npc_metropolice"] = true,
            ["npc_hunter"] = true,
            ["npc_strider"] = true,
        }

        return hostileNPCs[class] or false
    end

    -- NextBots
    if ent:IsNextBot() and ent.IsNPC then
        return true
    end

    return false
end

function PLAYER:CanSeeEntity(ent)
    if !IsValid(ent) then return false end

    local trace = util_TraceLine({
        start = self:GetShootPos(),
        endpos = ent:GetPos() + ent:OBBCenter(),
        filter = {self, self:GetWeaponENT()},
        mask = MASK_SHOT
    })

    -- Can see if trace hit the entity or nothing
    return !trace.Hit or trace.Entity == ent
end

function PLAYER:FindEnemies()
    -- FIX: Scan more frequently during combat for better reactivity
    local scanInterval = self.exp_State == "Combat" and 0.5 or 1  -- 0.5s in combat, 1s otherwise

    -- Scan for enemies periodically
    if CurTime() < self.exp_NextTargetScanTime then
        return self.exp_Enemy  -- Return current enemy
    end

    self.exp_NextTargetScanTime = CurTime() + scanInterval

    -- Find entities in range
    local pos = self:GetPos()
    local range = self.exp_CombatRange or 2000
    local ents = ents_FindInSphere(pos, range)

    local bestEnemy = nil
    local bestScore = -1

    for _, ent in ipairs(ents) do
        if self:IsValidTarget(ent) then
            -- Check line of sight
            if self:CanSeeEntity(ent) then
                -- Score based on distance (closer = better)
                local dist = pos:Distance(ent:GetPos())
                local score = range - dist

                -- Prioritize current enemy
                if ent == self.exp_Enemy then
                    score = score + 500
                end

                if score > bestScore then
                    bestScore = score
                    bestEnemy = ent
                end
            end
        end
    end

    return bestEnemy
end

function PLAYER:UpdateEnemy()
    -- Find enemies
    local enemy = self:FindEnemies()

    -- Update enemy
    if IsValid(enemy) then
        self.exp_Enemy = enemy
        self.exp_LastSeenEnemy = CurTime()
        self.exp_LastKnownEnemyPos = enemy:GetPos()  -- Track last known position
    else
        -- FIX: Don't immediately forget enemy, try to pursue last known position
        if self.exp_Enemy and IsValid(self.exp_Enemy) then
            local timeSinceLastSeen = CurTime() - self.exp_LastSeenEnemy

            -- Check if enemy is still nearby (within 2000 units)
            local dist = self:GetPos():Distance(self.exp_Enemy:GetPos())

            if timeSinceLastSeen > 10 or dist > 2000 then
                -- Enemy really gone, forget them
                self.exp_Enemy = nil
                self.exp_LastKnownEnemyPos = nil
            end
            -- Otherwise keep tracking them even without LOS
        end
    end

    return self.exp_Enemy
end

--[[ Threat Assessment ]]--

function PLAYER:AssessThreat(target)
    if !IsValid(target) then return 0 end

    local threat = 0

    -- Distance factor (closer = more threat)
    local dist = self:GetPos():Distance(target:GetPos())
    threat = threat + math.max(0, 1000 - dist) / 1000 * 40

    -- Health factor (low health targets are less threatening)
    if target:Health() and target:GetMaxHealth() then
        local healthRatio = target:Health() / target:GetMaxHealth()
        threat = threat + healthRatio * 20
    end

    -- Weapon factor (armed targets are more threatening)
    local hasWeapon = false
    if target.exp_IsExperimentalPlayer then
        -- Experimental Player bot
        hasWeapon = target.exp_Weapon and target.exp_Weapon  ~=  "none"
    elseif target:IsPlayer() then
        -- Real player
        local wep = target:GetActiveWeapon()
        hasWeapon = IsValid(wep)
    elseif target:IsNPC() then
        -- NPC
        local wep = target:GetActiveWeapon()
        hasWeapon = IsValid(wep)
    end

    if hasWeapon then
        threat = threat + 20
    end

    -- Visibility factor (can see target = more threatening)
    if self:CanSeeEntity(target) then
        threat = threat + 10
    end

    -- Player vs NPC (humans more threatening)
    if target:IsPlayer() then
        threat = threat + 10
    end

    -- Gamemode-specific threat modifiers
    if EXP.GameMode and EXP.GameMode.Active then
        local gamemodeName = EXP.GameMode.Name

        -- CTF: Prioritize flag carriers
        if gamemodeName == "CTF" then
            if target.exp_HasFlag then
                threat = threat + 50  -- FLAG CARRIER IS HIGH PRIORITY!
            end
        end

        -- KOTH: Prioritize enemies on the hill
        if gamemodeName == "KOTH" then
            if target.exp_OnHill then
                threat = threat + 30  -- On hill = higher threat
            end
        end

        -- TDM: Prioritize high kill-count players
        if gamemodeName == "TDM" then
            if target:Frags() > 5 then
                threat = threat + 20  -- High-skill players more threatening
            end
        end
    end

    return threat
end

function PLAYER:ShouldRetreat()
    if !IsValid(self.exp_Enemy) then return false end

    -- Get health ratio
    local myHealth = self:Health() / self:GetMaxHealth()

    -- Get personality-based retreat threshold
    local retreatThreshold = 0.4  -- Default
    if self.GetRetreatThreshold then
        retreatThreshold = self:GetRetreatThreshold()
    end

    -- Panic if low health (personality-dependent)
    if myHealth < retreatThreshold then return true end

    -- Assess threat level
    local threat = self:AssessThreat(self.exp_Enemy)

    -- Panic if threat is too high
    if threat > 70 then return true end

    -- Count nearby enemies (outnumbered check)
    local nearbyEnemies = 0
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 1500)) do
        if self:IsValidTarget(ent) and self:CanSeeEntity(ent) then
            nearbyEnemies = nearbyEnemies + 1
        end
    end

    -- Panic if outnumbered (more than 2 enemies)
    if nearbyEnemies > 2 then return true end

    return false
end

--[[ Panic/Retreat System ]]--

function PLAYER:RetreatFrom(target, timeout, speakLine)
    local alreadyPanic = self:IsPanicking()

    if !alreadyPanic then
        if self.StopMoving then
            self:StopMoving()
        end
        self:SetState("Retreat")
        self.exp_RetreatingFrom = target

        -- Play panic sound
        if speakLine and self.Voice_Panic then
            self:Voice_Panic()
        end

        print("[EXP] " .. self:Nick() .. " is retreating from " .. tostring(target))
    end

    -- Set retreat timeout
    self.exp_RetreatEndTime = CurTime() + (timeout or math.random(10, 20))
    self.exp_Enemy = target
end

function PLAYER:IsPanicking()
    return self.exp_State == "Retreat" and CurTime() <= (self.exp_RetreatEndTime or 0)
end

--[[ Combat Actions ]]--

function PLAYER:Attack(target)
    if !IsValid(target) then return end
    if CurTime() < self.exp_LastAttackTime then return end

    -- Get weapon data
    local weaponData = self:GetCurrentWeaponData()
    if !weaponData then return end

    -- Check if weapon is ready
    if !self:CanAttack() then
        return
    end

    -- Aim at target
    local aimPos = target:GetPos() + target:OBBCenter()
    local aimDir = (aimPos - self:GetShootPos()):GetNormalized()
    self:SetEyeAngles(aimDir:Angle())

    -- Check if we're aiming at target
    local dotProduct = self:GetAimVector():Dot(aimDir)
    if dotProduct < 0.9 then  -- Not aimed enough
        return
    end

    -- Attack with weapon
    if weaponData.ismelee then
        -- Melee attack
        self:Attack_Melee(target, weaponData)
    else
        -- Ranged attack
        self:Attack_Ranged(target, weaponData)
    end

    -- Set attack cooldown
    local rof = weaponData.rateoffire
    if !rof then
        -- Use min/max if available
        local rofMin = weaponData.rateoffiremin or 0.5
        local rofMax = weaponData.rateoffiremax or 0.5
        rof = math.Rand(rofMin, rofMax)
    end
    self.exp_LastAttackTime = CurTime() + rof
end

function PLAYER:Attack_Melee(target, weaponData)
    -- Check range
    local dist = self:GetPos():Distance(target:GetPos())
    if dist > (weaponData.attackrange or 100) then
        return
    end

    -- Trace to target
    local trace = util_TraceLine({
        start = self:GetShootPos(),
        endpos = self:GetShootPos() + self:GetAimVector() * (weaponData.attackrange or 100),
        filter = self,
        mask = MASK_SHOT
    })

    if trace.Hit and trace.Entity == target then
        -- Deal damage
        local dmg = DamageInfo()
        dmg:SetDamage(weaponData.damage or 10)
        dmg:SetAttacker(self)
        dmg:SetInflictor(self:GetWeaponENT() or self)
        dmg:SetDamageType(DMG_CLUB)
        dmg:SetDamagePosition(trace.HitPos)

        target:TakeDamageInfo(dmg)

        -- Play hit sound
        self:EmitSound("Weapon_Crowbar.Melee_Hit")

        -- Call weapon callback
        if weaponData.OnAttack then
            weaponData.OnAttack(self, self:GetWeaponENT(), target)
        end
    else
        -- Miss sound
        self:EmitSound("Weapon_Crowbar.Single")
    end
end

function PLAYER:Attack_Ranged(target, weaponData)
    -- Check ammo
    if self:GetWeaponClip() <= 0 then
        if self:CanReload() then
            self:Reload()
        end
        return
    end

    -- Fire bullet
    local bullet = {}
    bullet.Num = weaponData.bulletcount or 1
    bullet.Src = self:GetShootPos()
    bullet.Dir = self:GetAimVector()
    bullet.Spread = Vector(weaponData.spread or 0.1, weaponData.spread or 0.1, 0)
    bullet.Tracer = 1
    bullet.TracerName = weaponData.tracername or "Tracer"
    bullet.Force = weaponData.damage or 10
    bullet.Damage = weaponData.damage or 10
    bullet.AmmoType = "Pistol"
    bullet.Attacker = self
    bullet.Callback = function(attacker, trace, dmginfo)
        -- Custom bullet callback if needed
        if weaponData.bulletcallback then
            weaponData.bulletcallback(attacker, trace, dmginfo)
        end
    end

    self:FireBullets(bullet)

    -- Visual effects
    if weaponData.muzzleflash then
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetShootPos())
        effectdata:SetAngles(self:GetAngles())
        effectdata:SetEntity(self:GetWeaponENT())
        effectdata:SetAttachment(1)
        effectdata:SetScale(weaponData.muzzleflash)
        util.Effect("MuzzleEffect", effectdata)
    end

    -- Shell eject
    if weaponData.shelleject then
        local effectdata = EffectData()
        effectdata:SetOrigin(self:GetShootPos())
        effectdata:SetAngles(self:GetAngles())
        effectdata:SetEntity(self:GetWeaponENT())
        util.Effect(weaponData.shelleject, effectdata)
    end

    -- Sound
    if weaponData.attacksound then
        self:EmitSound(weaponData.attacksound)
    end

    -- Consume ammo
    self.exp_Clip = math.max(0, (self.exp_Clip or 0) - 1)

    -- Call weapon callback
    if weaponData.OnAttack then
        weaponData.OnAttack(self, self:GetWeaponENT(), target)
    end
end

--[[ Combat Think ]]--

function PLAYER:Think_Combat()
    if !self.exp_CombatRange then
        self:InitializeCombat()
        return
    end

    -- Always update enemy detection
    self:UpdateEnemy()

    -- FIX: Don't interrupt critical states with combat
    local protectedStates = {
        ["Retreat"] = true,
        ["AdminDuty"] = true,
        ["UsingCommand"] = true,
        ["Jailed"] = true
    }

    -- Switch to combat state if we have an enemy (unless in protected state)
    if IsValid(self.exp_Enemy) and self.exp_State  ~=  "Combat" then
        if !protectedStates[self.exp_State] then
            self:SetState("Combat")
        end
    end
end

--[[ Hooks ]]--

-- When bot is damaged, react intelligently
hook.Add("EntityTakeDamage", "EXP_OnBotDamaged", function(target, dmg)
    if !IsValid(target) or !target.exp_IsExperimentalPlayer then return end
    if !target:Alive() then return end

    local attacker = dmg:GetAttacker()
    if !IsValid(attacker) or attacker == target then return end

    local damage = dmg:GetDamage()

    -- Set enemy
    target.exp_Enemy = attacker
    target.exp_LastSeenEnemy = CurTime()

    -- Assess threat and decide response
    local threat = 0
    if target.AssessThreat then
        threat = target:AssessThreat(attacker)
    end

    local healthRatio = target:Health() / target:GetMaxHealth()

    -- Instant panic if critical damage
    if damage >= 50 or healthRatio < 0.3 then
        if target.RetreatFrom then
            target:RetreatFrom(attacker, math.random(5, 15), true)
            print("[EXP] " .. target:Nick() .. " panicking from heavy damage!")
        end
        return  -- Don't enter combat, retreat immediately
    end

    -- High threat? Consider retreating
    if threat > 60 and healthRatio < 0.6 then
        if target.RetreatFrom and math.random(1, 100) > 50 then
            target:RetreatFrom(attacker, math.random(8, 12), true)
            print("[EXP] " .. target:Nick() .. " retreating from high threat!")
            return
        end
    end

    -- Otherwise, fight back
    if target.exp_State  ~=  "Combat" then
        target.exp_State = "Combat"
        target.exp_StateTime = CurTime()
        print("[EXP] " .. target:Nick() .. " is now in combat with " .. tostring(attacker))
    end

    -- Evasive maneuver - jump or crouch randomly when hit
    if target:IsOnGround() and math.random(1, 100) > 70 then
        -- Jump dodge
        target.exp_InputButtons = bit.bor(target.exp_InputButtons or 0, IN_JUMP)
        timer.Simple(0.1, function()
            if IsValid(target) then
                target.exp_InputButtons = 0
            end
        end)
    elseif math.random(1, 100) > 80 then
        -- Crouch dodge
        target.exp_MoveCrouch = true
        timer.Simple(0.3, function()
            if IsValid(target) then
                target.exp_MoveCrouch = false
            end
        end)
    end

    -- Play pain sound
    if target.Voice_Panic and damage >= 50 then
        -- Panic voice for heavy damage
        target:Voice_Panic()
    end
end)

print("[Experimental Players] Combat system loaded")
