-- Experimental Players - Hydraulic Tool
-- Creates hydraulic (powered) constraints
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "hydraulic", {
	Name = "Hydraulic",
	Description = "Creates powered hydraulic constraints",

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

			local hydraulic = constraint.Hydraulic(
				ent1, ent2,
				0, 0,
				ent1:WorldToLocal( ply.exp_ToolPos1 ),
				ent2:WorldToLocal( trace.HitPos ),
				50, -- Fixed length
				0, -- No material
				math.random( 10, 50 ), -- Speed
				0 -- No elasticity
			)

			if hydraulic then
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " created hydraulic" )
			else
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
			end

			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			return hydraulic  ~=  nil
		end

		return false
	end,
} )

print( "[Experimental Players] Hydraulic tool loaded" )
