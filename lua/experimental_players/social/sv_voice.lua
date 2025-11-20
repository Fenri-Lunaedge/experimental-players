-- Experimental Players - Voice Line System
-- Based on GLambda/Lambda voice system
-- Server-side only

if ( CLIENT ) then return end

local math_random = math.random
local math_Rand = math.Rand
local CurTime = CurTime
local IsValid = IsValid
local table_Count = table.Count

local PLAYER = EXP.Player

--[[ Voice Pack Compatibility ]]--

-- Import voice lines from Lambda Players voice packs
local function ImportLambdaVoices()
    -- Check if Lambda Players voice system exists
    if LambdaVoiceChatLines then
        print("[Experimental Players] Voice: Importing Lambda Players voice lines...")

        for category, lines in pairs(LambdaVoiceChatLines) do
            if !EXP.VoiceLines[category] then
                EXP.VoiceLines[category] = {}
            end

            -- Merge Lambda voice lines
            for _, line in ipairs(lines) do
                table.insert(EXP.VoiceLines[category], line)
            end
        end

        print("[Experimental Players] Voice: Imported " .. table.Count(LambdaVoiceChatLines) .. " Lambda voice categories")
        return true
    end

    return false
end

-- Import voice lines from Zeta Players voice packs
local function ImportZetaVoices()
    -- Check if Zeta Players voice system exists
    if zetaVoiceLines then
        print("[Experimental Players] Voice: Importing Zeta Players voice lines...")

        for category, lines in pairs(zetaVoiceLines) do
            -- Map Zeta categories to EXP categories
            local expCategory = category
            if category == "taunt" then expCategory = "taunt"
            elseif category == "death" then expCategory = "death"
            elseif category == "hurt" then expCategory = "pain"
            elseif category == "idle" then expCategory = "idle"
            elseif category == "laugh" then expCategory = "taunt"
            elseif category == "assist" then expCategory = "assist"
            elseif category == "witness" then expCategory = "witness"
            end

            if !EXP.VoiceLines[expCategory] then
                EXP.VoiceLines[expCategory] = {}
            end

            -- Merge Zeta voice lines
            for _, line in ipairs(lines) do
                table.insert(EXP.VoiceLines[expCategory], line)
            end
        end

        print("[Experimental Players] Voice: Imported " .. table.Count(zetaVoiceLines) .. " Zeta voice categories")
        return true
    end

    return false
end

--[[ Default Voice Lines ]]--

-- Initialize default voice lines if not loaded from file
if !EXP.VoiceLines then
    EXP.VoiceLines = {
        -- Idle/casual
        idle = {
            "npc/metropolice/vo/on1.wav",
            "npc/metropolice/vo/on2.wav",
            "npc/combine_soldier/vo/on1.wav",
            "npc/combine_soldier/vo/on2.wav",
        },

        -- Combat
        attack = {
            "npc/metropolice/vo/chuckle.wav",
            "npc/combine_soldier/vo/alert1.wav",
            "npc/combine_soldier/vo/bouncerbouncer.wav",
        },

        taunt = {
            "npc/metropolice/vo/chuckle.wav",
        },

        kill = {
            "npc/metropolice/vo/chuckle.wav",
            "npc/combine_soldier/vo/overwatchconfirmsightline.wav",
        },

        -- Damage/retreat
        pain = {
            "npc/metropolice/vo/shit.wav",
            "npc/combine_soldier/vo/cover.wav",
        },

        panic = {
            "npc/metropolice/vo/runninglowonrounds.wav",
            "npc/combine_soldier/vo/cover.wav",
        },

        death = {
            -- Silent on death (no sounds)
        },

        fall = {
            "npc/metropolice/vo/shit.wav",
        },

        -- Social
        greet = {
            "npc/metropolice/vo/on1.wav",
            "npc/metropolice/vo/on2.wav",
        },

        witness = {
            "npc/metropolice/vo/holdit.wav",
        },

        assist = {
            "npc/combine_soldier/vo/cover.wav",
        },

        -- Admin
        admin = {
            "npc/metropolice/vo/dispupdatingapb.wav",
            "npc/combine_soldier/vo/alert1.wav",
        },
    }

    print("[Experimental Players] Voice: Using default HL2 voice lines")

    -- Try to import addon voice packs
    timer.Simple(2, function()
        local imported = ImportLambdaVoices() or ImportZetaVoices()

        if imported then
            print("[Experimental Players] Voice: Addon voice packs imported successfully!")
        else
            print("[Experimental Players] Voice: No addon voice packs found, using defaults only")
        end
    end)
end

