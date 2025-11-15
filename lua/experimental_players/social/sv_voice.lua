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

    -- Get voice lines for this type
    if !EXP.VoiceLines or !EXP.VoiceLines[voiceType] then
        return
    end

    local voiceLines = EXP.VoiceLines[voiceType]
    if !voiceLines or #voiceLines == 0 then
        return
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
