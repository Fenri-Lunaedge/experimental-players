-- Experimental Players - Weld Tool
-- Welds two entities together
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "weld", {
	Name = "Weld",
	Description = "Welds two props together",

	LeftClick = function( ply, trace, wepent )
		if !IsValid( ply ) then return false end
		if !trace.Hit then return false end
		if !IsValid( trace.Entity ) then return false end

		local ent = trace.Entity

		-- Must be a physics object
		local phys = ent:GetPhysicsObject()
		if !IsValid( phys ) then return false end

		-- Check permissions
		if ent.exp_Owner and ent.exp_Owner  ~=  ply then
			if EXP:GetConVar( "building_caneditothers" )  ~=  1 then
				return false
			end
		end

		-- Multi-stage tool (need 2 entities)
		if !ply.exp_ToolStage or ply.exp_ToolStage == 0 then
			-- Stage 1: Select first entity
			ply.exp_ToolEntity1 = ent
			ply.exp_ToolStage = 1

			-- Visual feedback
			ply:EmitSound( "buttons/button15.wav", 70, 100 )
			print( "[EXP] " .. ply:Nick() .. " selected first entity for weld" )

			return true

		elseif ply.exp_ToolStage == 1 then
			-- Stage 2: Select second entity and weld
			local ent1 = ply.exp_ToolEntity1
			local ent2 = ent

			if !IsValid( ent1 ) or !IsValid( ent2 ) then
				ply.exp_ToolStage = 0
				ply.exp_ToolEntity1 = nil
				return false
			end

			-- Can't weld to self
			if ent1 == ent2 then
				ply.exp_ToolStage = 0
				ply.exp_ToolEntity1 = nil
				return false
			end

			-- Create weld constraint
			local weld = constraint.Weld( ent1, ent2, 0, 0, 0, true, false )

			if weld then
				-- Success
				ply:EmitSound( "buttons/button9.wav", 70, 100 )
				print( "[EXP] " .. ply:Nick() .. " welded two entities together" )

				-- Reset tool state
				ply.exp_ToolStage = 0
				ply.exp_ToolEntity1 = nil

				return true
			else
				-- Failed
				ply:EmitSound( "buttons/button10.wav", 70, 100 )
				ply.exp_ToolStage = 0
				ply.exp_ToolEntity1 = nil
				return false
			end
		end

		return false
	end,
} )

print( "[Experimental Players] Weld tool loaded" )
