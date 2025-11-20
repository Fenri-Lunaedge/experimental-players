-- Experimental Players - Advanced Settings Panel
-- Full configuration menu like Zeta/Lambda
-- Client-side only

if ( SERVER ) then return end

local PANEL = {}

function PANEL:Init()
    self:SetSize(900, 700)
    self:SetTitle("Experimental Players - Advanced Settings")
    self:SetDraggable(true)
    self:SetSizable(true)
    self:ShowCloseButton(true)
    self:SetDeleteOnClose(false)

    -- Create property sheet (tabs)
    self.PropertySheet = vgui.Create("DPropertySheet", self)
    self.PropertySheet:Dock(FILL)
    self.PropertySheet:DockMargin(4, 4, 4, 4)

    -- Add tabs
    self:AddGeneralTab()
    self:AddCombatTab()
    self:AddSocialTab()
    self:AddBuildingTab()
    self:AddWeaponsTab()
    self:AddPersonalityTab()
    self:AddAdminTab()
end

--[[ General Settings Tab ]]--

function PANEL:AddGeneralTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    -- Header
    local header = self:CreateHeader(scroll, "General Settings")

    -- Max bots slider
    self:CreateSlider(scroll, "Maximum Bots", "exp_maxbots", 0, 128, 0,
        "Maximum number of bots that can be spawned")

    -- Respawn time
    self:CreateSlider(scroll, "Respawn Time (seconds)", "exp_respawn_time", 0, 60, 0,
        "Time before bots respawn after death (0 = instant)")

    -- Navigation update rate
    self:CreateSlider(scroll, "Navigation Update Rate", "exp_nav_updaterate", 0.05, 1, 2,
        "How often bots update their pathfinding (lower = more CPU)")

    -- Think rate
    self:CreateSlider(scroll, "AI Think Rate", "exp_ai_thinkrate", 0.05, 1, 2,
        "How often bots update their AI (lower = smarter but more CPU)")

    self.PropertySheet:AddSheet("General", panel, "icon16/cog.png")
end

--[[ Combat Settings Tab ]]--

function PANEL:AddCombatTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Combat Settings")

    -- Combat range
    self:CreateSlider(scroll, "Combat Range", "exp_combat_range", 500, 5000, 0,
        "How far bots can detect enemies")

    -- Accuracy
    self:CreateSlider(scroll, "Accuracy (%)", "exp_combat_accuracy", 0, 100, 0,
        "Bot aiming accuracy (100 = perfect)")

    -- Attack rate
    self:CreateSlider(scroll, "Attack Rate", "exp_combat_attackrate", 0.1, 2, 1,
        "Time between attacks (lower = faster)")

    -- Retreat health threshold
    self:CreateSlider(scroll, "Retreat Health (%)", "exp_combat_retreatthreshold", 0, 100, 0,
        "Health percentage when bots retreat (overridden by personality)")

    -- Cover usage
    self:CreateCheckbox(scroll, "Enable Cover System", "exp_combat_cover",
        "Allow bots to seek and use cover")

    -- Friendly fire
    self:CreateCheckbox(scroll, "Friendly Fire", "exp_combat_friendlyfire",
        "Allow bots to damage teammates")

    self.PropertySheet:AddSheet("Combat", panel, "icon16/gun.png")
end

--[[ Social Settings Tab ]]--

function PANEL:AddSocialTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Social Settings")

    -- Text chat
    self:CreateCheckbox(scroll, "Enable Text Chat", "exp_social_textchat",
        "Allow bots to send chat messages")

    -- Chat frequency
    self:CreateSlider(scroll, "Chat Frequency (%)", "exp_social_chatfrequency", 0, 100, 0,
        "How often bots send chat messages (30 = 30% chance)")

    -- Voice lines
    self:CreateCheckbox(scroll, "Enable Voice Lines", "exp_social_voice",
        "Allow bots to play voice lines")

    -- Voice pitch
    self:CreateSlider(scroll, "Voice Pitch Min", "exp_social_voicepitchmin", 50, 150, 0,
        "Minimum voice pitch")

    self:CreateSlider(scroll, "Voice Pitch Max", "exp_social_voicepitchmax", 50, 150, 0,
        "Maximum voice pitch")

    -- Taunt on kill
    self:CreateCheckbox(scroll, "Taunt on Kill", "exp_social_tauntonkill",
        "Bots taunt after getting a kill")

    self.PropertySheet:AddSheet("Social", panel, "icon16/comments.png")
