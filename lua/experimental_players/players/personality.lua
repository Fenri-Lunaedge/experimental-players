-- Experimental Players - Personality System
-- Defines bot personalities that affect behavior, chat, and voice
-- Server-side only

if ( CLIENT ) then return end

local IsValid = IsValid
local CurTime = CurTime
local math = math
local table = table

local PLAYER = EXP.Player

--[[ Personality Definitions ]]--

EXP.Personalities = {
    -- Aggressive: Rush in, high aggression, low retreat
    aggressive = {
        name = "Aggressive",
        description = "Rushes into combat, rarely retreats",

        -- Combat modifiers
        combatStyle = {
            retreatThreshold = 0.2,  -- Only retreat at 20% health
            aggressionMult = 1.5,    -- 50% more aggressive positioning
            coverUsage = 0.3,        -- 30% chance to use cover
            strafeFrequency = 0.7,   -- Strafe less (focused on advancing)
            reloadInCombat = false,  -- Tends to reload while exposed
        },

        -- Chat personality
        chatStyle = {
            taunts = 0.8,           -- 80% more taunts
            friendly = 0.2,         -- 20% friendly messages
            swearing = 0.6,         -- 60% swearing chance
        },

        -- Voice selection preference
        voiceType = "aggressive",   -- Prefer aggressive voice packs

        -- Weapon preferences
        weaponPreference = {
            melee = 0.3,            -- 30% melee preference
            shotgun = 0.4,          -- 40% shotgun preference
            smg = 0.2,              -- 20% SMG preference
            sniper = 0.1,           -- 10% sniper preference
        },
    },

    -- Defensive: Careful, uses cover, retreats often
    defensive = {
        name = "Defensive",
        description = "Careful, uses cover frequently",

        combatStyle = {
            retreatThreshold = 0.6,  -- Retreat at 60% health
            aggressionMult = 0.7,    -- 30% less aggressive
            coverUsage = 0.9,        -- 90% chance to seek cover
            strafeFrequency = 1.2,   -- Strafe more
            reloadInCombat = true,   -- Always reload in cover
        },

        chatStyle = {
            taunts = 0.2,
            friendly = 0.6,
            swearing = 0.2,
        },

        voiceType = "defensive",

        weaponPreference = {
            melee = 0.05,
            shotgun = 0.15,
            smg = 0.3,
            sniper = 0.5,           -- Prefers long range
        },
    },

    -- Tactical: Balanced, smart positioning
    tactical = {
        name = "Tactical",
        description = "Balanced, strategic fighter",

        combatStyle = {
            retreatThreshold = 0.4,
            aggressionMult = 1.0,
            coverUsage = 0.7,
            strafeFrequency = 1.0,
            reloadInCombat = true,
        },

        chatStyle = {
            taunts = 0.4,
            friendly = 0.5,
            swearing = 0.3,
        },

        voiceType = "tactical",

        weaponPreference = {
            melee = 0.1,
            shotgun = 0.25,
            smg = 0.35,
            sniper = 0.3,
        },
    },

    -- Joker: Random behavior, lots of chat
    joker = {
        name = "Joker",
        description = "Unpredictable, chatty, loves memes",

        combatStyle = {
            retreatThreshold = math.random(20, 70) / 100,  -- Random!
            aggressionMult = math.random(50, 150) / 100,
            coverUsage = math.random(20, 80) / 100,
            strafeFrequency = math.random(50, 150) / 100,
            reloadInCombat = math.random() > 0.5,
        },

        chatStyle = {
            taunts = 0.9,           -- LOTS of taunts
            friendly = 0.8,         -- Also very friendly
            swearing = 0.4,
            memes = true,           -- Special: uses meme chat
        },

        voiceType = "joker",

        weaponPreference = {
            melee = 0.25,           -- Random weapons
            shotgun = 0.25,
            smg = 0.25,
            sniper = 0.25,
        },
    },

    -- Silent: Rarely talks, focused fighter
    silent = {
        name = "Silent",
        description = "Quiet, focused, efficient",

        combatStyle = {
            retreatThreshold = 0.3,
            aggressionMult = 1.1,
            coverUsage = 0.8,
            strafeFrequency = 0.9,
            reloadInCombat = true,
        },

        chatStyle = {
            taunts = 0.05,          -- Almost never taunts
            friendly = 0.1,         -- Rarely chats
            swearing = 0.1,
        },

        voiceType = "silent",

        weaponPreference = {
            melee = 0.15,
            shotgun = 0.2,
            smg = 0.3,
            sniper = 0.35,
        },
    },

    -- Support: Team-oriented, helps allies
    support = {
        name = "Support",
        description = "Team player, assists allies",

        combatStyle = {
            retreatThreshold = 0.5,
            aggressionMult = 0.8,
            coverUsage = 0.6,
            strafeFrequency = 0.9,
            reloadInCombat = true,
            prioritizeAllySupport = true,  -- Special: helps teammates
        },

        chatStyle = {
            taunts = 0.3,
            friendly = 0.9,         -- Very friendly
            swearing = 0.1,
            encouragement = true,   -- Special: encourages teammates
        },

        voiceType = "support",

        weaponPreference = {
            melee = 0.1,
            shotgun = 0.2,
            smg = 0.4,
            sniper = 0.3,
        },
    },
}

