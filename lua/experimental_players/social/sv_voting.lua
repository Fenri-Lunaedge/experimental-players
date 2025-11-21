-- Experimental Players - Voting System
-- Adapted from Zeta Players voting
-- Server-side only

if ( CLIENT ) then return end

local math_random = math.random
local string_lower = string.lower
local CurTime = CurTime
local IsValid = IsValid
local table_Count = table.Count

--[[ Global Vote State ]]--

_EXP_CurrentVote = "NIL"  -- Current vote title or "NIL" if no active vote
_EXP_CurrentVotedOptions = {}  -- Tracks vote counts {option = count}
_EXP_VoteQuickIndex = {}  -- Quick index for numeric option selection (1, 2, 3...)
_EXP_VoteTimer = nil  -- Timer for vote duration

--[[ Vote Creation ]]--

function EXP_CreateVote( ply, title, options )
	-- Check if vote already active
	if _EXP_CurrentVote  ~=  "NIL" then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] Vote already in progress: " .. _EXP_CurrentVote )
		end
		return false
	end

	-- Validate title
	if !title or title == "" then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] Vote title cannot be empty!" )
		end
		return false
	end

	-- Validate options
	if !options or !istable( options ) then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] Vote options must be a table!" )
		end
		return false
	end

	local optionCount = #options
	if optionCount < 2 then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] Vote must have at least 2 options!" )
		end
		return false
	end

	if optionCount > 10 then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] Vote cannot have more than 10 options!" )
		end
		return false
	end

	-- Initialize vote
	_EXP_CurrentVote = title
	_EXP_CurrentVotedOptions = {}
	_EXP_VoteQuickIndex = {}

	for i, option in ipairs( options ) do
		_EXP_CurrentVotedOptions[ option ] = 0
		_EXP_VoteQuickIndex[ i ] = option
	end

	-- Broadcast vote start
	local initiatorName = IsValid( ply ) and ply:Nick() or "Console"
	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "╔═══════════════════════════════════" )
			recipient:ChatPrint( "║ " .. initiatorName .. " started a vote:" )
			recipient:ChatPrint( "║ " .. title )
			recipient:ChatPrint( "╠═══════════════════════════════════" )
			for i, option in ipairs( options ) do
				recipient:ChatPrint( "║ [" .. i .. "] " .. option )
			end
			recipient:ChatPrint( "╚═══════════════════════════════════" )
			recipient:ChatPrint( "Type ',vote <option>' or ',vote <number>' to vote!" )
		end
	end

	-- Trigger hook for bots
	hook.Run( "EXP_OnVoteDispatched", ply, title, options )

	-- Set timer for vote completion (10 seconds)
	-- FIX: Timer names are strings, not entities - don't use IsValid()
	local timerName = "EXP_VoteTimer"
	if timer.Exists( timerName ) then
		timer.Remove( timerName )
	end

	timer.Create( timerName, 10, 1, function()
		EXP_CompileVoteResults()
	end )

	print( "[Experimental Players] Vote created: " .. title )
	return true
end

--[[ Vote Dispatch (Cast Vote) ]]--

function EXP_DispatchVote( voter, option )
	-- Check if vote is active
	if _EXP_CurrentVote == "NIL" then
		if IsValid( voter ) then
			voter:ChatPrint( "[Experimental Players] No active vote!" )
		end
		return false
	end

	-- Normalize option
	local normalizedOption = tostring( option )

	-- Check if numeric index
	local asNumber = tonumber( normalizedOption )
	if asNumber then
		local indexedOption = _EXP_VoteQuickIndex[ asNumber ]
		if indexedOption then
			normalizedOption = indexedOption
		else
			if IsValid( voter ) then
				voter:ChatPrint( "[Experimental Players] Invalid option number: " .. asNumber )
			end
			return false
		end
	end

	-- Check if option exists
	if _EXP_CurrentVotedOptions[ normalizedOption ] == nil then
		if IsValid( voter ) then
			voter:ChatPrint( "[Experimental Players] Invalid option: " .. normalizedOption )
		end
		return false
	end

	-- Increment vote count
	_EXP_CurrentVotedOptions[ normalizedOption ] = _EXP_CurrentVotedOptions[ normalizedOption ] + 1

	-- Broadcast vote
	local voterName = IsValid( voter ) and voter:Nick() or "Unknown"
	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "[VOTE] " .. voterName .. " voted for: " .. normalizedOption )
		end
	end

	print( "[Experimental Players] " .. voterName .. " voted for: " .. normalizedOption )
	return true
end

--[[ Vote Results ]]--

