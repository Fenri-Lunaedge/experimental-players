-- Experimental Players - Spawn Menu Integration
-- Client-side spawn menu panel
-- Based on Lambda Players spawn menu

if ( SERVER ) then return end

local PANEL = {}

--[[ Spawn Menu Tab ]]--

function PANEL:Init()
    self:SetName("Experimental Players")

    -- Create main panel
    self.MainPanel = vgui.Create("DPanel", self)
    self.MainPanel:Dock(FILL)
    self.MainPanel:DockMargin(8, 8, 8, 8)
    self.MainPanel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 240))
    end

    -- Header
    local header = vgui.Create("DLabel", self.MainPanel)
    header:Dock(TOP)
    header:DockMargin(8, 8, 8, 8)
    header:SetFont("DermaLarge")
    header:SetText("Experimental Players - Bot Control")
    header:SetTextColor(Color(255, 200, 100))
    header:SizeToContents()

    -- Scroll panel for content
    local scroll = vgui.Create("DScrollPanel", self.MainPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 8, 8, 8)

    -- Create sections
    self:CreateSpawnSection(scroll)
    self:CreateQuickActionsSection(scroll)
    self:CreateConfigSection(scroll)
end

--[[ Spawn Bot Section ]]--

function PANEL:CreateSpawnSection(parent)
    local section = vgui.Create("DCollapsibleCategory", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 8)
    section:SetLabel("Spawn Bots")
    section:SetExpanded(true)

    local panel = vgui.Create("DPanel", section)
    panel:Dock(FILL)
    panel:DockPadding(8, 8, 8, 8)
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    section:SetContents(panel)

    -- Spawn count slider
    local countLabel = vgui.Create("DLabel", panel)
    countLabel:Dock(TOP)
    countLabel:SetText("Number of Bots:")
    countLabel:SetTextColor(Color(255, 255, 255))
    countLabel:SizeToContents()

    local countSlider = vgui.Create("DNumSlider", panel)
    countSlider:Dock(TOP)
    countSlider:SetMin(1)
    countSlider:SetMax(32)
    countSlider:SetDecimals(0)
    countSlider:SetValue(1)
    countSlider:SetDefaultValue(1)
    self.SpawnCount = countSlider

    -- Personality dropdown
    local personalityLabel = vgui.Create("DLabel", panel)
    personalityLabel:Dock(TOP)
    personalityLabel:DockMargin(0, 8, 0, 0)
    personalityLabel:SetText("Personality:")
    personalityLabel:SetTextColor(Color(255, 255, 255))
    personalityLabel:SizeToContents()

    local personalityBox = vgui.Create("DComboBox", panel)
    personalityBox:Dock(TOP)
    personalityBox:AddChoice("Random", "random", true)
    personalityBox:AddChoice("Aggressive", "aggressive")
    personalityBox:AddChoice("Defensive", "defensive")
    personalityBox:AddChoice("Tactical", "tactical")
    personalityBox:AddChoice("Joker", "joker")
    personalityBox:AddChoice("Silent", "silent")
    personalityBox:AddChoice("Support", "support")
    self.Personality = personalityBox

    -- Weapon dropdown
    local weaponLabel = vgui.Create("DLabel", panel)
    weaponLabel:Dock(TOP)
    weaponLabel:DockMargin(0, 8, 0, 0)
    weaponLabel:SetText("Starting Weapon:")
    weaponLabel:SetTextColor(Color(255, 255, 255))
    weaponLabel:SizeToContents()

    local weaponBox = vgui.Create("DComboBox", panel)
    weaponBox:Dock(TOP)
    weaponBox:AddChoice("Random", "random", true)
    weaponBox:AddChoice("Crowbar", "crowbar")
    weaponBox:AddChoice("Pistol", "pistol")
    weaponBox:AddChoice(".357 Magnum", "357")
    weaponBox:AddChoice("SMG1", "smg1")
    weaponBox:AddChoice("AR2", "ar2")
    weaponBox:AddChoice("Shotgun", "shotgun")
    weaponBox:AddChoice("Crossbow", "crossbow")
    weaponBox:AddChoice("RPG", "rpg")
    weaponBox:AddChoice("Gravity Gun", "gravgun")
    weaponBox:AddChoice("Physgun", "physgun")
    weaponBox:AddChoice("Toolgun", "toolgun")
    self.Weapon = weaponBox

    -- Team selection (if gamemode active)
    local teamLabel = vgui.Create("DLabel", panel)
    teamLabel:Dock(TOP)
    teamLabel:DockMargin(0, 8, 0, 0)
    teamLabel:SetText("Team:")
    teamLabel:SetTextColor(Color(255, 255, 255))
    teamLabel:SizeToContents()

    local teamBox = vgui.Create("DComboBox", panel)
    teamBox:Dock(TOP)
    teamBox:AddChoice("Auto-Assign", "auto", true)
    teamBox:AddChoice("Red Team", "red")
    teamBox:AddChoice("Blue Team", "blue")
    self.Team = teamBox

    -- Admin checkbox
    local adminCheck = vgui.Create("DCheckBoxLabel", panel)
    adminCheck:Dock(TOP)
    adminCheck:DockMargin(0, 8, 0, 0)
    adminCheck:SetText("Spawn as Admin (10% normal chance)")
    adminCheck:SetTextColor(Color(255, 255, 255))
    adminCheck:SetValue(false)
    self.IsAdmin = adminCheck

    -- Spawn button
    local spawnBtn = vgui.Create("DButton", panel)
    spawnBtn:Dock(TOP)
    spawnBtn:DockMargin(0, 16, 0, 0)
    spawnBtn:SetText("SPAWN BOTS")
    spawnBtn:SetTall(40)
    spawnBtn.Paint = function(pnl, w, h)
        local col = Color(60, 160, 60)
        if pnl:IsHovered() then col = Color(80, 200, 80) end
        if pnl:IsDown() then col = Color(40, 120, 40) end
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    spawnBtn.DoClick = function()
        self:SpawnBots()
    end