end

--[[ Building Settings Tab ]]--

function PANEL:AddBuildingTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Building Settings")

    -- Enable building
    self:CreateCheckbox(scroll, "Enable Building", "exp_building_enabled",
        "Allow bots to spawn props and build structures")

    -- Max props
    self:CreateSlider(scroll, "Max Props per Bot", "exp_building_maxprops", 0, 50, 0,
        "Maximum props each bot can spawn")

    -- Max entities
    self:CreateSlider(scroll, "Max Entities per Bot", "exp_building_maxentities", 0, 20, 0,
        "Maximum entities each bot can spawn")

    -- Max NPCs
    self:CreateSlider(scroll, "Max NPCs per Bot", "exp_building_maxnpcs", 0, 10, 0,
        "Maximum NPCs each bot can spawn")

    -- Can edit others
    self:CreateCheckbox(scroll, "Can Edit Others' Props", "exp_building_caneditothers",
        "Allow bots to edit props spawned by other bots")

    -- Can edit world
    self:CreateCheckbox(scroll, "Can Edit World Props", "exp_building_caneditworld",
        "Allow bots to edit map props")

    -- Toolgun
    self:CreateCheckbox(scroll, "Enable Toolgun", "exp_building_toolgun",
        "Allow bots to use toolgun for constraints")

    self.PropertySheet:AddSheet("Building", panel, "icon16/brick.png")
end

--[[ Weapons Settings Tab ]]--

function PANEL:AddWeaponsTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Weapon Permissions")

    -- Info label
    local info = vgui.Create("DLabel", scroll)
    info:Dock(TOP)
    info:DockMargin(8, 8, 8, 16)
    info:SetText("Enable or disable specific weapons for bots to use:")
    info:SetTextColor(Color(200, 200, 200))
    info:SetWrap(true)
    info:SetAutoStretchVertical(true)

    -- Weapon categories
    local weapons = {
        {name = "Melee Weapons", items = {
            {"Crowbar", "exp_weapon_crowbar"},
            {"Stun Stick", "exp_weapon_stunstick"},
        }},
        {name = "Pistols", items = {
            {"Pistol", "exp_weapon_pistol"},
            {".357 Magnum", "exp_weapon_357"},
        }},
        {name = "Rifles & SMGs", items = {
            {"SMG1", "exp_weapon_smg1"},
            {"AR2", "exp_weapon_ar2"},
            {"Crossbow", "exp_weapon_crossbow"},
        }},
        {name = "Shotguns", items = {
            {"Shotgun", "exp_weapon_shotgun"},
        }},
        {name = "Special Weapons", items = {
            {"RPG", "exp_weapon_rpg"},
            {"Grenade", "exp_weapon_grenade"},
            {"SLAM", "exp_weapon_slam"},
        }},
        {name = "Tool Weapons", items = {
            {"Gravity Gun", "exp_weapon_gravgun"},
            {"Physics Gun", "exp_weapon_physgun"},
            {"Tool Gun", "exp_weapon_toolgun"},
        }},
    }

    for _, category in ipairs(weapons) do
        local cat = vgui.Create("DCollapsibleCategory", scroll)
        cat:Dock(TOP)
        cat:DockMargin(0, 0, 0, 4)
        cat:SetLabel(category.name)
        cat:SetExpanded(false)

        local catPanel = vgui.Create("DPanel", cat)
        catPanel:Dock(FILL)
        catPanel:DockPadding(8, 8, 8, 8)
        catPanel.Paint = function(pnl, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50))
        end

        cat:SetContents(catPanel)

        for _, weapon in ipairs(category.items) do
            self:CreateCheckbox(catPanel, weapon[1], weapon[2], "")
        end
    end

    self.PropertySheet:AddSheet("Weapons", panel, "icon16/bomb.png")
end

--[[ Personality Settings Tab ]]--

