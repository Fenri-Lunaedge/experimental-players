-- Experimental Players - Gamemode Base System
-- Foundation for all game modes (CTF, KOTH, TDM, etc.)
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random
local CurTime = CurTime
local table_Count = table.Count

--[[ Global Gamemode Data ]]--

EXP.GameMode = {
	Active = false,
	Name = "None",
	Teams = {},
	Scores = {},
	RoundTime = 0,
	RoundStartTime = 0,
	RoundActive = false,
}

EXP.RegisteredGameModes = {}

--[[ Gamemode Registration ]]--

function EXP:RegisterGameMode( name, gamemodeTable )
	self.RegisteredGameModes[ name ] = gamemodeTable
	print( "[Experimental Players] Registered gamemode: " .. name )
end

function EXP:GetGameMode( name )
	return self.RegisteredGameModes[ name ]
end

function EXP:StartGameMode( name )
	local gamemode = self:GetGameMode( name )
	if !gamemode then
		print( "[Experimental Players] ERROR: Gamemode not found: " .. name )
		return false
	end

	-- Stop current gamemode
	if self.GameMode.Active then
		self:StopGameMode()
	end

	-- Initialize gamemode
	self.GameMode.Active = true
	self.GameMode.Name = name

	-- Call gamemode init
	if gamemode.Initialize then
		gamemode:Initialize()
	end

	-- Broadcast to all players
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "╔═══════════════════════════════════" )
			ply:ChatPrint( "║ Game Mode Started: " .. name )
			ply:ChatPrint( "╚═══════════════════════════════════" )
		end
	end

	print( "[Experimental Players] Started gamemode: " .. name )
	return true
end

function EXP:StopGameMode()
	if !self.GameMode.Active then return end

	local currentMode = self:GetGameMode( self.GameMode.Name )
	if currentMode and currentMode.Shutdown then
		currentMode:Shutdown()
	end

	-- Broadcast to all players
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "╔═══════════════════════════════════" )
			ply:ChatPrint( "║ Game Mode Ended: " .. self.GameMode.Name )
			ply:ChatPrint( "╚═══════════════════════════════════" )
		end
	end

	-- Reset gamemode
	self.GameMode.Active = false
	self.GameMode.Name = "None"
	self.GameMode.Teams = {}
	self.GameMode.Scores = {}
	self.GameMode.RoundActive = false

	print( "[Experimental Players] Stopped gamemode" )
end

--[[ Team System ]]--

function EXP:CreateTeam( teamID, teamName, teamColor )
	self.GameMode.Teams[ teamID ] = {
		name = teamName,
		color = teamColor or Color( 255, 255, 255 ),
		players = {},
		score = 0
	}

	print( "[Experimental Players] Created team: " .. teamName )
end

function EXP:AssignPlayerToTeam( ply, teamID )
	if !IsValid( ply ) then return end
	if !self.GameMode.Teams[ teamID ] then return end

	-- Remove from old team
	for id, team in pairs( self.GameMode.Teams ) do
		if team.players[ ply ] then
			team.players[ ply ] = nil
		end
	end

	-- Add to new team
	self.GameMode.Teams[ teamID ].players[ ply ] = true
	ply.exp_Team = teamID

	-- Set team color for visual identification
	local teamData = self.GameMode.Teams[ teamID ]
	if teamData.color then
		local col = teamData.color
		-- Convert Color to Vector for SetPlayerColor
		local colorVec = Vector( col.r / 255, col.g / 255, col.b / 255 )
		ply:SetPlayerColor( colorVec )
	end

	-- Network team info to clients
	ply:SetNW2Int( "exp_Team", teamID )
	ply:SetNW2String( "exp_TeamName", teamData.name )

	local teamName = teamData.name
	ply:ChatPrint( "[GAMEMODE] You have joined team: " .. teamName )

	print( "[Experimental Players] " .. ply:Nick() .. " joined team: " .. teamName )
