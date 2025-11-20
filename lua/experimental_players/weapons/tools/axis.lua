-- Experimental Players - Axis Tool
-- Creates rotating constraints between props
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "axis", {
	Name = "Axis",
	Description = "Creates a rotating axis between two props",

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
			print( "[EXP] " .. ply:Nick() .. " selected first entity for axis" )
			return true

		elseif ply.exp_ToolStage == 1 then
			-- Stage 2: Select second entity and create axis
			local ent1 = ply.exp_ToolEntity1
			local ent2 = ent
			local pos1 = ply.exp_ToolPos1

			if !IsValid( ent1 ) or !IsValid( ent2 ) then
				ply.exp_ToolStage = 0
				return false
			end

			if ent1 == ent2 then
				ply.exp_ToolStage = 0
				return false
			end

			-- Calculate axis vector
			local pos2 = trace.HitPos
			local axisVec = ( pos2 - pos1 ):GetNormalized()

			-- Create axis constraint
			local axis = constraint.Axis(
				ent1, ent2,
				0, 0,
				ent1:WorldToLocal( pos1 ),
				ent2:WorldToLocal( pos2 ),
				0, 0, -- No force limit
				0, -- No torque
				1, -- Friction
				0  -- No local axis
			)

			if axis then
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " created axis constraint" )
			else
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
			end

			-- Reset
			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			ply.exp_ToolPos1 = nil

			return axis  ~=  nil
		end

		return false
	end,
} )

print( "[Experimental Players] Axis tool loaded" )
