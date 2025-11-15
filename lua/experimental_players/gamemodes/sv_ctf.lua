-- Experimental Players - Capture the Flag (CTF) Gamemode
-- Steal enemy flag and return it to your base
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random
local CurTime = CurTime
local Vector = Vector
local Angle = Angle
local ents_Create = ents.Create

--[[ CTF Gamemode ]]--

local CTF = {}

CTF.Name = "Capture the Flag"
CTF.ShortName = "CTF"
CTF.ScoreLimit = 5  -- First team to 5 captures wins
CTF.RoundDuration = 600  -- 10 minutes

CTF.Flags = {}  -- {teamID = {entity, homePos, carrier}}
CTF.FlagReturnTime = 30  -- Seconds before dropped flag returns

function CTF:Initialize()
	-- Create two teams
	EXP:CreateTeam( 1, "Red Team", Color( 255, 50, 50 ) )
	EXP:CreateTeam( 2, "Blue Team", Color( 50, 50, 255 ) )

	-- Auto-balance teams
	EXP:AutoBalanceTeams()

	-- Create flags
	self:CreateFlags()

	-- Start round
	EXP:StartRound( self.RoundDuration )

	print( "[CTF] Initialized" )
end

function CTF:Shutdown()
	-- Remove flags
	for teamID, flagData in pairs( self.Flags ) do
		if IsValid( flagData.entity ) then
			flagData.entity:Remove()
		end
	end
	self.Flags = {}

	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Captures: " .. score )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end

	print( "[CTF] Shutdown" )
end

function CTF:OnRoundStart()
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "[CTF] Capture the enemy flag!" )
			ply:ChatPrint( "[CTF] First team to " .. self.ScoreLimit .. " captures wins!" )
		end
	end
end

function CTF:OnRoundEnd()
	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ TIME'S UP!" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Captures: " .. score )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end
end

function CTF:Think()
	-- Check score limit
	for teamID, team in pairs( EXP.GameMode.Teams ) do
		if ( team.score or 0 ) >= self.ScoreLimit then
			-- Team reached score limit, end round
			EXP:EndRound()
			return
		end
	end

	-- Update flag positions
	for teamID, flagData in pairs( self.Flags ) do
		if IsValid( flagData.entity ) then
			if flagData.carrier and IsValid( flagData.carrier ) then
				-- Flag is being carried
				flagData.entity:SetPos( flagData.carrier:GetPos() + Vector( 0, 0, 50 ) )
			end
		end
	end

	-- Check for flag captures
	self:CheckFlagCaptures()

	-- Check for flag pickups
	self:CheckFlagPickups()

	-- Check for dropped flag returns
	self:CheckFlagReturns()
end

function CTF:CreateFlags()
	-- Find flag positions (opposite sides of map)
	local positions = self:FindFlagPositions()

	-- Team 1 (Red) flag
	self:CreateFlag( 1, positions[ 1 ] or Vector( -1000, 0, 0 ) )

	-- Team 2 (Blue) flag
	self:CreateFlag( 2, positions[ 2 ] or Vector( 1000, 0, 0 ) )
end

function CTF:CreateFlag( teamID, position )
	local teamData = EXP.GameMode.Teams[ teamID ]
	if !teamData then return end

	-- Create flag entity
	local flag = ents_Create( "prop_physics" )
	if !IsValid( flag ) then return end

	flag:SetModel( "models/props_c17/signpole001.mdl" )
	flag:SetPos( position + Vector( 0, 0, 10 ) )
	flag:SetAngles( Angle( 0, 0, 0 ) )
	flag:SetColor( teamData.color )
	flag:Spawn()
	flag:SetCollisionGroup( COLLISION_GROUP_DEBRIS )

	local phys = flag:GetPhysicsObject()
	if IsValid( phys ) then
		phys:EnableMotion( false )
	end

	-- Store flag data
	self.Flags[ teamID ] = {
		entity = flag,
		homePos = position,
		carrier = nil,
		dropTime = 0,
	}

	print( "[CTF] Created flag for " .. teamData.name .. " at " .. tostring( position ) )
end