function PANEL:AddPersonalityTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Personality System")

    -- Enable personality system
    self:CreateCheckbox(scroll, "Enable Personality System", "exp_personality_enabled",
        "Give bots different personalities that affect behavior")

    -- Personality weights
    local weightHeader = vgui.Create("DLabel", scroll)
    weightHeader:Dock(TOP)
    weightHeader:DockMargin(8, 16, 8, 8)
    weightHeader:SetFont("DermaDefaultBold")
    weightHeader:SetText("Personality Spawn Weights:")
    weightHeader:SetTextColor(Color(255, 200, 100))
    weightHeader:SizeToContents()

    self:CreateSlider(scroll, "Aggressive Weight", "exp_personality_aggressive", 0, 100, 0,
        "Likelihood of spawning aggressive bots")

    self:CreateSlider(scroll, "Defensive Weight", "exp_personality_defensive", 0, 100, 0,
        "Likelihood of spawning defensive bots")

    self:CreateSlider(scroll, "Tactical Weight", "exp_personality_tactical", 0, 100, 0,
        "Likelihood of spawning tactical bots")

    self:CreateSlider(scroll, "Joker Weight", "exp_personality_joker", 0, 100, 0,
        "Likelihood of spawning joker bots")

    self:CreateSlider(scroll, "Silent Weight", "exp_personality_silent", 0, 100, 0,
        "Likelihood of spawning silent bots")

    self:CreateSlider(scroll, "Support Weight", "exp_personality_support", 0, 100, 0,
        "Likelihood of spawning support bots")

    self.PropertySheet:AddSheet("Personality", panel, "icon16/emoticon_smile.png")
end

--[[ Admin Settings Tab ]]--

function PANEL:AddAdminTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(40, 40, 40))
    end

    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    local header = self:CreateHeader(scroll, "Admin Bot Settings")

    -- Enable admin bots
    self:CreateCheckbox(scroll, "Enable Admin Bots", "exp_admin_enabled",
        "Allow some bots to spawn as admins")

    -- Admin spawn chance
    self:CreateSlider(scroll, "Admin Spawn Chance (%)", "exp_admin_spawnchance", 0, 100, 0,
        "Percentage chance a bot spawns as admin")

    -- Strictness range
    self:CreateSlider(scroll, "Strictness Min", "exp_admin_strictnessmin", 0, 100, 0,
        "Minimum admin strictness (soft punishments)")

    self:CreateSlider(scroll, "Strictness Max", "exp_admin_strictnessmax", 0, 100, 0,
        "Maximum admin strictness (harsh punishments)")

    -- Ban duration
    self:CreateSlider(scroll, "Ban Duration (minutes)", "exp_admin_banduration", 1, 60, 0,
        "How long admin bots ban players")

    self.PropertySheet:AddSheet("Admin", panel, "icon16/shield.png")
end

--[[ Helper Functions ]]--

function PANEL:CreateHeader(parent, text)
    local header = vgui.Create("DLabel", parent)
    header:Dock(TOP)
    header:DockMargin(8, 8, 8, 16)
    header:SetFont("DermaLarge")
    header:SetText(text)
    header:SetTextColor(Color(255, 200, 100))
    header:SizeToContents()
    return header
end

function PANEL:CreateSlider(parent, label, convar, min, max, decimals, tooltip)
    local slider = vgui.Create("DNumSlider", parent)
    slider:Dock(TOP)
    slider:DockMargin(8, 4, 8, 4)
    slider:SetText(label)
    slider:SetMin(min)
    slider:SetMax(max)
    slider:SetDecimals(decimals)
    slider:SetConVar(convar)
    slider:SetTooltip(tooltip or "")
    slider:SetDark(true)

    return slider
end

function PANEL:CreateCheckbox(parent, label, convar, tooltip)
    local checkbox = vgui.Create("DCheckBoxLabel", parent)
    checkbox:Dock(TOP)
    checkbox:DockMargin(8, 4, 8, 4)
    checkbox:SetText(label)
    checkbox:SetConVar(convar)
    checkbox:SetTooltip(tooltip or "")
    checkbox:SetTextColor(Color(255, 255, 255))
    checkbox:SizeToContents()

    return checkbox
end

vgui.Register("EXPSettingsFrame", PANEL, "DFrame")

print("[Experimental Players] Settings panel loaded")
