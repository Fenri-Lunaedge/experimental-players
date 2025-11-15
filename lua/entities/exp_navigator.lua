-- Experimental Players - Navigator Entity
-- Handles pathfinding for player bots
-- Based on GLambda's glace_navigator

ENT.Type = "nextbot"
ENT.Base = "base_nextbot"
ENT.AutomaticFrameAdvance = true

ENT.PrintName = "Experimental Navigator"
ENT.Author = "Fenri-Lunaedge"
ENT.Spawnable = false
ENT.AdminOnly = false

if ( SERVER ) then

    function ENT:Initialize()
        self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
        self:SetSolid( SOLID_NONE )
        self:SetMoveType( MOVETYPE_NONE )
        self:SetNoDraw( true )
        self:SetNotSolid( true )
        self:DrawShadow( false )

        -- Pathfinding properties
        self.path = nil
        self.pathAge = 0
        self.pathGoal = Vector( 0, 0, 0 )
        self.pathOptions = {}
        self.currentSegment = 1
    end

    function ENT:ComputePath( goal, options )
        self.pathGoal = goal
        self.pathOptions = options or {}

        -- Create path
        local path = Path( "Follow" )
        if !path:IsValid() then return false end

        path:SetMinLookAheadDistance( options.lookahead or 300 )
        path:SetGoalTolerance( options.tolerance or 20 )

        local result = path:Compute( self, goal, options.generator )
        if !result then
            return false
        end

        self.path = path
        self.pathAge = 0
        self.currentSegment = 1
        return true
    end

    function ENT:GetPath()
        return self.path
    end

    function ENT:IsPathValid()
        return self.path and self.path:IsValid()
    end

    function ENT:InvalidatePath()
        self.path = nil
        self.currentSegment = 1
    end

    function ENT:GetCurrentSegment()
        return self.currentSegment
    end

    function ENT:AdvanceSegment()
        self.currentSegment = self.currentSegment + 1
    end

    function ENT:RecomputePath()
        if !self.pathGoal then return false end
        return self:ComputePath( self.pathGoal, self.pathOptions )
    end

    function ENT:RunBehaviour()
        while true do
            -- Navigator just exists for path computation
            -- The player bot will read the path from this entity
            coroutine.yield()
        end
    end

end

print( "[Experimental Players] Navigator entity loaded" )