function CTF:FindFlagPositions()
	-- Try to find spawn points
	local spawns = ents.FindByClass( "info_player_*" )

	if #spawns >= 2 then
		-- Use spawn points
		return {
			spawns[ 1 ]:GetPos(),
			spawns[ #spawns ]:GetPos()
		}
	end

	-- Fallback: Random positions on opposite sides
	return {
		Vector( -1000, math_random( -500, 500 ), 0 ),
		Vector( 1000, math_random( -500, 500 ), 0 )
	}
end

function CTF:CheckFlagPickups()
	for teamID, flagData in pairs( self.Flags ) do
		if !IsValid( flagData.entity ) then continue end
		if flagData.carrier then continue end  -- Already being carried

		local flagPos = flagData.entity:GetPos()

		-- Check all players
		for _, ply in ipairs( player.GetAll() ) do
			if !IsValid( ply ) or !ply:Alive() then continue end

			local playerTeam = EXP:GetPlayerTeam( ply )
			if !playerTeam then continue end

			-- Check distance
			local dist = ply:GetPos():Distance( flagPos )
			if dist > 100 then continue end

			-- Can't pick up own flag (unless returning it)
			if playerTeam == teamID then
				-- Check if flag is at home (return it)
				local distFromHome = flagPos:Distance( flagData.homePos )
				if distFromHome > 50 then
					-- Return flag to home
					self:ReturnFlag( teamID )
					ply:ChatPrint( "[CTF] You returned your team's flag!" )
				end
				continue
			end

			-- Pick up enemy flag
			self:PickupFlag( teamID, ply )
			break
		end
	end
end

function CTF:PickupFlag( teamID, ply )
	local flagData = self.Flags[ teamID ]
	if !flagData then return end

	flagData.carrier = ply

	-- Broadcast
	local playerTeam = EXP:GetPlayerTeam( ply )
	local playerTeamData = EXP.GameMode.Teams[ playerTeam ]
	local flagTeamData = EXP.GameMode.Teams[ teamID ]

	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "[CTF] " .. ply:Nick() .. " (" .. playerTeamData.name .. ") captured the " .. flagTeamData.name .. " flag!" )
		end
	end

	print( "[CTF] " .. ply:Nick() .. " picked up team " .. teamID .. " flag" )
end

function CTF:DropFlag( teamID, pos )
	local flagData = self.Flags[ teamID ]
	if !flagData then return end

	flagData.carrier = nil
	flagData.dropTime = CurTime()

	if IsValid( flagData.entity ) then
		flagData.entity:SetPos( pos )
	end

	-- Broadcast
	local flagTeamData = EXP.GameMode.Teams[ teamID ]
	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "[CTF] " .. flagTeamData.name .. " flag was dropped!" )
		end
	end

	print( "[CTF] Team " .. teamID .. " flag dropped at " .. tostring( pos ) )
end

function CTF:ReturnFlag( teamID )
	local flagData = self.Flags[ teamID ]
	if !flagData then return end

	flagData.carrier = nil
	flagData.dropTime = 0

	if IsValid( flagData.entity ) then
		flagData.entity:SetPos( flagData.homePos )
	end

	-- Broadcast
	local flagTeamData = EXP.GameMode.Teams[ teamID ]
	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "[CTF] " .. flagTeamData.name .. " flag has been returned!" )
		end
	end

	print( "[CTF] Team " .. teamID .. " flag returned to base" )
end

function CTF:CheckFlagCaptures()
	-- Check if player with enemy flag reaches their own flag
	for teamID, flagData in pairs( self.Flags ) do
		if !flagData.carrier then continue end
		if !IsValid( flagData.carrier ) then
			-- Carrier died or disconnected
			self:DropFlag( teamID, flagData.entity:GetPos() )
			continue
		end

		local carrier = flagData.carrier
		local carrierTeam = EXP:GetPlayerTeam( carrier )

		if !carrierTeam then continue end

		-- Check if carrier is at their own flag
		local ownFlagData = self.Flags[ carrierTeam ]
		if !ownFlagData then continue end

		-- Own flag must be at home
		local ownFlagPos = ownFlagData.entity:GetPos()
		local distFromHome = ownFlagPos:Distance( ownFlagData.homePos )
		if distFromHome > 50 then continue end

		-- Check distance to own flag
		local distToOwnFlag = carrier:GetPos():Distance( ownFlagPos )
		if distToOwnFlag > 100 then continue end

		-- CAPTURE!
		self:CaptureFlag( teamID, carrier, carrierTeam )
	end
