-- Experimental Players - Spawner Entity
-- Used in spawn menu to create player bots

ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.AutomaticFrameAdvance = false

ENT.PrintName = "Experimental Player Spawner"
ENT.Author = "Fenri-Lunaedge"
ENT.Category = "Experimental Players"
ENT.Spawnable = true
ENT.AdminOnly = false

if ( SERVER ) then

    function ENT:Initialize()
        -- Spawn a bot when this entity is created
        if EXP and EXP.CreateLambdaPlayer then
            local glace = EXP:CreateLambdaPlayer()
            if glace and glace._PLY and IsValid( glace._PLY ) then
                glace._PLY:SetPos( self:GetPos() )
            end
        end

        -- Remove the spawner entity
        self:Remove()
    end

    function ENT:Think()
        return false
    end

end

print( "[Experimental Players] Spawner entity loaded" )