end

function EXP:GetPlayerTeam( ply )
	if !IsValid( ply ) then return nil end
	return ply.exp_Team
end

function EXP:GetTeamPlayers( teamID )
	if !self.GameMode.Teams[ teamID ] then return {} end

	local players = {}
	for ply, _ in pairs( self.GameMode.Teams[ teamID ].players ) do
		if IsValid( ply ) then
			table.insert( players, ply )
		end
	end

	return players
end

function EXP:GetTeamScore( teamID )
	if !self.GameMode.Teams[ teamID ] then return 0 end
	return self.GameMode.Teams[ teamID ].score or 0
end

function EXP:AddTeamScore( teamID, amount )
	if !self.GameMode.Teams[ teamID ] then return end

	self.GameMode.Teams[ teamID ].score = ( self.GameMode.Teams[ teamID ].score or 0 ) + amount

	-- Network score to all clients
	SetGlobalInt( "exp_Team" .. teamID .. "_Score", self.GameMode.Teams[ teamID ].score )

	-- Broadcast score update with visual divider
	local teamName = self.GameMode.Teams[ teamID ].name
	local score = self.GameMode.Teams[ teamID ].score
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "═══════════════════════════════════" )
			ply:ChatPrint( "★ " .. teamName .. " SCORED! ★" )
			ply:ChatPrint( "Score: " .. score .. " points" )
			ply:ChatPrint( "═══════════════════════════════════" )
		end
	end

	-- Play notification sound
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			-- Check if it's their team
			if ply.exp_Team == teamID then
				ply:EmitSound( "buttons/button14.wav", 75, 100 )  -- Positive sound
			else
				ply:EmitSound( "buttons/button10.wav", 75, 100 )  -- Negative sound
			end
		end
	end
end

--[[ Round System ]]--

function EXP:StartRound( duration )
	self.GameMode.RoundActive = true
	self.GameMode.RoundStartTime = CurTime()
	self.GameMode.RoundTime = duration or 300  -- Default 5 minutes

	-- Respawn all players
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			if ply:Alive() then
				ply:Spawn()
			end
		end
	end

	-- Broadcast
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "╔═══════════════════════════════════" )
			ply:ChatPrint( "║ Round Started!" )
			ply:ChatPrint( "║ Duration: " .. duration .. " seconds" )
			ply:ChatPrint( "╚═══════════════════════════════════" )
		end
	end

	-- Call gamemode hook
	local currentMode = self:GetGameMode( self.GameMode.Name )
	if currentMode and currentMode.OnRoundStart then
		currentMode:OnRoundStart()
	end

	print( "[Experimental Players] Round started (Duration: " .. duration .. "s)" )
end

function EXP:EndRound()
	if !self.GameMode.RoundActive then return end

	self.GameMode.RoundActive = false

	-- Call gamemode hook
	local currentMode = self:GetGameMode( self.GameMode.Name )
	if currentMode and currentMode.OnRoundEnd then
		currentMode:OnRoundEnd()
	end

	-- Broadcast results
	self:BroadcastScores()

	print( "[Experimental Players] Round ended" )
end

function EXP:GetRoundTimeRemaining()
	if !self.GameMode.RoundActive then return 0 end

	local elapsed = CurTime() - self.GameMode.RoundStartTime
	local remaining = self.GameMode.RoundTime - elapsed

	return math.max( 0, remaining )
end

--[[ Scoring System ]]--

function EXP:BroadcastScores()
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "╔═══════════════════════════════════" )
			ply:ChatPrint( "║ SCORES:" )
			ply:ChatPrint( "╠═══════════════════════════════════" )

			for teamID, team in pairs( self.GameMode.Teams ) do
				ply:ChatPrint( "║ " .. team.name .. ": " .. ( team.score or 0 ) .. " points" )
			end

			ply:ChatPrint( "╚═══════════════════════════════════" )
		end
	end
