-- Experimental Players - Rope Tool
-- Creates rope constraints between props
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "rope", {
	Name = "Rope",
	Description = "Connects two props with a rope",

	LeftClick = function( ply, trace, wepent )
		if !IsValid( ply ) then return false end
		if !trace.Hit then return false end
		if !IsValid( trace.Entity ) then return false end

		local ent = trace.Entity
		local phys = ent:GetPhysicsObject()
		if !IsValid( phys ) then return false end

		-- Check permissions
		if ent.exp_Owner and ent.exp_Owner  ~=  ply then
			if EXP:GetConVar( "building_caneditothers" )  ~=  1 then
				return false
			end
		end

		-- Multi-stage tool
		if !ply.exp_ToolStage or ply.exp_ToolStage == 0 then
			-- Stage 1: Select first entity
			ply.exp_ToolEntity1 = ent
			ply.exp_ToolPos1 = trace.HitPos
			ply.exp_ToolStage = 1

			ply:EmitSound( "buttons/button15.wav", 70, 100 )
			print( "[EXP] " .. ply:Nick() .. " selected first entity for rope" )
			return true

		elseif ply.exp_ToolStage == 1 then
			-- Stage 2: Select second entity and create rope
			local ent1 = ply.exp_ToolEntity1
			local ent2 = ent
			local pos1 = ply.exp_ToolPos1
			local pos2 = trace.HitPos

			if !IsValid( ent1 ) or !IsValid( ent2 ) then
				ply.exp_ToolStage = 0
				return false
			end

			-- Calculate rope length
			local length = pos1:Distance( pos2 )
			length = math.max( length, 50 ) -- Minimum 50 units

			-- Random rope properties
			local ropeWidth = math.random( 1, 3 )
			local ropeMaterial = "cable/rope"

			-- Create rope constraint
			local rope = constraint.Rope(
				ent1, ent2,
				0, 0,
				ent1:WorldToLocal( pos1 ),
				ent2:WorldToLocal( pos2 ),
				length,
				0, -- No slack
				0, -- Force limit
				ropeWidth,
				ropeMaterial,
				false -- Not rigid
			)

			if rope then
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " created rope (" .. math.floor( length ) .. " units)" )
			else
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
			end

			-- Reset
			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			ply.exp_ToolPos1 = nil

			return rope  ~=  nil
		end

		return false
	end,
} )

print( "[Experimental Players] Rope tool loaded" )