end

--[[ Quick Actions Section ]]--

function PANEL:CreateQuickActionsSection(parent)
    local section = vgui.Create("DCollapsibleCategory", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 8)
    section:SetLabel("Quick Actions")
    section:SetExpanded(false)

    local panel = vgui.Create("DPanel", section)
    panel:Dock(FILL)
    panel:DockPadding(8, 8, 8, 8)
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    section:SetContents(panel)

    -- Remove all bots button
    local removeBtn = vgui.Create("DButton", panel)
    removeBtn:Dock(TOP)
    removeBtn:DockMargin(0, 0, 0, 4)
    removeBtn:SetText("Remove All Bots")
    removeBtn:SetTall(30)
    removeBtn.Paint = function(pnl, w, h)
        local col = Color(160, 60, 60)
        if pnl:IsHovered() then col = Color(200, 80, 80) end
        if pnl:IsDown() then col = Color(120, 40, 40) end
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    removeBtn.DoClick = function()
        RunConsoleCommand("exp_removeall")
    end

    -- Kill all bots button
    local killBtn = vgui.Create("DButton", panel)
    killBtn:Dock(TOP)
    killBtn:DockMargin(0, 0, 0, 4)
    killBtn:SetText("Kill All Bots")
    killBtn:SetTall(30)
    killBtn.Paint = function(pnl, w, h)
        local col = Color(160, 100, 60)
        if pnl:IsHovered() then col = Color(200, 120, 80) end
        if pnl:IsDown() then col = Color(120, 80, 40) end
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    killBtn.DoClick = function()
        RunConsoleCommand("exp_killall")
    end

    -- Open settings button
    local settingsBtn = vgui.Create("DButton", panel)
    settingsBtn:Dock(TOP)
    settingsBtn:SetText("Advanced Settings")
    settingsBtn:SetTall(30)
    settingsBtn.Paint = function(pnl, w, h)
        local col = Color(60, 100, 160)
        if pnl:IsHovered() then col = Color(80, 120, 200) end
        if pnl:IsDown() then col = Color(40, 80, 120) end
        draw.RoundedBox(4, 0, 0, w, h, col)
    end
    settingsBtn.DoClick = function()
        self:OpenSettingsMenu()
    end
end

--[[ Config Preview Section ]]--

