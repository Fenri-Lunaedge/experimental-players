-- Experimental Players - Toolgun System
-- Complete tool implementation for bot building
-- Server-side only

if ( CLIENT ) then return end

--[[ Tool Registry ]]--

_EXPERIMENTALPLAYERSTOOLS = _EXPERIMENTALPLAYERSTOOLS or {}

-- Register a tool
function EXP:RegisterTool( toolName, toolData )
	_EXPERIMENTALPLAYERSTOOLS[ toolName ] = toolData
	print( "[Experimental Players] Registered tool: " .. toolName )
end

-- Get tool data
function EXP:GetTool( toolName )
	return _EXPERIMENTALPLAYERSTOOLS[ toolName ]
end

-- Get random tool
function EXP:GetRandomTool()
	local tools = {}
	for name, _ in pairs( _EXPERIMENTALPLAYERSTOOLS ) do
		table.insert( tools, name )
	end

	if #tools == 0 then return nil end
	return tools[ math.random( #tools ) ]
end

--[[ Toolgun Weapon Definition ]]--

table.Merge( _EXPERIMENTALPLAYERSWEAPONS, {
	toolgun = {
		model = "models/weapons/w_toolgun.mdl",
		prettyname = "Tool Gun",
		origin = "Garry's Mod",
		holdtype = "pistol",
		killicon = "weapon_physgun",
		islethal = false,
		ismelee = false,
		nodraw = false,
		bonemerge = true,

		-- Stats
		attackrange = 2000,
		keepdistance = 200,
		clip = -1, -- Infinite uses

		-- Sounds
		attacksnd = "weapons/airboat/airboat_gun_lastshot2.wav",

		OnDeploy = function( ply, wepent, oldwep )
			-- Initialize tool state
			ply.exp_CurrentTool = ply.exp_CurrentTool or "weld"
			ply.exp_ToolStage = 0 -- Multi-stage tool tracking
			ply.exp_ToolEntity1 = nil
			ply.exp_ToolEntity2 = nil
		end,

		OnAttack = function( ply, wepent, target )
			if !IsValid( ply ) then return true end

			local currentTool = ply.exp_CurrentTool or "weld"
			local toolData = EXP:GetTool( currentTool )

			if !toolData then
				print( "[EXP] ERROR: Tool '" .. currentTool .. "' not found!" )
				return true
			end

			-- Trace to find target
			local trace = util.TraceLine( {
				start = ply:GetShootPos(),
				endpos = ply:GetShootPos() + ply:GetAimVector() * 2000,
				filter = ply,
				mask = MASK_SOLID
			} )

			-- Call tool's primary fire
			if toolData.LeftClick then
				toolData.LeftClick( ply, trace, wepent )
			end

			-- Visual effect
			local effectdata = EffectData()
			effectdata:SetOrigin( trace.HitPos )
			effectdata:SetNormal( trace.HitNormal )
			effectdata:SetMagnitude( 5 )
			effectdata:SetScale( 1 )
			effectdata:SetRadius( 3 )
			util.Effect( "ToolTracer", effectdata )

			return true -- Custom attack handled
		end,

		OnReload = function( ply, wepent )
			-- Reload = cycle through tools
			local tools = { "weld", "axis", "rope", "elastic", "hydraulic", "wheel", "ballsocket" }
			local currentTool = ply.exp_CurrentTool or "weld"

			-- Find next tool
			local currentIndex = 1
			for i, toolName in ipairs( tools ) do
				if toolName == currentTool then
					currentIndex = i
					break
				end
			end

			local nextIndex = ( currentIndex % #tools ) + 1
			ply.exp_CurrentTool = tools[ nextIndex ]

			-- Reset tool state
			ply.exp_ToolStage = 0
			ply.exp_ToolEntity1 = nil
			ply.exp_ToolEntity2 = nil

			-- Feedback
			ply:EmitSound( "weapons/357/357_reload1.wav", 60, 150 )
			print( "[EXP] " .. ply:Nick() .. " switched to tool: " .. ply.exp_CurrentTool )

			return true -- Custom reload handled
		end,
	},
} )

--[[ Player Tool Methods ]]--

-- These functions will be added to PLAYER table after it's created
-- Store them in a temp table for now
EXP.ToolgunPlayerMethods = EXP.ToolgunPlayerMethods or {}

function EXP.ToolgunPlayerMethods:SwitchTool( toolName )
	if !_EXPERIMENTALPLAYERSTOOLS[ toolName ] then
		print( "[EXP] ERROR: Tool '" .. toolName .. "' doesn't exist!" )
		return false
	end

	self.exp_CurrentTool = toolName
	self.exp_ToolStage = 0
	self.exp_ToolEntity1 = nil
	self.exp_ToolEntity2 = nil

	return true
end

function EXP.ToolgunPlayerMethods:GetCurrentTool()
	return self.exp_CurrentTool or "weld"
end

function EXP.ToolgunPlayerMethods:UseTool( targetEnt )
	local currentTool = self:GetCurrentTool()
	local toolData = EXP:GetTool( currentTool )

	if !toolData then return false end

	-- Trace to target
	local trace = util.TraceLine( {
		start = self:GetShootPos(),
		endpos = IsValid( targetEnt ) and targetEnt:GetPos() or self:GetShootPos() + self:GetAimVector() * 500,
		filter = self,
		mask = MASK_SOLID
	} )

	-- Use tool
	if toolData.LeftClick then
		toolData.LeftClick( self, trace, self:GetWeaponENT() )
	end

	return true
end

print( "[Experimental Players] Toolgun weapon loaded" )
