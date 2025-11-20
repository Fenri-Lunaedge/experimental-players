-- Experimental Players - Spawn Menu Server Handler
-- Handles bot spawning from client menu
-- Server-side only

if ( CLIENT ) then return end

util.AddNetworkString("EXP_SpawnBotsFromMenu")

--[[ Network Receiver ]]--

net.Receive("EXP_SpawnBotsFromMenu", function(len, ply)
    -- Check if player has permission
    if !IsValid(ply) then return end
    if !ply:IsAdmin() and !ply:IsSuperAdmin() and !game.SinglePlayer() then
        ply:ChatPrint("[Experimental Players] You need to be an admin to spawn bots!")
        return
    end

    -- Read data
    local count = net.ReadUInt(8)
    local personality = net.ReadString()
    local weapon = net.ReadString()
    local team = net.ReadString()
    local isAdmin = net.ReadBool()

    -- Validate count
    count = math.Clamp(count, 1, 32)

    -- Spawn bots
    for i = 1, count do
        local bot = EXP:CreateLambdaPlayer(nil, nil)

        if IsValid(bot) then
            -- Apply personality
            if personality  ~=  "random" and bot.AssignPersonality then
                bot:AssignPersonality(personality)
            end

            -- Apply weapon
            if weapon  ~=  "random" and bot.SwitchWeapon then
                timer.Simple(0.5, function()
                    if IsValid(bot) then
                        bot:SwitchWeapon(weapon, true)
                    end
                end)
            end

            -- Apply team
            if team  ~=  "auto" and EXP.GameMode and EXP.GameMode.Active then
                timer.Simple(0.1, function()
                    if IsValid(bot) and EXP.GameMode.AssignTeam then
                        if team == "red" then
                            EXP.GameMode:AssignTeam(bot, "Red")
                        elseif team == "blue" then
                            EXP.GameMode:AssignTeam(bot, "Blue")
                        end
                    end
                end)
            end

            -- Apply admin status
            if isAdmin and bot.InitializeAdmin then
                timer.Simple(0.2, function()
                    if IsValid(bot) then
                        bot:InitializeAdmin(true, math.random(30, 70))
                    end
                end)
            end
        end
    end

    -- Feedback
    ply:ChatPrint("[Experimental Players] Spawned " .. count .. " bot(s)")
    print("[EXP] " .. ply:Nick() .. " spawned " .. count .. " bot(s) via menu")
end)

print("[Experimental Players] Spawn menu server handler loaded")
