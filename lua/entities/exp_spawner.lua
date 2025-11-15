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
            local bot = EXP:CreateLambdaPlayer()
            if IsValid( bot ) then
                bot:SetPos( self:GetPos() )
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
