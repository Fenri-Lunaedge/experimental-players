-- Experimental Players - Diagnostic Test Script
-- Run this on your server console to test bot functionality
-- Usage: lua_openscript_cl diagnostic_test.lua (or just exec from server console)

print("\n=== EXPERIMENTAL PLAYERS DIAGNOSTIC TEST ===\n")

-- Test 1: Check if addon loaded
print("[TEST 1] Checking if addon loaded...")
if EXP then
    print("✓ EXP table exists")
    print("  - EXP.Player:", EXP.Player and "exists" or "MISSING")
    print("  - EXP.CreateLambdaPlayer:", EXP.CreateLambdaPlayer and "exists" or "MISSING")
    print("  - EXP.ActiveBots:", EXP.ActiveBots and "exists" or "MISSING")
else
    print("✗ EXP table does NOT exist - addon failed to load!")
    return
end

-- Test 2: Check weapon system
print("\n[TEST 2] Checking weapon system...")
if _EXPERIMENTALPLAYERSWEAPONS then
    local count = table.Count(_EXPERIMENTALPLAYERSWEAPONS)
    print("✓ Weapon table exists with " .. count .. " weapons")

    if count == 0 then
        print("✗ WARNING: No weapons loaded!")
    else
        print("  Sample weapons:")
        local shown = 0
        for name, data in pairs(_EXPERIMENTALPLAYERSWEAPONS) do
            if shown < 5 then
                print("    - " .. name .. " (" .. (data.prettyname or "no name") .. ")")
                shown = shown + 1
            end
        end
    end
else
    print("✗ Weapon table does NOT exist!")
end

-- Test 3: Check if PlayerCreateNextBot is available
print("\n[TEST 3] Checking PlayerBot functionality...")
if player.CreateNextBot then
    print("✓ player.CreateNextBot() is available")
else
    print("✗ player.CreateNextBot() is NOT available - multiplayer required!")
end

if game.SinglePlayer() then
    print("✗ WARNING: Running in singleplayer mode - bots will NOT work!")
else
    print("✓ Running in multiplayer mode")
end

-- Test 4: Check player methods
print("\n[TEST 4] Checking PLAYER methods...")
local requiredMethods = {
    "ThreadedThink",
    "Think",
    "SetState",
    "State_Idle",
    "State_Wander",
    "State_Combat",
    "MoveToPos",
    "SwitchWeapon",
    "CreateWeaponEntity",
}

local missingMethods = {}
for _, method in ipairs(requiredMethods) do
    if !EXP.Player[method] then
        table.insert(missingMethods, method)
    end
end

if #missingMethods == 0 then
    print("✓ All required PLAYER methods exist")
else
    print("✗ Missing methods: " .. table.concat(missingMethods, ", "))
end

-- Test 5: Try to spawn a test bot
print("\n[TEST 5] Attempting to spawn test bot...")
if SERVER and !game.SinglePlayer() then
    local testBot = EXP:CreateLambdaPlayer("DIAGNOSTIC_TEST_BOT")

    if testBot then
        print("✓ Bot spawned successfully!")
        print("  - Bot object:", testBot)
        print("  - Player entity:", testBot._PLY)
        print("  - Bot is valid:", IsValid(testBot._PLY))

        if IsValid(testBot._PLY) then
            local ply = testBot._PLY
            print("\n  Bot properties:")
            print("    - Name:", ply:Nick())
            print("    - Health:", ply:Health())
            print("    - Alive:", ply:Alive())
            print("    - Model:", ply:GetModel())
            print("    - State:", ply.exp_State or "NONE")
            print("    - Current Weapon:", ply.exp_CurrentWeapon or "NONE")
            print("    - Weapon Entity:", IsValid(ply.exp_WeaponEntity) and "exists" or "MISSING")
            print("    - Navigator:", IsValid(ply.Navigator) and "exists" or "MISSING")
            print("    - Thread:", ply._Thread and "exists" or "MISSING")

            if ply._Thread then
                print("    - Thread status:", coroutine.status(ply._Thread))
            end

            -- Wait a moment then check if thread is running
            timer.Simple(2, function()
                if IsValid(ply) then
                    print("\n[TEST 5.1] Checking bot after 2 seconds...")
                    print("  - Still alive:", ply:Alive())
                    print("  - State:", ply.exp_State or "NONE")
                    print("  - Position:", ply:GetPos())

                    if ply._Thread then
                        local status = coroutine.status(ply._Thread)
                        print("  - Thread status:", status)

                        if status == "dead" then
                            print("  ✗ WARNING: Thread died! Bot is not thinking!")
                        elseif status == "suspended" then
                            print("  ✓ Thread is suspended (normal)")
                        end
                    else
                        print("  ✗ WARNING: No thread!")
                    end

                    -- Try to move the bot
                    print("\n[TEST 5.2] Testing movement...")
                    local targetPos = ply:GetPos() + Vector(200, 0, 0)
                    print("  - Attempting to move to:", targetPos)

                    if ply.MoveToPos then
                        timer.Simple(0.1, function()
                            if IsValid(ply) then
                                local result = ply:MoveToPos(targetPos, { tolerance = 50, maxage = 5 })
                                print("  - Movement result:", result)
                            end
                        end)
                    else
                        print("  ✗ MoveToPos method missing!")
                    end

                    -- Remove test bot after 10 seconds
                    timer.Simple(8, function()
                        if IsValid(ply) then
                            print("\n[CLEANUP] Removing test bot...")
                            ply:Kick("Diagnostic test complete")
                        end
                    end)
                end
            end)
        else
            print("✗ Bot entity is not valid!")
        end
    else
        print("✗ Failed to spawn bot!")
        print("  Check console for errors")
    end
else
    if game.SinglePlayer() then
        print("⊘ Skipped - singleplayer mode")
    else
        print("⊘ Skipped - not on server")
    end
end

print("\n=== DIAGNOSTIC TEST COMPLETE ===\n")
print("If you see errors above, that's what's preventing bots from working.")
print("Common issues:")
print("  1. Running in singleplayer (requires multiplayer)")
print("  2. Missing PLAYER methods (modules didn't load)")
print("  3. No weapons loaded (weapon files didn't load)")
print("  4. Thread dying immediately (error in ThreadedThink)")
print("\nCheck your server console for Lua errors!\n")
