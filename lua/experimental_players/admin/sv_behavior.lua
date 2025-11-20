-- Experimental Players - Admin Behavior
-- Admin states and automated behavior for admin bots
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random
local CurTime = CurTime
local coroutine_yield = coroutine.yield

local PLAYER = EXP.Player

-- Coroutine wait helper
local function coroutine_wait(seconds)
    local waitUntil = CurTime() + seconds
    while CurTime() < waitUntil do
        coroutine_yield()
    end
end

--[[ Admin States ]]--

function PLAYER:State_AdminDuty()
	if !self.exp_IsAdmin then
		self:SetState( "Idle" )
		return
	end

	-- Check if we have rule data to handle
	if self.exp_CurrentRuleData then
		self:ConductAdminSit()
		self.exp_CurrentRuleData = nil
		self:SetState( "Idle" )
		return
	end

	-- Random admin activities
	local activities = {
		function() self:Admin_RandomCommand() end,
		function() self:Admin_PatrolArea() end,
	}

	local activity = activities[ math_random( #activities ) ]
	activity()

	coroutine_wait( math_random( 5, 15 ) )
	self:SetState( "Idle" )
end

function PLAYER:State_UsingCommand()
	if !self.exp_IsAdmin then
		self:SetState( "Idle" )
		return
	end

	-- Execute random admin command
	self:Admin_RandomCommand()

	coroutine_wait( math_random( 3, 8 ) )
	self:SetState( "Idle" )
end

--[[ Admin Sit Conduct ]]--

function PLAYER:ConductAdminSit()
	if !self.exp_IsAdmin then return end
	if !self.exp_CurrentRuleData then return end

	local offender = self.exp_CurrentRuleData.offender
	local reason = self.exp_CurrentRuleData.ruletype or "Unknown"

	if !IsValid( offender ) then
		print( "[Experimental Players] Admin sit failed: Invalid offender" )
		return
	end

	-- Check if already being handled
	if offender.exp_AdminHandled then
		print( "[Experimental Players] Offender already being handled by another admin" )
		return
	end

	-- Mark as being handled
	offender.exp_AdminHandled = true
	self.exp_HeldOffender = offender
	self.exp_InSit = true

	-- Store positions
	local adminStartPos = self:GetPos()
	local offenderStartPos = offender:GetPos()

	-- Choose approach (3 modes)
	local approach = math_random( 1, 3 )

	if approach == 1 then
		-- Mode 1: Bring + Interrogate + Decide
		self:COMMAND_Bring( offender )
		coroutine_wait( 1 )
		self:Interrogate( math_random( 1, 3 ), offender )
		coroutine_wait( 2 )
		self:DecideOnOffender( offender, reason )

	elseif approach == 2 then
		-- Mode 2: TpJail + Interrogate + Decide
		self:COMMAND_TpJail( offender )
		coroutine_wait( 1 )
		self:Interrogate( math_random( 2, 4 ), offender )
		coroutine_wait( 2 )
		self:COMMAND_UnJail( offender )
		coroutine_wait( 0.5 )
		self:DecideOnOffender( offender, reason )

	elseif approach == 3 then
		-- Mode 3: Direct hard punishment
		self:COMMAND_Bring( offender )
		coroutine_wait( 1 )
		self:ChooseHardPunishment( offender, reason )
	end

	-- Return entities to original positions (if still alive)
	if IsValid( offender ) then
		offender:SetPos( offenderStartPos )
		offender.exp_AdminHandled = false
	end

	if IsValid( self ) then
		self:SetPos( adminStartPos )
		self.exp_HeldOffender = nil
		self.exp_InSit = false
	end

	print( "[Experimental Players] Admin sit completed for " .. ( IsValid( offender ) and offender:Nick() or "Unknown" ) )
end

--[[ Interrogation ]]--

function PLAYER:Interrogate( times, offender )
	if !IsValid( offender ) then return end
	if !self.exp_IsAdmin then return end

	times = times or 1

	-- Set offender state
	if offender.exp_IsExperimentalPlayer then
		offender.exp_State = "Jailed"  -- Custom state for being held
	end

	for i = 1, times do
		-- Admin scolds offender
		local scoldMessages = {
			"Why did you do that?",
			"That's against the rules!",
			"Do you have anything to say?",
			"This is unacceptable behavior!",
			"Explain yourself!",
		}

		local message = scoldMessages[ math_random( #scoldMessages ) ]

		if self.SayText then
			self:SayText( message, "idle" )
		end

		-- Wait for response (bots don't respond, but timing looks natural)
		coroutine_wait( 3 )

		-- Offender might respond (if bot)
		if offender.exp_IsExperimentalPlayer and offender.SayText then
			local responses = {
				"Sorry...",
				"I didn't mean to!",
				"It was an accident!",
				"...",
			}

			if math_random( 1, 100 ) < 70 then  -- 70% chance to respond
				local response = responses[ math_random( #responses ) ]
				offender:SayText( response, "idle" )
			end
		end

		coroutine_wait( 2 )
	end

	-- Reset offender state
	if offender.exp_IsExperimentalPlayer then
		offender.exp_State = "Idle"
	end
end

--[[ Admin Random Commands ]]--

function PLAYER:Admin_RandomCommand()
	if !self.exp_IsAdmin then return end

	local commands = {
		-- Self commands
		function()
			self:COMMAND_SetHealth( self, math_random( 100, 200 ) )
		end,
		function()
			self:COMMAND_SetArmor( self, math_random( 100, 255 ) )
		end,
		function()
			if !self.exp_InGodmode then
				self:COMMAND_Godmode( self )
			else
				self:COMMAND_UnGod( self )
			end
		end,

		-- Teleport commands
		function()
			local players = player.GetAll()
			if #players > 0 then
				local target = players[ math_random( #players ) ]
				if IsValid( target ) and target  ~=  self then
					self:COMMAND_Goto( target )
				end
			end
		end,
	}

	local command = commands[ math_random( #commands ) ]
	command()
end

function PLAYER:Admin_PatrolArea()
	if !self.exp_IsAdmin then return end

	-- Wander around like normal patrol
	local randomPos = self:GetPos() + Vector( math_random( -1000, 1000 ), math_random( -1000, 1000 ), 0 )

	if self.MoveToPos then
		self:MoveToPos( randomPos, {
			tolerance = 100,
			sprint = false,
			maxage = 10
		} )
	end

	coroutine_wait( math_random( 5, 10 ) )
end

--[[ Rule Detection Hooks ]]--

-- Detect RDM (Random Death Match)
hook.Add( "PlayerDeath", "EXP_DetectRDM", function( victim, inflictor, attacker )
	if !IsValid( victim ) or !IsValid( attacker ) then return end
	if victim == attacker then return end  -- Suicide

	-- Check if attacker is bot
	if !attacker.exp_IsExperimentalPlayer then return end

	-- Check if there are admin bots
	if !EXP.ActiveBots then return end

	for _, bot in ipairs( EXP.ActiveBots ) do
		if !IsValid( bot._PLY ) then continue end

		local ply = bot._PLY  -- Extract entity from wrapper

		if !ply.exp_IsAdmin then continue end

		-- Random chance to notice (50%)
		if math_random( 1, 100 ) > 50 then continue end

		-- Set rule data
		ply.exp_CurrentRuleData = {
			offender = attacker,
			victim = victim,
			inflictor = inflictor,
			ruletype = "RDM"
		}

		-- Enter admin duty state
		ply:SetState( "AdminDuty" )

		print( "[Experimental Players] Admin " .. ply:Nick() .. " detected RDM by " .. attacker:Nick() )
		break  -- Only one admin handles it
	end
end )

-- Detect Prop Killing
hook.Add( "PlayerDeath", "EXP_DetectPropKill", function( victim, inflictor, attacker )
	if !IsValid( victim ) or !IsValid( inflictor ) then return end

	-- Check if killed by prop
	if inflictor:GetClass()  ~=  "prop_physics" then return end

	-- Find owner of prop
	local owner = inflictor.exp_Owner
	if !IsValid( owner ) then return end

	-- Check if there are admin bots
	if !EXP.ActiveBots then return end

	for _, bot in ipairs( EXP.ActiveBots ) do
		if !IsValid( bot._PLY ) then continue end

		local ply = bot._PLY  -- Extract entity from wrapper

		if !ply.exp_IsAdmin then continue end

		-- Random chance to notice (60%)
		if math_random( 1, 100 ) > 60 then continue end

		-- Set rule data
		ply.exp_CurrentRuleData = {
			offender = owner,
			victim = victim,
			inflictor = inflictor,
			ruletype = "Prop Killing"
		}

		-- Enter admin duty state
		ply:SetState( "AdminDuty" )

		print( "[Experimental Players] Admin " .. ply:Nick() .. " detected prop kill by " .. owner:Nick() )
		break
	end
end )

--[[ Cleanup ]]--

-- Clean up jail when bot dies
hook.Add( "PlayerDeath", "EXP_AdminCleanupJail", function( victim, inflictor, attacker )
	if !IsValid( victim ) then return end

	if victim.exp_IsJailed then
		EXP_RemoveJailOnEnt( victim )
	end

	if victim.exp_AdminHandled then
		victim.exp_AdminHandled = false
	end
end )

print( "[Experimental Players] Admin behavior loaded" )