end

function EXP:GetWinningTeam()
	local winningTeam = nil
	local highestScore = -1

	for teamID, team in pairs( self.GameMode.Teams ) do
		local score = team.score or 0
		if score > highestScore then
			highestScore = score
			winningTeam = teamID
		end
	end

	return winningTeam, highestScore
end

--[[ Auto-balance Teams ]]--

function EXP:AutoBalanceTeams()
	if table_Count( self.GameMode.Teams ) == 0 then return end

	local allPlayers = player.GetAll()
	if #allPlayers == 0 then return end

	-- Count teams
	local teamIDs = {}
	for teamID, _ in pairs( self.GameMode.Teams ) do
		table.insert( teamIDs, teamID )
	end

	if #teamIDs == 0 then return end

	-- Assign players to teams randomly
	for _, ply in ipairs( allPlayers ) do
		if IsValid( ply ) then
			local randomTeam = teamIDs[ math_random( #teamIDs ) ]
			self:AssignPlayerToTeam( ply, randomTeam )
		end
	end

	print( "[Experimental Players] Teams auto-balanced" )
end

--[[ Think Loop ]]--

-- Track last score broadcast time
_EXP_LastScoreBroadcast = 0
_EXP_LastTimeWarning = 0

hook.Add( "Think", "EXP_GameModeThink", function()
	if !EXP.GameMode.Active then return end
	if !EXP.GameMode.RoundActive then return end

	-- Check if round time expired
	if EXP:GetRoundTimeRemaining() <= 0 then
		EXP:EndRound()
		return
	end

	-- Periodic score updates (every 60 seconds)
	if CurTime() - _EXP_LastScoreBroadcast > 60 then
		_EXP_LastScoreBroadcast = CurTime()

		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "─────────────────────────────────" )
				ply:ChatPrint( "Current Scores:" )
				for teamID, team in pairs( EXP.GameMode.Teams ) do
					ply:ChatPrint( "  " .. team.name .. ": " .. ( team.score or 0 ) )
				end
				ply:ChatPrint( "─────────────────────────────────" )
			end
		end
	end

	-- Time warnings (at 60s, 30s, 10s remaining)
	local timeRemaining = math.floor( EXP:GetRoundTimeRemaining() )
	if ( timeRemaining == 60 or timeRemaining == 30 or timeRemaining == 10 ) and timeRemaining  ~=  _EXP_LastTimeWarning then
		_EXP_LastTimeWarning = timeRemaining

		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "⏰ " .. timeRemaining .. " seconds remaining!" )
				ply:EmitSound( "buttons/button17.wav", 75, 100 )
			end
		end
	end

	-- Call gamemode think
	local currentMode = EXP:GetGameMode( EXP.GameMode.Name )
	if currentMode and currentMode.Think then
		currentMode:Think()
	end
end )

--[[ Console Commands ]]--

concommand.Add( "exp_gamemode_start", function( ply, cmd, args )
	if #args < 1 then
		if IsValid( ply ) then
			ply:ChatPrint( "Usage: exp_gamemode_start <gamemode_name>" )
		else
			print( "Usage: exp_gamemode_start <gamemode_name>" )
		end
		return
	end

	local gamemodeName = args[ 1 ]
	EXP:StartGameMode( gamemodeName )
end )

concommand.Add( "exp_gamemode_stop", function( ply, cmd, args )
	EXP:StopGameMode()
end )

concommand.Add( "exp_round_start", function( ply, cmd, args )
	local duration = tonumber( args[ 1 ] ) or 300
	EXP:StartRound( duration )
end )

concommand.Add( "exp_round_end", function( ply, cmd, args )
	EXP:EndRound()
end )

concommand.Add( "exp_team_balance", function( ply, cmd, args )
	EXP:AutoBalanceTeams()
end )

print( "[Experimental Players] Gamemode base system loaded" )
