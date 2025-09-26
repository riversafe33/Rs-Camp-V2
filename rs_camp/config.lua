Config = {}

Config.RenderDistace = 100.0       -- Distance at which objects fade away when moving away

Config.Commands = {
    Camp = "camp",                 -- Command to activate the target and collect the camp props
    Shareperms = "shareperm",      -- Command to give access to a chest or door to another player
    Unshareperms = "unshareperm",  -- Command to remove access to chests or door
}

Config.Input = {
    Confirm = "Confirm",
    MinMax = "0.01 to 5",
    Change = "Only numbers between 0.01 and 5 are allowed",
    Speed = "Change speed",
}

Config.Text = {
    StorageName = "Storage",
    Chest = "Chest",
    Dontchest = "You cannot open this storage",
    Target = "Target",
    Targeton = "Target activated",
    Targetoff = "Target deactivated",
    Camp = "Camp",
    Place = "Camp placed!",
    Cancel = "Placement cancelled.",
    Picked = "You have stored your camp",
    Dont = "This camp does not belong to you",
    TargetActiveText = "Use /",
    TargetActiveText1 = " to deactivate the target",
    Sharecorret = "Player ID",
    Dontowner = "You are not the owner of this object",
    Playerno = "Player not found or not connected",
    Already = "The player already has access to this object",
    Permsyes = "Successfully shared",
    Permsdont = "Object not found",
    Corret = "Chest or Door ID",
    Allpermission = "All permissions have been revoked",
    Playerpermi = "ID of the player you want to give permission to",
    Shared = "Share a chest or door with another player",
    Remove = "Remove all permissions",
    Door = "Door",
    Dontdoor = "You do not have access to this door",
    Perms = "Permissions",
    SpeedLabel = "Speed",
}

Config.ControlsPanel = {
    title = "Controls",
    controls = {
        "[Mouse Scroll] - Adjust Speed",
        "[← ↑ ↓ →] - Move object",
        "[1/2]     - Rotate Z",
        "[3/4]     - Rotate X",
        "[5/6]     - Rotate Y",
        "[7/8]     - Move Up/Down",
        "[ENTER]   - Confirm Position",
        "[G]       - Cancel Placement",
        "[F]       - Place on Ground",
    }
}


Config.Promp = {
    Collect = "Pickut",
    Controls = "Camp",
    Chest = "Chest",
    Chestopen = "Storage",
    Door = "Door",
    Dooropen = "Open/Close",
    Key = {
        Pickut = 0xE30CD707, -- R
        Chest = 0x760A9C6F,  -- G
        Door = 0x760A9C6F,   -- G
    }
}

Config.Keys = {
    moveForward    = 0x6319DB71, -- Arrow Up
    moveBackward   = 0x05CA7C52, -- Arrow Down
    moveLeft       = 0xA65EBAB4, -- Arrow Left
    moveRight      = 0xDEB34313, -- Arrow Right
    rotateLeftZ    = 0xE6F612E4, -- 1
    rotateRightZ   = 0x1CE6D9EB, -- 2
    rotateUpX      = 0x4F49CC4C, -- 3
    rotateDownX    = 0x8F9F9E58, -- 4
    rotateLeftY    = 0xAB62E997, -- 5
    rotateRightY   = 0xA1FDE2A6, -- 6
    moveUp         = 0xB03A913B, -- 7
    moveDown       = 0x42385422, -- 8
    placeOnGround  = 0xB2F377E8, -- F
    cancelPlace    = 0x760A9C6F, -- G
    confirmPlace   = 0xC7B5340A, -- ENTER
    increaseSpeed = 0xCC1075A7, -- MSCROLLUP
    decreaseSpeed = 0xFD0F0C2C, -- MSCROLLDOWN
}

Config.Chests = {
	{ object = 's_re_rcboatbox01x', capacity = 400 },
    { object = 'p_trunk04x', capacity = 700 },
    { object = 's_lootablebedchest', capacity = 1000 },
    -- Add whatever you want
}

Config.Doors = {
	{ modelDoor = 'val_p_door_lckd_1'},
    { modelDoor = 'p_doornbd39x_destruct'},
    { modelDoor = 'p_doorstrawberry01x_new'},
    { modelDoor = 'p_doorriverboat01x'},
    -- Add whatever you want
}

-- If you set veg = 10.0 at the end, that object will remove vegetation when placed. 
-- 10.0 is the vegetation clearing radius, change it to whatever you prefer.
Config.Items = {

    -- Tent
    ["tent_trader"] = { model = "mp005_s_posse_tent_trader07x", veg = 10.0},
    ["tent_bounty07"] = { model = "mp005_s_posse_tent_bountyhunter07x", veg = 10.0},
    ["tent_bounty02"] = { model = "mp005_s_posse_tent_bountyhunter02x", veg = 10.0},
    ["tent_bounty06"] = { model = "mp005_s_posse_tent_bountyhunter06x", veg = 10.0},
    ["tent_collector04"] = { model = "mp005_s_posse_tent_collector04x", veg = 10.0},

    -- Hitch post
    ["hitchingpost_wood"] = { model = "p_hitchingpost04x"},
    ["hitchingpost_iron"] = { model = "p_horsehitchnbd01x"},
    ["hitchingpost_wood_double"] = { model = "p_hitchingpost01x"},
    
    -- Chair
    ["chair_wood"] = { model = "p_chair05x"},

    -- Table
    ["table_wood01"] = { model = "p_table48x"},

    -- Campfire
    ["campfire_01"] = { model = "p_campfirecombined03x"},
    ["campfire_02"] = { model = "p_campfire05x"},

    -- Chest
    ["chest_little"] = { model = "s_re_rcboatbox01x"},
    ["chest_medium"] = { model = "p_trunk04x"},
    ["chest_big"] = { model = "s_lootablebedchest"},

    -- Door
    ["door_01"] = { model = "val_p_door_lckd_1"},
    ["door_02"] = { model = "p_doornbd39x_destruct"},
    ["door_03"] = { model = "p_doorstrawberry01x_new"},
    ["door_04"] = { model = "p_doorriverboat01x"},
    -- Add whatever you want
}