--[[ Voice Initialization ]]--

function PLAYER:InitializeVoice()
    self.exp_VoicePitch = math_random(80, 120)
    self.exp_NextVoiceTime = 0
    self.exp_VoiceProfile = nil  -- Can be set to use custom voice profiles
end

--[[ Voice Line Playing ]]--

function PLAYER:PlayVoiceLine(voiceType, forcePitch)
    -- Check if voice is enabled
    if !EXP:GetConVar("social_voicechat") then return end

    -- Check cooldown
    if CurTime() < self.exp_NextVoiceTime then return end

    -- Filter voice lines by personality type if available
    local voiceLines = EXP.VoiceLines[voiceType]
    if self.GetPersonalityData then
        local personalityData = self:GetPersonalityData()
        if personalityData and personalityData.voiceType then
            local personalityVoiceType = personalityData.voiceType
            local filteredKey = voiceType .. "_" .. personalityVoiceType

            -- Check if personality-specific voice lines exist
            if EXP.VoiceLines[filteredKey] and #EXP.VoiceLines[filteredKey] > 0 then
                voiceLines = EXP.VoiceLines[filteredKey]
            end
        end
    end

    -- Validate voice lines exist
    if !voiceLines or #voiceLines == 0 then
        -- Fallback to generic if personality-specific not found
        voiceLines = EXP.VoiceLines[voiceType]
        if !voiceLines or #voiceLines == 0 then
            return
        end
    end

    -- Pick random voice line
    local voiceLine = voiceLines[math_random(#voiceLines)]
    if !voiceLine then return end

    -- Play sound
    local pitch = forcePitch or self.exp_VoicePitch or 100
    self:EmitSound(voiceLine, 75, pitch, 1, CHAN_VOICE)

    -- Set cooldown
    self.exp_NextVoiceTime = CurTime() + math_Rand(3, 6)

    -- Network to clients for voice popup
    if EXP:GetConVar("player_voicepopups") then
        self:SetNW2Bool("exp_IsSpeaking", true)
        self:SetNW2String("exp_VoiceType", voiceType)

        timer.Simple(2, function()
            if IsValid(self) then
                self:SetNW2Bool("exp_IsSpeaking", false)
            end
        end)
    end
end

--[[ Context Voice Lines ]]--

function PLAYER:Voice_Idle()
    if math_random(1, 100) < 5 then  -- 5% chance per think
        self:PlayVoiceLine("idle")
    end
end

function PLAYER:Voice_Taunt()
    self:PlayVoiceLine("taunt")
end

function PLAYER:Voice_Death()
    self:PlayVoiceLine("death")
end

function PLAYER:Voice_Kill()
    self:PlayVoiceLine("kill")
end

function PLAYER:Voice_Panic()
    self:PlayVoiceLine("panic")
end

function PLAYER:Voice_Witness()
    self:PlayVoiceLine("witness")
end

function PLAYER:Voice_Assist()
    self:PlayVoiceLine("assist")
end

function PLAYER:Voice_Fall()
    if !self:IsOnGround() then
        local fallVel = self:GetVelocity().z
        if fallVel < -500 then  -- Falling fast
            self:PlayVoiceLine("fall")
        end
    end
end

--[[ Automatic Voice ]]--

function PLAYER:Think_Voice()
    if !self.exp_NextVoiceTime then
        self:InitializeVoice()
        return
    end

    -- Idle voice lines
    if self.exp_State == "Idle" then
        self:Voice_Idle()
    end

    -- Fall voice
    self:Voice_Fall()
end

--[[ Death/Kill Hooks ]]--

-- Play death sound when killed
hook.Add("PlayerDeath", "EXP_VoiceDeath", function(victim, inflictor, attacker)
    if !IsValid(victim) or !victim.exp_IsExperimentalPlayer then return end

    -- Find GLACE wrapper
    if EXP.ActiveBots then
        for _, bot in ipairs(EXP.ActiveBots) do
            if bot._PLY == victim and bot.Voice_Death then
                bot:Voice_Death()
                break
            end
        end
    end
end)

-- Play kill sound when killing someone
hook.Add("OnNPCKilled", "EXP_VoiceKill", function(npc, attacker, inflictor)
    if !IsValid(attacker) or !attacker.exp_IsExperimentalPlayer then return end

    -- Find GLACE wrapper
    if EXP.ActiveBots then
        for _, bot in ipairs(EXP.ActiveBots) do
            if bot._PLY == attacker and bot.Voice_Kill then
                bot:Voice_Kill()
                break
            end
        end
    end
end)

print("[Experimental Players] Voice system loaded")
