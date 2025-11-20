-- Experimental Players - Text Chat System
-- Based on Zeta Players text chat
-- Server-side only

if ( CLIENT ) then return end

local math_random = math.random
local string_Replace = string.Replace
local string_Explode = string.Explode
local string_lower = string.lower
local CurTime = CurTime
local IsValid = IsValid

local PLAYER = EXP.Player

--[[ Text Message Tables ]]--

EXP.TextMessages = {
    idle = {
        "Hello",
        "Hi there",
        "Anyone here?",
        "This map is cool",
        "What should I do?",
        "I'm bored",
        "Nice weather",
        "Anyone want to play?",
    },
    kill = {
        "Got you!",
        "Nice try",
        "Too easy",
        "Rekt",
        "Better luck next time",
        "Owned",
        "GG",
    },
    death = {
        "Ow!",
        "That hurt",
        "Not fair!",
        "Damn",
        "Come on!",
        "Really?",
        "Bruh",
    },
    taunt = {
        "Come at me!",
        "You can't hit me",
        "Is that all you got?",
        "Try harder",
        "Bring it on",
    },
    assist = {
        "Nice kill",
        "Good job",
        "Thanks for the assist",
        "Got em",
    },
}

--[[ Key Phrases ]]--

local keyPhrases = {
    ["/map/"] = game.GetMap(),
    ["/self/"] = true,      -- Bot's own name
    ["/rndent/"] = true,    -- Random player/bot name
    ["/time/"] = true,      -- Current time
}

--[[ Chat Functions ]]--

function PLAYER:InitializeTextChat()
    self.exp_NextChatTime = CurTime() + math_random(10, 30)
    self.exp_IsTyping = false
    self.exp_TypingText = ""
    self.exp_TypingProgress = 0
end

function PLAYER:GetRandomTextMessage(category)
    if !EXP.TextMessages[category] then
        category = "idle"
    end

    local messages = EXP.TextMessages[category]
    if !messages or #messages == 0 then
        return "..."
    end

    return messages[math_random(#messages)]
end

function PLAYER:ReplaceKeyPhrases(text)
    -- Replace /self/ with bot's name
    text = string_Replace(text, "/self/", self:Nick())

    -- Replace /map/ with current map
    text = string_Replace(text, "/map/", game.GetMap())

    -- Replace /time/ with current time
    local hour = tonumber(os.date("%H"))
    local timeOfDay = "morning"
    if hour >= 12 and hour < 18 then
        timeOfDay = "afternoon"
    elseif hour >= 18 then
        timeOfDay = "evening"
    end
    text = string_Replace(text, "/time/", timeOfDay)

    -- Replace /rndent/ with random entity name
    if string.find(text, "/rndent/") then
        local players = player.GetAll()
        if #players > 0 then
            local rndPlayer = players[math_random(#players)]
            text = string_Replace(text, "/rndent/", rndPlayer:Nick())
        end
    end

    return text
end

function PLAYER:SayText(text, category)
    if !text or text == "" then
        text = self:GetRandomTextMessage(category or "idle")
    end

    -- Replace key phrases
    text = self:ReplaceKeyPhrases(text)

    -- Start typing simulation
    self:StartTyping(text)
end

--[[ Typing Simulation ]]--

function PLAYER:StartTyping(text)
    if self.exp_IsTyping then return end

    self.exp_IsTyping = true
    self.exp_TypingText = text
    self.exp_TypingProgress = 0
    self.exp_TypingStartTime = CurTime()

    -- Typing speed (characters per second)
    local charsPerSecond = math_random(8, 15)
    local typingDuration = #text / charsPerSecond

    -- Show typing indicator to players
    self:SetNW2Bool("exp_IsTyping", true)

    -- Finish typing after duration
    timer.Simple(typingDuration, function()
        if IsValid(self) then
            self:FinishTyping()
        end
    end)
end

function PLAYER:FinishTyping()
    if !self.exp_IsTyping then return end

    local text = self.exp_TypingText

    -- Send to chat
    if text and text  ~=  "" then
        -- Use player:ChatPrint for everyone
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                ply:ChatPrint("[" .. self:Nick() .. "]: " .. text)
            end
        end
    end

    -- Clear typing state
    self.exp_IsTyping = false
    self.exp_TypingText = ""
    self.exp_TypingProgress = 0
    self:SetNW2Bool("exp_IsTyping", false)

    -- Set next chat time
    self.exp_NextChatTime = CurTime() + math_random(20, 60)
end

function PLAYER:StopTyping()
    self.exp_IsTyping = false
    self.exp_TypingText = ""
    self.exp_TypingProgress = 0
    self:SetNW2Bool("exp_IsTyping", false)
end

--[[ Automatic Chatting ]]--

function PLAYER:ShouldChat()
    -- Check if chat is enabled
    if !EXP:GetConVar("social_textchat") then return false end

    -- Check if enough time has passed
    if CurTime() < self.exp_NextChatTime then return false end

    -- Check if already typing
    if self.exp_IsTyping then return false end

    -- Random chance
    if math_random(1, 100) > 30 then return false end

    return true
end

function PLAYER:Think_TextChat()
    if !self.exp_NextChatTime then
        self:InitializeTextChat()
        return
    end

    if self:ShouldChat() then
        -- Say random idle message
        self:SayText(nil, "idle")
    end
end

--[[ Context-Aware Chat ]]--

function PLAYER:OnKillEnemy(enemy)
    if math_random(1, 100) < 50 then  -- 50% chance
        self:SayText(nil, "kill")
    end
end

function PLAYER:OnDeath(attacker)
    if math_random(1, 100) < 40 then  -- 40% chance
        self:SayText(nil, "death")
    end
end

function PLAYER:OnTaunt()
    self:SayText(nil, "taunt")
end

--[[ Response System ]]--

-- Respond to player chat
hook.Add("PlayerSay", "EXP_RespondToChat", function(ply, text)
    if !IsValid(ply) or !text then return end

    -- Skip vote commands (handled by voting system)
    local lowerText = string_lower(text)
    if string.StartWith(lowerText, ",startvote") or string.StartWith(lowerText, ",vote ") then
        return  -- Let voting system handle it
    end

    text = lowerText

    -- Check if any bot should respond
    if !EXP.ActiveBots then return end

    for _, bot in ipairs(EXP.ActiveBots) do
        if !IsValid(bot._PLY) then continue end

        local ply = bot._PLY  -- Extract entity from wrapper

        -- Respond if mentioned by name
        local botName = string_lower(ply:Nick())
        if string.find(text, botName) then
            -- 70% chance to respond
            if math_random(1, 100) < 70 then
                timer.Simple(math_random(1, 3), function()
                    if IsValid(ply) and ply.SayText then
                        ply:SayText("Yes?", "idle")
                    end
                end)
            end
            break
        end

        -- Random chance to respond to any message
        if math_random(1, 100) < 10 then  -- 10% chance
            timer.Simple(math_random(2, 5), function()
                if IsValid(ply) and ply.SayText then
                    ply:SayText(nil, "idle")
                end
            end)
            break  -- Only one bot responds
        end
    end
end)

print("[Experimental Players] Text chat system loaded")
