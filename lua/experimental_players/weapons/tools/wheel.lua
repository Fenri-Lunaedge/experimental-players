-- Experimental Players - Wheel Tool
-- Creates motorized wheels
-- Server-side only

if ( CLIENT ) then return end

EXP:RegisterTool( "wheel", {
	Name = "Wheel",
	Description = "Creates motorized wheels",

	LeftClick = function( ply, trace, wepent )
		if !IsValid( ply ) then return false end
		if !trace.Hit then return false end
		if !IsValid( trace.Entity ) then return false end

		local ent = trace.Entity
		if !IsValid( ent:GetPhysicsObject() ) then return false end

		-- Create a wheel constraint to world
		local wheel = constraint.Motor(
			ent, -- Entity
			game.GetWorld(), -- Anchor to world
			0, 0,
			ent:WorldToLocal( trace.HitPos ),
			Vector( 0, 0, 0 ),
			1, -- Friction
			math.random( 100, 500 ), -- Torque
			0, -- Force limit
			false, -- Not nocollide
			false -- Not local axis
		)

		if wheel then
			ply:EmitSound( "buttons/button9.wav", 70, 100 )
			print( "[EXP] " .. ply:Nick() .. " created wheel" )
		else
			ply:EmitSound( "buttons/button10.wav", 70, 100 )
		end

		return wheel  ~=  nil
	end,
} )

print( "[Experimental Players] Wheel tool loaded" )
