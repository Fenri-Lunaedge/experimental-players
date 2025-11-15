-- Experimental Players - Admin System
-- Adapted from Zeta Players admin
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random
local math_Rand = math.Rand
local CurTime = CurTime
local string_lower = string.lower
local table_insert = table.insert
local table_remove = table.remove
local Vector = Vector
local Angle = Angle

local PLAYER = EXP.Player

--[[ Global Admin Data ]]--

_EXP_BannedPlayers = {}  -- {steamID = {name, unbanTime}}

--[[ Admin Initialization ]]--

function PLAYER:InitializeAdmin( isAdmin, strictness )
	self.exp_IsAdmin = isAdmin or false
	self.exp_Strictness = strictness or math_random( 30, 70 )
	self.exp_CurrentRuleData = nil
	self.exp_HeldOffender = nil
	self.exp_LastPosition = self:GetPos()
	self.exp_AdminHandled = false
	self.exp_InSit = false
	self.exp_SitAdmin = nil

	if self.exp_IsAdmin then
		-- Set admin name color
		self:SetNW2Bool( "exp_IsAdmin", true )
		print( "[Experimental Players] " .. self:Nick() .. " is an admin (Strictness: " .. self.exp_Strictness .. ")" )
	end
end

--[[ Admin Commands ]]--

-- Teleport admin to entity
function PLAYER:COMMAND_Goto( target )
	if !IsValid( target ) then return false end

	self.exp_LastPosition = self:GetPos()
	self:SetPos( target:GetPos() + Vector( 0, 0, 10 ) )
	self:ChatPrint( "[ADMIN] Teleported to " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Bring entity to admin
function PLAYER:COMMAND_Bring( target )
	if !IsValid( target ) then return false end

	if target.exp_LastPosition then
		-- Already stored
	else
		target.exp_LastPosition = target:GetPos()
	end

	target:SetPos( self:GetPos() + self:GetForward() * 100 + Vector( 0, 0, 10 ) )
	self:ChatPrint( "[ADMIN] Brought " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Return entity to last position
function PLAYER:COMMAND_Return( target )
	if !IsValid( target ) then return false end

	if !target.exp_LastPosition then
		self:ChatPrint( "[ADMIN] No last position stored for this entity!" )
		return false
	end

	target:SetPos( target.exp_LastPosition )
	self:ChatPrint( "[ADMIN] Returned " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Slay entity
function PLAYER:COMMAND_Slay( target )
	if !IsValid( target ) then return false end

	local dmginfo = DamageInfo()
	dmginfo:SetDamage( 999999 )
	dmginfo:SetAttacker( self )
	dmginfo:SetDamageType( DMG_GENERIC )

	target:TakeDamageInfo( dmginfo )
	self:ChatPrint( "[ADMIN] Slayed " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Kick entity
function PLAYER:COMMAND_Kick( target, reason )
	if !IsValid( target ) then return false end

	reason = reason or "Kicked by admin"

	if target:IsPlayer() and !target.exp_IsExperimentalPlayer then
		-- Real player
		target:Kick( reason )
		self:ChatPrint( "[ADMIN] Kicked " .. target:Nick() .. ": " .. reason )
	elseif target.exp_IsExperimentalPlayer then
		-- Bot player
		local name = target:Nick()
		target:Kick( reason )  -- This will remove the bot
		self:ChatPrint( "[ADMIN] Kicked bot " .. name .. ": " .. reason )
	end

	return true
end

-- Ban entity
function PLAYER:COMMAND_Ban( target, duration, reason )
	if !IsValid( target ) then return false end

	duration = duration or 300  -- Default 5 minutes
	reason = reason or "Banned by admin"

	if target:IsPlayer() and !target.exp_IsExperimentalPlayer then
		-- Real player - use SteamID
		local steamID = target:SteamID()
		_EXP_BannedPlayers[ steamID ] = {
			name = target:Nick(),
			unbanTime = CurTime() + duration,
			reason = reason
		}

		target:Kick( "Banned: " .. reason .. " (Duration: " .. duration .. "s)" )
		self:ChatPrint( "[ADMIN] Banned " .. target:Nick() .. " for " .. duration .. "s: " .. reason )

		-- Auto-unban timer
		timer.Simple( duration, function()
			if _EXP_BannedPlayers[ steamID ] then
				_EXP_BannedPlayers[ steamID ] = nil
				print( "[Experimental Players] " .. target:Nick() .. " has been unbanned" )
			end
		end )
	elseif target.exp_IsExperimentalPlayer then
		-- Bot player - use creation ID
		local creationID = target:AccountID() or target:UserID()
		_EXP_BannedPlayers[ creationID ] = {
			name = target:Nick(),
			unbanTime = CurTime() + duration,
			reason = reason
		}

		target:Kick( "Banned: " .. reason )
		self:ChatPrint( "[ADMIN] Banned bot " .. target:Nick() .. " for " .. duration .. "s: " .. reason )
	end

	return true
end

-- Slap entity
function PLAYER:COMMAND_Slap( target, damage )
	if !IsValid( target ) then return false end

	damage = damage or math_random( 0, 100 )

	local dmginfo = DamageInfo()
	dmginfo:SetDamage( damage )
	dmginfo:SetAttacker( self )
	dmginfo:SetDamageType( DMG_CLUB )

	target:TakeDamageInfo( dmginfo )

	-- Apply knockback
	local knockback = Vector( math_Rand( -500, 500 ), math_Rand( -500, 500 ), 500 )
	target:SetVelocity( knockback )

	target:EmitSound( "physics/body/body_medium_impact_hard" .. math_random( 1, 6 ) .. ".wav", 75 )
	self:ChatPrint( "[ADMIN] Slapped " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) .. " for " .. damage .. " damage" )

	return true
end

-- Whip entity (repeated slaps)
function PLAYER:COMMAND_Whip( target, damage, times )
	if !IsValid( target ) then return false end

	damage = damage or math_random( 0, 20 )
	times = times or math_random( 1, 100 )

	self:ChatPrint( "[ADMIN] Whipping " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) .. " " .. times .. " times" )

	for i = 1, times do
		timer.Simple( i * 0.5, function()
			if IsValid( target ) and IsValid( self ) then
				self:COMMAND_Slap( target, damage )
			end
		end )
	end

	return true
end

-- Ignite entity
function PLAYER:COMMAND_Ignite( target, duration )
	if !IsValid( target ) then return false end

	duration = duration or math_random( 1, 120 )

	target:Ignite( duration )
	self:ChatPrint( "[ADMIN] Ignited " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) .. " for " .. duration .. "s" )

	return true
end

-- Set health
function PLAYER:COMMAND_SetHealth( target, health )
	if !IsValid( target ) then return false end

	health = health or 100

	target:SetHealth( health )
	self:ChatPrint( "[ADMIN] Set " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) .. " health to " .. health )

	return true
