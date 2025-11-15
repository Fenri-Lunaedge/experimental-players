-- Experimental Players - Player Admin Commands
-- Allows real players to execute admin commands on bots
-- Server-side only

if ( CLIENT ) then return end

local string_lower = string.lower
local string_Trim = string.Trim
local string_Explode = string.Explode
local IsValid = IsValid

--[[ Helper: Find Bot by Name ]]--

local function FindBotByName( name )
	if !name or name == "" then return nil end

	name = string_lower( name )

	-- Search active bots
	if EXP.ActiveBots then
		for _, bot in ipairs( EXP.ActiveBots ) do
			if IsValid( bot._PLY ) then
				local botName = string_lower( bot._PLY:Nick() )
				if string.find( botName, name, 1, true ) then
					return bot._PLY
				end
			end
		end
	end

	-- Search all players (in case it's a real player)
	for _, ply in ipairs( player.GetAll() ) do
		if IsValid( ply ) then
			local plyName = string_lower( ply:Nick() )
			if string.find( plyName, name, 1, true ) then
				return ply
			end
		end
	end

	return nil
end

--[[ Helper: Get Bot GLACE Wrapper ]]--

local function GetBotGLACE( ply )
	if !IsValid( ply ) then return nil end
	if !ply.exp_IsExperimentalPlayer then return nil end

	if EXP.ActiveBots then
		for _, bot in ipairs( EXP.ActiveBots ) do
			if bot._PLY == ply then
				return bot
			end
		end
	end

	return nil
end

--[[ Player Chat Commands ]]--

hook.Add( "PlayerSay", "EXP_AdminCommands", function( ply, text )
	if !IsValid( ply ) or !text then return end

	local lowerText = string_lower( text )

	-- Goto command: ,goto <name>
	if string.StartWith( lowerText, ",goto " ) then
		local targetName = string_Trim( string.sub( text, 7 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		ply:SetPos( target:GetPos() + Vector( 0, 0, 10 ) )
		ply:ChatPrint( "[ADMIN] Teleported to " .. target:Nick() )
		return ""
	end

	-- Bring command: ,bring <name>
	if string.StartWith( lowerText, ",bring " ) then
		local targetName = string_Trim( string.sub( text, 8 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:SetPos( ply:GetPos() + ply:GetForward() * 100 + Vector( 0, 0, 10 ) )
		ply:ChatPrint( "[ADMIN] Brought " .. target:Nick() )
		return ""
	end

	-- Return command: ,return <name>
	if string.StartWith( lowerText, ",return " ) then
		local targetName = string_Trim( string.sub( text, 9 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		if !target.exp_LastPosition then
			ply:ChatPrint( "[ADMIN] No last position stored!" )
			return ""
		end

		target:SetPos( target.exp_LastPosition )
		ply:ChatPrint( "[ADMIN] Returned " .. target:Nick() )
		return ""
	end

	-- Slay command: ,slay <name>
	if string.StartWith( lowerText, ",slay " ) then
		local targetName = string_Trim( string.sub( text, 7 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		local dmginfo = DamageInfo()
		dmginfo:SetDamage( 999999 )
		dmginfo:SetAttacker( ply )
		dmginfo:SetDamageType( DMG_GENERIC )
		target:TakeDamageInfo( dmginfo )

		ply:ChatPrint( "[ADMIN] Slayed " .. target:Nick() )
		return ""
	end

	-- Kick command: ,kick <name> <reason>
	if string.StartWith( lowerText, ",kick " ) then
		local args = string_Explode( " ", string.sub( text, 7 ) )
		if #args < 1 then
			ply:ChatPrint( "[ADMIN] Usage: ,kick <name> [reason]" )
			return ""
		end

		local targetName = args[ 1 ]
		table.remove( args, 1 )
		local reason = table.concat( args, " " )
		if reason == "" then reason = "Kicked by admin" end

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:Kick( reason )
		ply:ChatPrint( "[ADMIN] Kicked " .. target:Nick() .. ": " .. reason )
		return ""
	end

	-- Ban command: ,ban <name> <time> <reason>
	if string.StartWith( lowerText, ",ban " ) then
		local args = string_Explode( " ", string.sub( text, 6 ) )
		if #args < 2 then
			ply:ChatPrint( "[ADMIN] Usage: ,ban <name> <time_seconds> [reason]" )
			return ""
		end

		local targetName = args[ 1 ]
		local duration = tonumber( args[ 2 ] ) or 300
		table.remove( args, 1 )
		table.remove( args, 1 )
		local reason = table.concat( args, " " )
		if reason == "" then reason = "Banned by admin" end

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		-- Use admin system
		local botGLACE = GetBotGLACE( ply )
		if botGLACE and botGLACE.COMMAND_Ban then
			botGLACE:COMMAND_Ban( target, duration, reason )
		else
			-- Fallback for real players
			if target.exp_IsExperimentalPlayer then
				_EXP_BannedPlayers[ target:AccountID() ] = {
					name = target:Nick(),
					unbanTime = CurTime() + duration,
					reason = reason
				}
				target:Kick( "Banned: " .. reason )
			else
				_EXP_BannedPlayers[ target:SteamID() ] = {
					name = target:Nick(),
					unbanTime = CurTime() + duration,
					reason = reason
				}
				target:Kick( "Banned: " .. reason .. " (" .. duration .. "s)" )
			end

			ply:ChatPrint( "[ADMIN] Banned " .. target:Nick() .. " for " .. duration .. "s: " .. reason )
		end
		return ""
	end

	-- Slap command: ,slap <name> [damage]
	if string.StartWith( lowerText, ",slap " ) then
		local args = string_Explode( " ", string.sub( text, 7 ) )
		if #args < 1 then
			ply:ChatPrint( "[ADMIN] Usage: ,slap <name> [damage]" )
			return ""
		end

		local targetName = args[ 1 ]
		local damage = tonumber( args[ 2 ] ) or math.random( 0, 100 )

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		local dmginfo = DamageInfo()
		dmginfo:SetDamage( damage )
		dmginfo:SetAttacker( ply )
		dmginfo:SetDamageType( DMG_CLUB )
		target:TakeDamageInfo( dmginfo )

		target:SetVelocity( Vector( math.Rand( -500, 500 ), math.Rand( -500, 500 ), 500 ) )
		target:EmitSound( "physics/body/body_medium_impact_hard" .. math.random( 1, 6 ) .. ".wav", 75 )

		ply:ChatPrint( "[ADMIN] Slapped " .. target:Nick() .. " for " .. damage .. " damage" )
		return ""
	end

	-- Whip command: ,whip <name> [damage] [times]
	if string.StartWith( lowerText, ",whip " ) then
		local args = string_Explode( " ", string.sub( text, 7 ) )
		if #args < 1 then
			ply:ChatPrint( "[ADMIN] Usage: ,whip <name> [damage] [times]" )
			return ""
		end

		local targetName = args[ 1 ]
		local damage = tonumber( args[ 2 ] ) or math.random( 0, 20 )
		local times = tonumber( args[ 3 ] ) or math.random( 1, 10 )

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		ply:ChatPrint( "[ADMIN] Whipping " .. target:Nick() .. " " .. times .. " times" )

		for i = 1, times do
			timer.Simple( i * 0.5, function()
				if IsValid( target ) then
					local dmginfo = DamageInfo()
					dmginfo:SetDamage( damage )
					dmginfo:SetAttacker( ply )
					dmginfo:SetDamageType( DMG_CLUB )
					target:TakeDamageInfo( dmginfo )

					target:SetVelocity( Vector( math.Rand( -500, 500 ), math.Rand( -500, 500 ), 500 ) )
					target:EmitSound( "physics/body/body_medium_impact_hard" .. math.random( 1, 6 ) .. ".wav", 75 )
				end
			end )
		end
		return ""
	end

	-- Ignite command: ,ignite <name> [seconds]
	if string.StartWith( lowerText, ",ignite " ) then
		local args = string_Explode( " ", string.sub( text, 9 ) )
		if #args < 1 then
			ply:ChatPrint( "[ADMIN] Usage: ,ignite <name> [seconds]" )
			return ""
		end

		local targetName = args[ 1 ]
		local duration = tonumber( args[ 2 ] ) or 10

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:Ignite( duration )
		ply:ChatPrint( "[ADMIN] Ignited " .. target:Nick() .. " for " .. duration .. "s" )
		return ""
	end

	-- Set Health command: ,sethealth <name> <value>
	if string.StartWith( lowerText, ",sethealth " ) then
		local args = string_Explode( " ", string.sub( text, 12 ) )
		if #args < 2 then
			ply:ChatPrint( "[ADMIN] Usage: ,sethealth <name> <value>" )
			return ""
		end

		local targetName = args[ 1 ]
		local health = tonumber( args[ 2 ] ) or 100

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:SetHealth( health )
		ply:ChatPrint( "[ADMIN] Set " .. target:Nick() .. " health to " .. health )
		return ""
	end

	-- Set Armor command: ,setarmor <name> <value>
	if string.StartWith( lowerText, ",setarmor " ) then
		local args = string_Explode( " ", string.sub( text, 11 ) )
		if #args < 2 then
			ply:ChatPrint( "[ADMIN] Usage: ,setarmor <name> <value>" )
			return ""
		end

		local targetName = args[ 1 ]
		local armor = tonumber( args[ 2 ] ) or 100

		local target = FindBotByName( targetName )
		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:SetArmor( armor )
		ply:ChatPrint( "[ADMIN] Set " .. target:Nick() .. " armor to " .. armor )
		return ""
	end

	-- Godmode command: ,god <name>
	if string.StartWith( lowerText, ",god " ) then
		local targetName = string_Trim( string.sub( text, 6 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target.exp_InGodmode = true
		ply:ChatPrint( "[ADMIN] Enabled godmode for " .. target:Nick() )
		return ""
	end

	-- Ungod command: ,ungod <name>
	if string.StartWith( lowerText, ",ungod " ) then
		local targetName = string_Trim( string.sub( text, 8 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target.exp_InGodmode = false
		ply:ChatPrint( "[ADMIN] Disabled godmode for " .. target:Nick() )
		return ""
	end

	-- Jail command: ,jail <name>
	if string.StartWith( lowerText, ",jail " ) then
		local targetName = string_Trim( string.sub( text, 7 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		EXP_CreateJailOnEnt( target )
		ply:ChatPrint( "[ADMIN] Jailed " .. target:Nick() )
		return ""
	end

	-- Unjail command: ,unjail <name>
	if string.StartWith( lowerText, ",unjail " ) then
		local targetName = string_Trim( string.sub( text, 9 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		EXP_RemoveJailOnEnt( target )
		ply:ChatPrint( "[ADMIN] Unjailed " .. target:Nick() )
		return ""
	end

	-- TpJail command: ,tpjail <name>
	if string.StartWith( lowerText, ",tpjail " ) then
		local targetName = string_Trim( string.sub( text, 9 ) )
		local target = FindBotByName( targetName )

		if !IsValid( target ) then
			ply:ChatPrint( "[ADMIN] Could not find: " .. targetName )
			return ""
		end

		target:SetPos( ply:GetPos() + ply:GetForward() * 100 + Vector( 0, 0, 10 ) )
		timer.Simple( 0.1, function()
			if IsValid( target ) then
				EXP_CreateJailOnEnt( target )
			end
		end )

		ply:ChatPrint( "[ADMIN] Teleported and jailed " .. target:Nick() )
		return ""
	end
end )

print( "[Experimental Players] Admin commands loaded" )