--[[ Personality Assignment ]]--

function PLAYER:AssignPersonality(personalityName)
    -- Assign a specific personality
    if !EXP.Personalities[personalityName] then
        print("[EXP] WARNING: Personality '" .. personalityName .. "' doesn't exist, using tactical")
        personalityName = "tactical"
    end

    self.exp_Personality = personalityName
    self.exp_PersonalityData = table.Copy(EXP.Personalities[personalityName])

    print("[EXP] " .. self:Nick() .. " assigned personality: " .. self.exp_PersonalityData.name)
end

function PLAYER:GetPersonality()
    return self.exp_Personality or "tactical"
end

function PLAYER:GetPersonalityData()
    if !self.exp_PersonalityData then
        self:AssignRandomPersonality()
    end
    return self.exp_PersonalityData
end

function PLAYER:AssignRandomPersonality()
    -- Pick a random personality
    local personalities = {"aggressive", "defensive", "tactical", "joker", "silent", "support"}
    local randomPersonality = personalities[math.random(#personalities)]

    self:AssignPersonality(randomPersonality)
end

--[[ Personality-Based Behavior Modifiers ]]--

function PLAYER:GetRetreatThreshold()
    local personalityData = self:GetPersonalityData()
    if personalityData and personalityData.combatStyle then
        return personalityData.combatStyle.retreatThreshold or 0.4
    end
    return 0.4  -- Default
end

function PLAYER:GetAggressionMultiplier()
    local personalityData = self:GetPersonalityData()
    if personalityData and personalityData.combatStyle then
        return personalityData.combatStyle.aggressionMult or 1.0
    end
    return 1.0
end

function PLAYER:GetCoverUsageChance()
    local personalityData = self:GetPersonalityData()
    if personalityData and personalityData.combatStyle then
        return personalityData.combatStyle.coverUsage or 0.5
    end
    return 0.5
end

function PLAYER:ShouldUseCoverWithPersonality()
    -- Personality-based cover seeking
    local coverChance = self:GetCoverUsageChance()
    return math.random() < coverChance
end

function PLAYER:GetStrafeFrequencyMultiplier()
    local personalityData = self:GetPersonalityData()
    if personalityData and personalityData.combatStyle then
        return personalityData.combatStyle.strafeFrequency or 1.0
    end
    return 1.0
end

function PLAYER:SelectWeaponByPersonality(weaponType)
    local personalityData = self:GetPersonalityData()
    if !personalityData or !personalityData.weaponPreference then
        return nil
    end

    -- Get preference value for this weapon type
    local preference = personalityData.weaponPreference[weaponType] or 0.25

    -- Random roll based on preference
    if math.random() < preference then
        return true
    end

    return false
end

--[[ Chat Personality ]]--

function PLAYER:GetChatPersonality()
    local personalityData = self:GetPersonalityData()
    if personalityData and personalityData.chatStyle then
        return personalityData.chatStyle
    end
    return {taunts = 0.5, friendly = 0.5, swearing = 0.3}
end

function PLAYER:ShouldTaunt()
    local chatStyle = self:GetChatPersonality()
    return math.random() < (chatStyle.taunts or 0.5)
end

function PLAYER:ShouldBeFriendly()
    local chatStyle = self:GetChatPersonality()
    return math.random() < (chatStyle.friendly or 0.5)
end

function PLAYER:ShouldSwear()
    local chatStyle = self:GetChatPersonality()
    return math.random() < (chatStyle.swearing or 0.3)
end

--[[ Meme Chat for Joker Personality ]]--

EXP.MemeChat = {
    "no u",
    "skill issue",
    "ez clap",
    "gg no re",
    "outplayed",
    "get rekt",
    "pro gamer move",
    "360 noscope when?",
    "spam crouch = instant win",
    "just build lol",
}

function PLAYER:SendMemeChat()
    if !self.SendTextChat then return end

    local chatStyle = self:GetChatPersonality()
    if chatStyle.memes then
        local meme = EXP.MemeChat[math.random(#EXP.MemeChat)]
        self:SendTextChat(meme)
    end
end

--[[ Initialization ]]--

function PLAYER:InitializePersonality()
    -- Assign random personality on spawn
    self:AssignRandomPersonality()

    -- Apply personality modifiers to existing systems
    if self.exp_PersonalityData and self.exp_PersonalityData.combatStyle then
        local combat = self.exp_PersonalityData.combatStyle

        -- Modify combat variables
        if combat.retreatThreshold then
            self.exp_PersonalityRetreatThreshold = combat.retreatThreshold
        end

        if combat.aggressionMult then
            self.exp_PersonalityAggressionMult = combat.aggressionMult
        end
    end
end

print("[Experimental Players] Personality system loaded")
