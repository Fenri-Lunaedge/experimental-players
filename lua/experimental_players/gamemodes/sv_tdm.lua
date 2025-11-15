-- Experimental Players - Team Deathmatch (TDM) Gamemode
-- Classic team-based deathmatch
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local math_random = math.random

--[[ TDM Gamemode ]]--

local TDM = {}

TDM.Name = "Team Deathmatch"
TDM.ShortName = "TDM"
TDM.ScoreLimit = 50  -- First team to 50 kills wins
TDM.RoundDuration = 600  -- 10 minutes

function TDM:Initialize()
	-- Create two teams
	EXP:CreateTeam( 1, "Red Team", Color( 255, 50, 50 ) )
	EXP:CreateTeam( 2, "Blue Team", Color( 50, 50, 255 ) )

	-- Auto-balance teams
	EXP:AutoBalanceTeams()

	-- Start round
	EXP:StartRound( self.RoundDuration )

	print( "[TDM] Initialized" )
end

function TDM:Shutdown()
	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Final Score: " .. score .. " kills" )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end

	print( "[TDM] Shutdown" )
end

function TDM:OnRoundStart()
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			ply:ChatPrint( "[TDM] First team to " .. self.ScoreLimit .. " kills wins!" )
		end
	end
end

function TDM:OnRoundEnd()
	-- Announce winner
	local winningTeam, score = EXP:GetWinningTeam()

	if winningTeam then
		local teamData = EXP.GameMode.Teams[ winningTeam ]
		for _, ply in ipairs( player.GetAll() ) do
			if IsValid( ply ) then
				ply:ChatPrint( "╔═══════════════════════════════════" )
				ply:ChatPrint( "║ TIME'S UP!" )
				ply:ChatPrint( "║ " .. teamData.name .. " WINS!" )
				ply:ChatPrint( "║ Final Score: " .. score .. " kills" )
				ply:ChatPrint( "╚═══════════════════════════════════" )
			end
		end
	end
end

function TDM:Think()
	-- Check score limit
	for teamID, team in pairs( EXP.GameMode.Teams ) do
		if ( team.score or 0 ) >= self.ScoreLimit then
			-- Team reached score limit, end round
			EXP:EndRound()
			break
		end
	end
end

--[[ Kill Tracking ]]--

hook.Add( "PlayerDeath", "EXP_TDM_TrackKills", function( victim, inflictor, attacker )
	if !EXP.GameMode.Active then return end
	if EXP.GameMode.Name != "TDM" then return end
	if !EXP.GameMode.RoundActive then return end

	if !IsValid( attacker ) or !IsValid( victim ) then return end
	if attacker == victim then return end  -- Suicide

	-- Get attacker's team
	local attackerTeam = EXP:GetPlayerTeam( attacker )
	local victimTeam = EXP:GetPlayerTeam( victim )

	if !attackerTeam or !victimTeam then return end

	-- Don't award points for team kills
	if attackerTeam == victimTeam then
		attacker:ChatPrint( "[TDM] Teamkill! No points awarded." )
		return
	end

	-- Award point to attacker's team
	EXP:AddTeamScore( attackerTeam, 1 )

	print( "[TDM] " .. attacker:Nick() .. " killed " .. victim:Nick() )
end )

--[[ Register Gamemode ]]--

EXP:RegisterGameMode( "TDM", TDM )

print( "[Experimental Players] Team Deathmatch gamemode loaded" )
