-- Experimental Players - Ball Socket Tool
-- Creates ball-socket joint constraints
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "ballsocket", {
	Name = "Ball Socket",
	Description = "Creates rotating ball-socket joints",

	LeftClick = function( ply, trace, wepent )
		if !IsValid( ply ) then return false end
		if !trace.Hit then return false end
		if !IsValid( trace.Entity ) then return false end

		local ent = trace.Entity
		if !IsValid( ent:GetPhysicsObject() ) then return false end
		if ent.exp_Owner and ent.exp_Owner  ~=  ply then
			if EXP:GetConVar( "building_caneditothers" )  ~=  1 then return false end
		end

		if !ply.exp_ToolStage or ply.exp_ToolStage == 0 then
			ply.exp_ToolEntity1 = ent
			ply.exp_ToolPos1 = trace.HitPos
			ply.exp_ToolStage = 1
			ply:EmitSound( "buttons/button15.wav", 70, 100 )
			return true

		elseif ply.exp_ToolStage == 1 then
			local ent1 = ply.exp_ToolEntity1
			local ent2 = ent

			if !IsValid( ent1 ) or !IsValid( ent2 ) or ent1 == ent2 then
				ply.exp_ToolStage = 0
				return false
			end

			local ballsocket = constraint.Ballsocket(
				ent1, ent2,
				0, 0,
				ent1:WorldToLocal( ply.exp_ToolPos1 ),
				0, -- Force limit
				0, -- Torque limit
				0  -- Only collision
			)

			if ballsocket then
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " created ball socket" )
			else
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
			end

			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			return ballsocket  ~=  nil
		end

		return false
	end,
} )

print( "[Experimental Players] Ball Socket tool loaded" )