end

-- Set armor
function PLAYER:COMMAND_SetArmor( target, armor )
	if !IsValid( target ) then return false end

	armor = armor or 100

	target:SetArmor( armor )
	self:ChatPrint( "[ADMIN] Set " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) .. " armor to " .. armor )

	return true
end

-- Godmode
function PLAYER:COMMAND_Godmode( target )
	if !IsValid( target ) then return false end

	target.exp_InGodmode = true
	self:ChatPrint( "[ADMIN] Enabled godmode for " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Remove godmode
function PLAYER:COMMAND_UnGod( target )
	if !IsValid( target ) then return false end

	target.exp_InGodmode = false
	self:ChatPrint( "[ADMIN] Disabled godmode for " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Jail entity
function PLAYER:COMMAND_Jail( target )
	if !IsValid( target ) then return false end

	EXP_CreateJailOnEnt( target )
	self:ChatPrint( "[ADMIN] Jailed " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Unjail entity
function PLAYER:COMMAND_UnJail( target )
	if !IsValid( target ) then return false end

	EXP_RemoveJailOnEnt( target )
	self:ChatPrint( "[ADMIN] Unjailed " .. ( target:IsPlayer() and target:Nick() or target:GetClass() ) )

	return true
end

-- Teleport to + Jail
function PLAYER:COMMAND_TpJail( target )
	if !IsValid( target ) then return false end

	self:COMMAND_Bring( target )
	timer.Simple( 0.5, function()
		if IsValid( target ) then
			self:COMMAND_Jail( target )
		end
	end )

	return true
end

--[[ Admin Decision Making ]]--

function PLAYER:DecideOnOffender( offender, reason )
	if !IsValid( offender ) then return end
	if !self.exp_IsAdmin then return end

	reason = reason or "Unknown"

	-- Check strictness
	local strictness = self.exp_Strictness or 50
	local roll = math_random( 1, 100 )

	-- Soft punishment (100% of strictness)
	if roll <= strictness then
		self:ChoosePunishment( offender )
		self:ChatPrint( "[ADMIN] Applied punishment to " .. offender:Nick() .. " for: " .. reason )
		return
	end

	-- Hard punishment (200% of strictness, clamped to 100)
	if roll <= math.min( strictness * 2, 100 ) then
		if offender.exp_IsExperimentalPlayer then
			-- Bots can be kicked/banned
			self:ChooseHardPunishment( offender, reason )
		else
			-- Real players get soft punishment
			self:ChoosePunishment( offender )
		end
		return
	end

	-- Let them off with a warning
	self:ChatPrint( "[ADMIN] Warned " .. offender:Nick() .. " for: " .. reason )
end

function PLAYER:ChoosePunishment( target )
	if !IsValid( target ) then return end

	local punishments = {
		function() self:COMMAND_Slay( target ) end,
		function() self:COMMAND_Ignite( target, math_random( 5, 30 ) ) end,
		function() self:COMMAND_Slap( target, math_random( 10, 50 ) ) end,
		function() self:COMMAND_Whip( target, math_random( 5, 15 ), math_random( 3, 10 ) ) end,
	}

	local punishment = punishments[ math_random( #punishments ) ]
	punishment()
end

function PLAYER:ChooseHardPunishment( target, reason )
	if !IsValid( target ) then return end

	local punishments = {
		function() self:COMMAND_Kick( target, reason ) end,
		function() self:COMMAND_Ban( target, math_random( 60, 600 ), reason ) end,
	}

	local punishment = punishments[ math_random( #punishments ) ]
	punishment()
end

--[[ Jail System ]]--

function EXP_CreateJailOnEnt( ent )
	if !IsValid( ent ) then return end
	if ent.exp_IsJailed then return end  -- Already jailed

	ent.exp_IsJailed = true
	ent.exp_JailEnts = {}

	local pos = ent:GetPos()
	local barModel = "models/props_building_details/Storefront_Template001a_Bars.mdl"

	-- Create 8 bars around entity
	local angles = { 0, 45, 90, 135, 180, 225, 270, 315 }
	for _, ang in ipairs( angles ) do
		local bar = ents.Create( "prop_physics" )
		if IsValid( bar ) then
			bar:SetModel( barModel )
			bar:SetPos( pos + Angle( 0, ang, 0 ):Forward() * 50 + Vector( 0, 0, 40 ) )
			bar:SetAngles( Angle( 0, ang, 0 ) )
			bar:Spawn()
			bar:SetCollisionGroup( COLLISION_GROUP_WORLD )

			local phys = bar:GetPhysicsObject()
			if IsValid( phys ) then
				phys:EnableMotion( false )
			end

			table_insert( ent.exp_JailEnts, bar )
		end
	end

	print( "[Experimental Players] Jailed " .. ( ent:IsPlayer() and ent:Nick() or ent:GetClass() ) )
end

function EXP_RemoveJailOnEnt( ent )
	if !IsValid( ent ) then return end
	if !ent.exp_IsJailed then return end

	ent.exp_IsJailed = false

	if ent.exp_JailEnts then
		for _, bar in ipairs( ent.exp_JailEnts ) do
			if IsValid( bar ) then
				bar:Remove()
			end
		end
		ent.exp_JailEnts = nil
	end

	print( "[Experimental Players] Unjailed " .. ( ent:IsPlayer() and ent:Nick() or ent:GetClass() ) )
end

--[[ Godmode Protection ]]--

hook.Add( "EntityTakeDamage", "EXP_GodmodeProtection", function( target, dmginfo )
	if !IsValid( target ) then return end

	if target.exp_InGodmode then
		return true  -- Block damage
	end
end )

--[[ Ban Check ]]--

hook.Add( "PlayerAuthed", "EXP_BanCheck", function( ply, steamID )
	if _EXP_BannedPlayers[ steamID ] then
		local banData = _EXP_BannedPlayers[ steamID ]
		local remainingTime = math.Round( banData.unbanTime - CurTime() )

		if remainingTime > 0 then
			ply:Kick( "You are banned: " .. banData.reason .. " (" .. remainingTime .. "s remaining)" )
		else
			-- Ban expired
			_EXP_BannedPlayers[ steamID ] = nil
		end
	end
end )

print( "[Experimental Players] Admin system loaded" )