end

function CTF:CaptureFlag( capturedTeamID, capturingPlayer, capturingTeam )
	-- Award point
	EXP:AddTeamScore( capturingTeam, 1 )

	-- Return captured flag
	self:ReturnFlag( capturedTeamID )

	-- Broadcast capture
	local capturingTeamData = EXP.GameMode.Teams[ capturingTeam ]
	local capturedTeamData = EXP.GameMode.Teams[ capturedTeamID ]

	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "╔═══════════════════════════════════" )
			ply:ChatPrint( "║ " .. capturingPlayer:Nick() .. " CAPTURED THE FLAG!" )
			ply:ChatPrint( "║ " .. capturingTeamData.name .. ": " .. EXP:GetTeamScore( capturingTeam ) .. " captures" )
			ply:ChatPrint( "╚═══════════════════════════════════" )
		end
	end

	print( "[CTF] " .. capturingPlayer:Nick() .. " captured flag for team " .. capturingTeam )
end

function CTF:CheckFlagReturns()
	-- Auto-return dropped flags after timeout
	for teamID, flagData in pairs( self.Flags ) do
		if flagData.carrier then continue end  -- Being carried
		if flagData.dropTime == 0 then continue end  -- Not dropped

		-- Check if timeout expired
		if CurTime() - flagData.dropTime >= self.FlagReturnTime then
			self:ReturnFlag( teamID )
		end
	end
end

--[[ Death Hook ]]--

hook.Add( "PlayerDeath", "EXP_CTF_DropFlag", function( victim, inflictor, attacker )
	if !EXP.GameMode.Active then return end
	if EXP.GameMode.Name != "CTF" then return end
	if !IsValid( victim ) then return end

	-- Check if victim was carrying a flag
	for teamID, flagData in pairs( CTF.Flags ) do
		if flagData.carrier == victim then
			-- Drop flag
			CTF:DropFlag( teamID, victim:GetPos() )
			break
		end
	end
end )

--[[ Bot AI Integration ]]--

-- Make bots go for enemy flag
hook.Add( "Think", "EXP_CTF_BotAI", function()
	if !EXP.GameMode.Active then return end
	if EXP.GameMode.Name != "CTF" then return end
	if !EXP.GameMode.RoundActive then return end
	if !EXP.ActiveBots then return end

	for _, bot in ipairs( EXP.ActiveBots ) do
		if !IsValid( bot._PLY ) then continue end

		-- Random chance to go for flag (5% per frame)
		if math_random( 1, 100 ) > 5 then continue end

		-- Check if already carrying flag
		local carryingFlag = false
		for teamID, flagData in pairs( CTF.Flags ) do
			if flagData.carrier == bot._PLY then
				carryingFlag = true

				-- Go to own flag to capture
				local ownTeam = EXP:GetPlayerTeam( bot._PLY )
				if ownTeam then
					local ownFlagData = CTF.Flags[ ownTeam ]
					if ownFlagData and IsValid( ownFlagData.entity ) then
						if bot.MoveToPos then
							bot:MoveToPos( ownFlagData.entity:GetPos(), {
								tolerance = 100,
								sprint = true,
								maxage = 30
							} )
						end
					end
				end
				break
			end
		end

		if carryingFlag then continue end

		-- Check if idle or wandering
		if bot.exp_State != "Idle" and bot.exp_State != "Wander" then continue end

		-- Go for enemy flag
		local botTeam = EXP:GetPlayerTeam( bot._PLY )
		if !botTeam then continue end

		for teamID, flagData in pairs( CTF.Flags ) do
			if teamID == botTeam then continue end  -- Own flag

			if IsValid( flagData.entity ) then
				if bot.MoveToPos then
					timer.Simple( math_random( 0, 3 ), function()
						if IsValid( bot._PLY ) then
							bot:MoveToPos( flagData.entity:GetPos(), {
								tolerance = 100,
								sprint = true,
								maxage = 30
							} )
						end
					end )
					break
				end
			end
		end
	end
end )

--[[ Register Gamemode ]]--

EXP:RegisterGameMode( "CTF", CTF )

print( "[Experimental Players] Capture the Flag gamemode loaded" )
