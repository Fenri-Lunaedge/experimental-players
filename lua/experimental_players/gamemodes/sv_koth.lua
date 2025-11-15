-- Experimental Players - King of the Hill (KOTH) Gamemode
-- Capture and hold the hill to earn points
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random
local CurTime = CurTime
local Vector = Vector
local ents_Create = ents.Create

--[[ KOTH Gamemode ]]--

local KOTH = {}

KOTH.Name = "King of the Hill"
KOTH.ShortName = "KOTH"
KOTH.ScoreLimit = 300  -- First team to 300 points wins
KOTH.RoundDuration = 600  -- 10 minutes
KOTH.PointsPerSecond = 1  -- Points earned per second on hill
KOTH.HillEntity = nil
KOTH.HillPosition = nil
KOTH.HillRadius = 300
KOTH.ControllingTeam = nil
KOTH.LastScoreTime = 0

function KOTH:Initialize()
	-- Create two teams
	EXP:CreateTeam( 1, "Red Team", Color( 255, 50, 50 ) )
	EXP:CreateTeam( 2, "Blue Team", Color( 50, 50, 255 ) )

	-- Auto-balance teams
	EXP:AutoBalanceTeams()

	-- Find hill position (center of map or random navmesh point)
	self.HillPosition = self:FindHillPosition()

	-- Create hill marker entity
	self:CreateHillMarker()

	-- Start round
	EXP:StartRound( self.RoundDuration )

	print( "[KOTH] Initialized at position: " .. tostring( self.HillPosition ) )
end

function KOTH:Shutdown()
	-- Remove hill marker
	if IsValid( self.HillEntity ) then
		self.HillEntity:Remove()
		self.HillEntity = nil
	end

	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Final Score: " .. score .. " points" )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end

	print( "[KOTH] Shutdown" )
end

function KOTH:OnRoundStart()
	self.LastScoreTime = CurTime()

	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "[KOTH] Capture and hold the hill!" )
			ply:ChatPrint( "[KOTH] First team to " .. self.ScoreLimit .. " points wins!" )
		end
	end
end

function KOTH:OnRoundEnd()
	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ TIME'S UP!" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Final Score: " .. score .. " points" )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end
end

function KOTH:Think()
	if !EXP.GameMode.RoundActive then return end

	-- Check score limit
	for teamID, team in pairs( EXP.GameMode.Teams ) do
		if ( team.score or 0 ) >= self.ScoreLimit then
			-- Team reached score limit, end round
			EXP:EndRound()
			return
		end
	end

	-- Update hill control
	local controllingTeam = self:GetHillController()

	if controllingTeam != self.ControllingTeam then
		self.ControllingTeam = controllingTeam

		-- Announce control change
		if controllingTeam then
			local teamData = EXP.GameMode.Teams[ controllingTeam ]
			for _, ply in ipairs( player.GetAll() ) do
				if IsValid( ply ) then
					ply:ChatPrint( "[KOTH] " .. teamData.name .. " captured the hill!" )
				end
			end
		else
			for _, ply in ipairs( player.GetAll() ) do
				if IsValid( ply ) then
					ply:ChatPrint( "[KOTH] Hill is contested!" )
				end
			end
		end
	end

	-- Award points every second
	if CurTime() - self.LastScoreTime >= 1 then
		self.LastScoreTime = CurTime()

		if self.ControllingTeam then
			EXP:AddTeamScore( self.ControllingTeam, self.PointsPerSecond )
		end
	end
end

function KOTH:FindHillPosition()
	-- Try to find center of all players
	local players = player.GetAll()
	if #players > 0 then
		local avgPos = Vector( 0, 0, 0 )
		for _, ply in ipairs( players ) do
			if IsValid( ply ) then
				avgPos = avgPos + ply:GetPos()
			end
		end
		avgPos = avgPos / #players
		return avgPos
	end

	-- Fallback: Random position
	return Vector( math_random( -2000, 2000 ), math_random( -2000, 2000 ), 0 )
end

function KOTH:CreateHillMarker()
	-- Create prop to mark the hill
	local marker = ents_Create( "prop_dynamic" )
	if IsValid( marker ) then
		marker:SetModel( "models/props_wasteland/controlroom_desk001b.mdl" )
		marker:SetPos( self.HillPosition )
		marker:SetAngles( Angle( 0, 0, 0 ) )
		marker:SetColor( Color( 255, 255, 0 ) )
		marker:Spawn()
		marker:SetCollisionGroup( COLLISION_GROUP_WORLD )

		self.HillEntity = marker
	end

	-- Create visual effect (light)
	local light = ents_Create( "light_dynamic" )
	if IsValid( light ) then
		light:SetPos( self.HillPosition + Vector( 0, 0, 50 ) )
		light:SetKeyValue( "_light", "255 255 0 255" )
		light:SetKeyValue( "brightness", "5" )
		light:SetKeyValue( "distance", tostring( self.HillRadius * 2 ) )
		light:Spawn()
		light:Activate()
		light:Fire( "TurnOn", "", 0 )
	end
end

function KOTH:GetHillController()
	if !self.HillPosition then return nil end

	-- Count players from each team on the hill
	local teamCounts = {}
	for teamID, _ in pairs( EXP.GameMode.Teams ) do
		teamCounts[ teamID ] = 0
	end

	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) and ply:Alive() then
			local dist = ply:GetPos():Distance( self.HillPosition )

			if dist <= self.HillRadius then
				local team = EXP:GetPlayerTeam( ply )
				if team then
					teamCounts[ team ] = ( teamCounts[ team ] or 0 ) + 1
				end
			end
		end
	end

	-- Find team with most players
	local controllingTeam = nil
	local maxCount = 0
	local contested = false

	for teamID, count in pairs( teamCounts ) do
		if count > maxCount then
			maxCount = count
			controllingTeam = teamID
			contested = false
		elseif count == maxCount and count > 0 then
			contested = true
		end
	end

	-- If contested, no team controls
	if contested then
		return nil
	end

	-- If no players, no control
	if maxCount == 0 then
		return nil
	end

	return controllingTeam
end

--[[ Bot AI Integration ]]--

-- Make bots move towards the hill
hook.Add( "Think", "EXP_KOTH_BotAI", function()
	if !EXP.GameMode.Active then return end
	if EXP.GameMode.Name != "KOTH" then return end
	if !EXP.GameMode.RoundActive then return end

	local hillPos = KOTH.HillPosition
	if !hillPos then return end

	if !EXP.ActiveBots then return end

	for _, bot in ipairs( EXP.ActiveBots ) do
		if !IsValid( bot._PLY ) then continue end

		-- Random chance to head to hill (10% per frame)
		if math_random( 1, 100 ) > 10 then continue end

		-- Check if already near hill
		local dist = bot._PLY:GetPos():Distance( hillPos )
		if dist < KOTH.HillRadius then continue end

		-- Check if idle or wandering
		if bot.exp_State != "Idle" and bot.exp_State != "Wander" then continue end

		-- Move to hill
		if bot.MoveToPos then
			timer.Simple( math_random( 0, 3 ), function()
				if IsValid( bot._PLY ) then
					bot:MoveToPos( hillPos, {
						tolerance = KOTH.HillRadius - 50,
						sprint = true,
						maxage = 30
					} )
				end
			end )
		end
	end
end )

--[[ Register Gamemode ]]--

EXP:RegisterGameMode( "KOTH", KOTH )

print( "[Experimental Players] King of the Hill gamemode loaded" )