function EXP_CompileVoteResults()
	if _EXP_CurrentVote == "NIL" then
		return nil, 0
	end

	local winningOption = nil
	local winningVotes = 0
	local tiedOptions = {}

	-- Find highest vote count
	for option, votes in pairs( _EXP_CurrentVotedOptions ) do
		if votes > winningVotes then
			winningOption = option
			winningVotes = votes
			tiedOptions = { option }
		elseif votes == winningVotes and votes > 0 then
			table.insert( tiedOptions, option )
		end
	end

	-- Handle ties
	-- FIX: Only consider it a tie if there were actual votes
	if #tiedOptions > 1 and winningVotes > 0 then
		winningOption = tiedOptions[ math_random( #tiedOptions ) ]
	elseif winningVotes == 0 then
		-- No votes at all
		winningOption = nil
	end

	-- Broadcast results
	local voteTitle = _EXP_CurrentVote
	for _, recipient in ipairs( player.GetAll() ) do
		if IsValid( recipient ) then
			recipient:ChatPrint( "╔═══════════════════════════════════" )
			recipient:ChatPrint( "║ Vote Results: " .. voteTitle )
			recipient:ChatPrint( "╠═══════════════════════════════════" )

			-- Show all results
			for option, votes in pairs( _EXP_CurrentVotedOptions ) do
				local marker = ( option == winningOption ) and "★ " or "  "
				recipient:ChatPrint( "║ " .. marker .. option .. ": " .. votes .. " votes" )
			end

			recipient:ChatPrint( "╠═══════════════════════════════════" )
			if winningOption then
				recipient:ChatPrint( "║ Winner: " .. winningOption .. " (" .. winningVotes .. " votes)" )
			else
				recipient:ChatPrint( "║ No votes cast!" )
			end
			recipient:ChatPrint( "╚═══════════════════════════════════" )
		end
	end

	-- Trigger hook
	hook.Run( "EXP_OnVoteResults", voteTitle, winningOption, winningVotes, _EXP_CurrentVotedOptions )

	-- Reset vote
	_EXP_CurrentVote = "NIL"
	_EXP_CurrentVotedOptions = {}
	_EXP_VoteQuickIndex = {}

	-- FIX: Clean up bot vote timers when vote ends
	if _EXP_BotVoteTimers then
		for _, timerName in ipairs( _EXP_BotVoteTimers ) do
			if timer.Exists( timerName ) then
				timer.Remove( timerName )
			end
		end
		_EXP_BotVoteTimers = {}
	end

	print( "[Experimental Players] Vote ended. Winner: " .. ( winningOption or "None" ) )
	return winningOption, winningVotes
end

--[[ Vote Command Parsing ]]--

function EXP_ParseVoteCommand( text )
	-- Expected format: ,startvote "Title" option1 option2 option3
	-- or: ,startvote Title option1 option2

	local title, optionsStr = string.match( text, ',startvote%s+"([^"]+)"%s+(.+)' )

	if !title then
		-- Try without quotes
		local parts = string.Explode( " ", text )
		if #parts < 4 then return nil, nil end

		-- Remove ,startvote
		table.remove( parts, 1 )

		-- First part is title
		title = parts[ 1 ]
		table.remove( parts, 1 )

		-- Rest are options
		return title, parts
	end

	-- Parse options
	local options = string.Explode( " ", optionsStr )
	return title, options
end

--[[ Player Chat Commands ]]--

hook.Add( "PlayerSay", "EXP_VoteCommands", function( ply, text )
	if !IsValid( ply ) or !text then return end

	local lowerText = string_lower( text )

	-- Start vote command
	if string.StartWith( lowerText, ",startvote" ) then
		local title, options = EXP_ParseVoteCommand( text )

		if !title or !options then
			ply:ChatPrint( "[Experimental Players] Usage: ,startvote \"Title\" option1 option2 option3" )
			return ""
		end

		EXP_CreateVote( ply, title, options )
		return ""
	end

	-- Cast vote command
	if string.StartWith( lowerText, ",vote " ) then
		local option = string.sub( text, 7 )  -- Remove ",vote "
		option = string.Trim( option )

		if !option or option == "" then
			ply:ChatPrint( "[Experimental Players] Usage: ,vote <option> or ,vote <number>" )
			return ""
		end

		EXP_DispatchVote( ply, option )
		return ""
	end
end )

--[[ Bot Integration ]]--

-- Bots randomly participate in votes
hook.Add( "EXP_OnVoteDispatched", "EXP_BotVoting", function( initiator, title, options )
	if !EXP.ActiveBots then return end

	-- FIX: Track bot vote timers to clean them up if vote ends early
	if !_EXP_BotVoteTimers then
		_EXP_BotVoteTimers = {}
	end

	-- Clear any existing bot vote timers
	for _, timerName in ipairs( _EXP_BotVoteTimers ) do
		if timer.Exists( timerName ) then
			timer.Remove( timerName )
		end
	end
	_EXP_BotVoteTimers = {}

	for i, bot in ipairs( EXP.ActiveBots ) do
		if !IsValid( bot._PLY ) then continue end

		-- 33% chance to vote
		if math_random( 1, 100 ) > 33 then continue end

		-- Random delay before voting
		local delay = math_random( 1, 8 )
		local timerName = "EXP_BotVote_" .. i .. "_" .. CurTime()
		table.insert( _EXP_BotVoteTimers, timerName )

		timer.Simple( delay, timerName, function()
			if IsValid( bot._PLY ) and _EXP_CurrentVote  ~=  "NIL" then
				-- Pick random option
				local randomOption = options[ math_random( #options ) ]
				EXP_DispatchVote( bot._PLY, randomOption )
			end
		end )
	end
end )

--[[ Console Commands ]]--

concommand.Add( "exp_startvote", function( ply, cmd, args )
	if #args < 3 then
		if IsValid( ply ) then
			ply:ChatPrint( "Usage: exp_startvote <title> <option1> <option2> [option3] ..." )
		else
			print( "Usage: exp_startvote <title> <option1> <option2> [option3] ..." )
		end
		return
	end

	local title = args[ 1 ]
	local options = {}
	for i = 2, #args do
		table.insert( options, args[ i ] )
	end

	EXP_CreateVote( ply, title, options )
end )

concommand.Add( "exp_vote", function( ply, cmd, args )
	if #args < 1 then
		if IsValid( ply ) then
			ply:ChatPrint( "Usage: exp_vote <option>" )
		end
		return
	end

	local option = args[ 1 ]
	EXP_DispatchVote( ply, option )
end )

concommand.Add( "exp_endvote", function( ply, cmd, args )
	if _EXP_CurrentVote == "NIL" then
		if IsValid( ply ) then
			ply:ChatPrint( "[Experimental Players] No active vote!" )
		else
			print( "[Experimental Players] No active vote!" )
		end
		return
	end

	EXP_CompileVoteResults()
end )

print( "[Experimental Players] Voting system loaded" )
