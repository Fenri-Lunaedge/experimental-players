-- Experimental Players - Half-Life 2 Weapons
-- Base weapon set from HL2

table.Merge( _EXPERIMENTALPLAYERSWEAPONS, {

    -- Melee Weapons --

    crowbar = {
        model = "models/weapons/w_crowbar.mdl",
        origin = "Half-Life 2",
        prettyname = "Crowbar",
        holdtype = "melee",
        killicon = "weapon_crowbar",
        ismelee = true,
        bonemerge = true,
        keepdistance = 40,
        attackrange = 55,
        dropentity = "weapon_crowbar",

        damage = 10,
        rateoffiremin = 0.04,
        rateoffiremax = 0.75,
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE,
        attacksnd = "Weapon_Crowbar.Single",
        hitsnd = "Weapon_Crowbar.Melee_Hit",

        islethal = true,
    },

    stunstick = {
        model = "models/weapons/w_stunbaton.mdl",
        origin = "Half-Life 2",
        prettyname = "Stun Stick",
        holdtype = "melee",
        killicon = "weapon_stunstick",
        ismelee = true,
        bonemerge = true,
        keepdistance = 40,
        attackrange = 50,
        dropentity = "weapon_stunstick",

        damage = 15,
        rateoffiremin = 0.1,
        rateoffiremax = 0.8,
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE,
        attacksnd = "Weapon_StunStick.Swing",
        hitsnd = "Weapon_StunStick.Melee_Hit",

        islethal = true,
    },

    -- Pistols --

    pistol = {
        model = "models/weapons/w_pistol.mdl",
        origin = "Half-Life 2",
        prettyname = "Pistol",
        holdtype = "pistol",
        killicon = "weapon_pistol",
        bonemerge = true,
        keepdistance = 350,
        attackrange = 2000,
        islethal = true,
        dropentity = "weapon_pistol",

        clip = 18,
        tracername = "Tracer",
        damage = 5,
        spread = 0.133,
        rateoffiremin = 0.175,
        rateoffiremax = 0.3,
        muzzleflash = 1,
        shelleject = "ShellEject",
        shelloffpos = Vector(0,2,5),
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_PISTOL,
        attacksnd = "Weapon_Pistol.Single",

        reloadtime = 1.8,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_PISTOL,
        reloadsounds = { { 0, "Weapon_Pistol.Reload" } }
    },

    ["357"] = {
        model = "models/weapons/w_357.mdl",
        origin = "Half-Life 2",
        prettyname = ".357 Magnum",
        holdtype = "revolver",
        killicon = "weapon_357",
        bonemerge = true,
        keepdistance = 450,
        attackrange = 3000,
        islethal = true,
        dropentity = "weapon_357",

        clip = 6,
        tracername = "Tracer",
        damage = 40,
        spread = 0.05,
        rateoffiremin = 0.5,
        rateoffiremax = 0.8,
        muzzleflash = 5,
        shelleject = "ShellEject",
        shelloffpos = Vector(0,2,5),
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_REVOLVER,
        attacksnd = "Weapon_357.Single",

        reloadtime = 2.2,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_REVOLVER,
        reloadsounds = { { 0, "Weapon_357.Reload" } }
    },

    -- SMGs --

    smg1 = {
        model = "models/weapons/w_smg1.mdl",
        origin = "Half-Life 2",
        prettyname = "SMG",
        holdtype = "smg",
        killicon = "weapon_smg1",
        bonemerge = true,
        keepdistance = 400,
        attackrange = 2500,
        islethal = true,
        dropentity = "weapon_smg1",

        clip = 45,
        tracername = "Tracer",
        damage = 4,
        spread = 0.4,
        rateoffire = 0.08,
        muzzleflash = 1,
        shelleject = "ShellEject",
        shelloffpos = Vector(0,5,2),
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_SMG1,
        attacksnd = "Weapon_SMG1.Single",

        reloadtime = 2.0,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_SMG1,
        reloadsounds = { { 0.5, "Weapon_SMG1.Reload" } }
    },

    -- Rifles --

    ar2 = {
        model = "models/weapons/w_irifle.mdl",
        origin = "Half-Life 2",
        prettyname = "AR2",
        holdtype = "ar2",
        killicon = "weapon_ar2",
        bonemerge = true,
        keepdistance = 500,
        attackrange = 4000,
        islethal = true,
        dropentity = "weapon_ar2",

        clip = 30,
        tracername = "AR2Tracer",
        damage = 8,
        spread = 0.2,
        rateoffire = 0.1,
        muzzleflash = 5,
        shelleject = "RifleShellEject",
        shelloffpos = Vector(0,5,2),
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_AR2,
        attacksnd = "Weapon_AR2.Single",

        reloadtime = 2.5,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_AR2,
        reloadsounds = { { 0.6, "Weapon_AR2.Reload" }, { 1.2, "Weapon_AR2.Reload_Push" } }
    },

    -- Shotguns --

    shotgun = {
        model = "models/weapons/w_shotgun.mdl",
        origin = "Half-Life 2",
        prettyname = "Shotgun",
        holdtype = "shotgun",
        killicon = "weapon_shotgun",
        bonemerge = true,
        keepdistance = 300,
        attackrange = 1500,
        islethal = true,
        dropentity = "weapon_shotgun",

        clip = 6,
        tracername = "Tracer",
        bulletcount = 7,
        damage = 5,
        spread = 0.8,
        rateoffiremin = 0.8,
        rateoffiremax = 1.2,
        muzzleflash = 1,
        shelleject = "ShotgunShellEject",
        shelloffpos = Vector(0,3,2),
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_SHOTGUN,
        attacksnd = "Weapon_Shotgun.Single",

        reloadtime = 0.5,  -- Per shell
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_SHOTGUN,
        reloadsounds = { { 0, "Weapon_Shotgun.Reload" } }
    },

    -- Crossbow --

    crossbow = {
        model = "models/weapons/w_crossbow.mdl",
        origin = "Half-Life 2",
        prettyname = "Crossbow",
        holdtype = "crossbow",
        killicon = "weapon_crossbow",
        bonemerge = true,
        keepdistance = 600,
        attackrange = 5000,
        islethal = true,
        dropentity = "weapon_crossbow",

        clip = 1,
        tracername = "Tracer",
        damage = 100,
        spread = 0.01,
        rateoffiremin = 1.5,
        rateoffiremax = 2.0,
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_CROSSBOW,
        attacksnd = "Weapon_Crossbow.Single",

        reloadtime = 2.0,
        reloadanim = ACT_HL2MP_GESTURE_RELOAD_CROSSBOW,
        reloadsounds = { { 0.5, "Weapon_Crossbow.Reload" } }
    },

    -- Special --

    none = {
        model = "",
        origin = "Experimental Players",
        prettyname = "None",
        holdtype = "normal",
        ismelee = true,
        nodraw = true,
        keepdistance = 0,
        attackrange = 0,
        islethal = false,
        cantbeselected = true,
        damage = 0,
        rateoffire = 1,
        attackanim = ACT_HL2MP_GESTURE_RANGE_ATTACK_FIST,
    },

} )

print( "[Experimental Players] Half-Life 2 weapons loaded" )
