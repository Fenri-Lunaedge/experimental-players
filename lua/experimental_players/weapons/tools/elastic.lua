-- Experimental Players - Elastic Tool
-- Creates elastic/spring constraints
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "elastic", {
	Name = "Elastic",
	Description = "Creates elastic/spring connections",

	LeftClick = function( ply, trace, wepent )
		if !IsValid( ply ) then return false end
		if !trace.Hit then return false end
		if !IsValid( trace.Entity ) then return false end

		local ent = trace.Entity
		local phys = ent:GetPhysicsObject()
		if !IsValid( phys ) then return false end

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
			local pos1 = ply.exp_ToolPos1
			local pos2 = trace.HitPos

			if !IsValid( ent1 ) or !IsValid( ent2 ) or ent1 == ent2 then
				ply.exp_ToolStage = 0
				return false
			end

			local length = pos1:Distance( pos2 )
			local elastic = constraint.Elastic(
				ent1, ent2,
				0, 0,
				ent1:WorldToLocal( pos1 ),
				ent2:WorldToLocal( pos2 ),
				math.random( 500, 2000 ), -- Constant (stiffness)
				math.random( 50, 200 ), -- Damping
				0, -- No elasticity
				"cable/rope",
				2,
				false
			)

			if elastic then
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " created elastic constraint" )
			else
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
			end

			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			return elastic  ~=  nil
		end

		return false
	end,
} )

print( "[Experimental Players] Elastic tool loaded" )