function PANEL:CreateConfigSection(parent)
    local section = vgui.Create("DCollapsibleCategory", parent)
    section:Dock(TOP)
    section:DockMargin(0, 0, 0, 8)
    section:SetLabel("Current Configuration")
    section:SetExpanded(false)

    local panel = vgui.Create("DPanel", section)
    panel:Dock(FILL)
    panel:DockPadding(8, 8, 8, 8)
    panel.Paint = function(pnl, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end

    section:SetContents(panel)

    -- Stats display
    local statsText = vgui.Create("DLabel", panel)
    statsText:Dock(FILL)
    statsText:SetFont("DermaDefault")
    statsText:SetTextColor(Color(200, 200, 200))
    statsText:SetAutoStretchVertical(true)
    statsText:SetWrap(true)

    local function UpdateStats()
        local text = ""
        text = text .. "Combat Range: " .. GetConVar("exp_combat_range"):GetInt() .. " units\n"
        text = text .. "Combat Accuracy: " .. GetConVar("exp_combat_accuracy"):GetInt() .. "%\n"
        text = text .. "Building Enabled: " .. (GetConVar("exp_building_enabled"):GetBool() and "Yes" or "No") .. "\n"
        text = text .. "Max Props: " .. GetConVar("exp_building_maxprops"):GetInt() .. "\n"
        text = text .. "Text Chat: " .. (GetConVar("exp_social_textchat"):GetBool() and "Enabled" or "Disabled") .. "\n"
        text = text .. "Voice Lines: " .. (GetConVar("exp_social_voice"):GetBool() and "Enabled" or "Disabled") .. "\n"

        statsText:SetText(text)
    end

    UpdateStats()
    timer.Create("EXP_UpdateConfigStats", 2, 0, UpdateStats)
end

--[[ Spawn Bots Function ]]--

function PANEL:SpawnBots()
    local count = math.floor(self.SpawnCount:GetValue())
    local personality = select(2, self.Personality:GetSelected())
    local weapon = select(2, self.Weapon:GetSelected())
    local team = select(2, self.Team:GetSelected())
    local isAdmin = self.IsAdmin:GetChecked()

    -- Send to server
    net.Start("EXP_SpawnBotsFromMenu")
        net.WriteUInt(count, 8)
        net.WriteString(personality or "random")
        net.WriteString(weapon or "random")
        net.WriteString(team or "auto")
        net.WriteBool(isAdmin)
    net.SendToServer()

    -- Feedback
    chat.AddText(Color(100, 200, 255), "[Experimental Players] ", Color(255, 255, 255), "Spawning " .. count .. " bot(s)...")
end

--[[ Open Settings Menu ]]--

function PANEL:OpenSettingsMenu()
    -- Open advanced settings panel (will create this next)
    local frame = vgui.Create("EXPSettingsFrame")
    frame:Center()
    frame:MakePopup()
end

vgui.Register("EXPSpawnMenu", PANEL, "DPanel")

--[[ Register Spawn Menu Tab ]]--

hook.Add("PopulateToolMenu", "EXP_AddSpawnMenuTab", function()
    spawnmenu.AddToolTab("Experimental Players", "Experimental Players", "icon16/user.png")
end)

hook.Add("AddToolMenuTabs", "EXP_AddToolMenuTab", function()
    spawnmenu.AddToolTab("Experimental Players", "Experimental Players", "icon16/user.png")
end)

hook.Add("AddToolMenuCategories", "EXP_AddToolMenuCategories", function()
    spawnmenu.AddToolCategory("Experimental Players", "Bots", "Experimental Players")
end)

hook.Add("PopulateToolMenu", "EXP_PopulateToolMenu", function()
    spawnmenu.AddToolMenuOption("Experimental Players", "Bots", "EXP_SpawnMenu", "Bot Control", "", "", function(panel)
        panel:ClearControls()

        local spawnPanel = vgui.Create("EXPSpawnMenu")
        panel:AddItem(spawnPanel)
    end)
end)

--[[ Network Receiver ]]--

util.AddNetworkString("EXP_SpawnBotsFromMenu")

print("[Experimental Players] Spawn menu loaded")
