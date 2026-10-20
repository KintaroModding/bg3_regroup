-- The Regroup spell on the server: who gets the spell, who a cast moves, and where to.

Harness.Mods[ModuleUUID] = { Info = { ModVersion = { 1, 0, 0, 0 } } }

--- An Osiris GUID string: name and a 36-character UUID made from the number.
local function Guid(name, n)
    return string.format("%s_%08d-0000-0000-0000-%012d", name, n, n)
end

local Caster = Guid("S_Player_Caster", 1)
local Friend = Guid("S_Player_Friend", 2)
local Camper = Guid("S_Camp_Companion", 3)
local Pet = Guid("S_Summon_Wolf", 4)
local Newcomer = Guid("S_Hireling", 5)

-- [guid] = { Position, InParty (with the caster), Summon, Owner, Combat, Spells }
local World = {}
local Calls = {}

local function Reset()
    World = {
        [Caster] = { Position = { 10, 0, 20 }, InParty = true, Spells = {} },
        [Friend] = { Position = { 50, 0, 60 }, InParty = true, Spells = {} },
        [Camper] = { Position = { 90, 0, 90 }, InParty = false, Spells = {} },
        [Pet] = { Position = { 70, 0, 70 }, InParty = false, Summon = true, Owner = Friend, Spells = {} },
        [Newcomer] = { Position = { 0, 0, 0 }, InParty = true, Spells = {} },
    }
    Calls = { AddSpell = {}, TeleportToPosition = {}, TeleportTo = {}, PlayEffect = {} }
    Harness.ValidPosition = function(x, y, z)
        return x, y, z
    end
end
Reset()

local function Rows(list)
    local rows = {}
    for _, guid in ipairs(list) do
        rows[#rows + 1] = { guid }
    end
    return rows
end

local DbPlayers, DbTeam, DbSummons = { Caster, Friend }, { Caster, Friend, Camper }, { Pet }
Osi.DB_Players = { Get = function(_, _) return Rows(DbPlayers) end }
Osi.DB_PartOfTheTeam = { Get = function(_, _) return Rows(DbTeam) end }
Osi.DB_PlayerSummons = { Get = function(_, _) return Rows(DbSummons) end }
Osi.IsSummon = function(guid) return World[guid].Summon and 1 or 0 end
Osi.HasSpell = function(guid, spell) return World[guid].Spells[spell] and 1 or 0 end
Osi.AddSpell = function(guid, spell, notify, container)
    World[guid].Spells[spell] = true
    Calls.AddSpell[#Calls.AddSpell + 1] = { guid, spell, notify, container }
end
Osi.IsInPartyWith = function(guid, other)
    assert(other == Caster or World[other].InParty, "IsInPartyWith: the second character is the caster's party")
    return World[guid].InParty and 1 or 0
end
Osi.CharacterGetOwner = function(guid) return World[guid].Owner end
Osi.IsInCombat = function(guid) return World[guid].Combat and 1 or 0 end
Osi.GetPosition = function(guid)
    local p = World[guid].Position
    if p == nil then
        return nil
    end
    return p[1], p[2], p[3]
end
Osi.FindValidPosition = function(x, y, z, radius, object, avoidDanger)
    assert(radius > 0 and World[object] ~= nil and avoidDanger == 1, "FindValidPosition arguments")
    return Harness.ValidPosition(x, y, z)
end
Osi.TeleportToPosition = function(guid, x, y, z, event, linked, followers, summons, leaveCombat, snap)
    Calls.TeleportToPosition[#Calls.TeleportToPosition + 1] = {
        Character = guid, Position = { x, y, z }, Args = { event, linked, followers, summons, leaveCombat, snap } }
end
Osi.TeleportTo = function(guid, target, event, linked, followers, summons, leaveCombat, snap)
    Calls.TeleportTo[#Calls.TeleportTo + 1] = {
        Character = guid, Target = target, Args = { event, linked, followers, summons, leaveCombat, snap } }
end
Osi.PlayEffect = function(guid, effect, bone, scale)
    Calls.PlayEffect[#Calls.PlayEffect + 1] = { guid, effect, bone, scale }
end

Ext.Require("BootstrapServer.lua")
local Regroup = Ext.Require("Server/Regroup.lua")

local function ServerLog()
    Harness.RunTimers()
    return Harness.Files["bg3_regroup/server.log"] or ""
end

local function Cast(spell)
    Harness.Listeners["CastedSpell/5"](Caster, spell or "Regroup_Shout", "Shout", "", 1)
end

local function Distance(a, b)
    local dx, dy, dz = a[1] - b[1], a[2] - b[2], a[3] - b[3]
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function MovedCharacters()
    local moved = {}
    for _, call in ipairs(Calls.TeleportToPosition) do
        moved[call.Character] = call.Position
    end
    return moved
end

Test("the level start gives the spell to party members and camp companions, once", function()
    Reset()
    DbTeam = { Caster, Friend, Camper, Pet }
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(#Calls.AddSpell, 3, "three characters")
    for _, call in ipairs(Calls.AddSpell) do
        AssertTrue(call[1] ~= Pet, "a summon does not get the spell")
        AssertEq(call[2], "Regroup_Shout", "spell")
        AssertEq(call[3], 0, "no notification")
        AssertEq(call[4], 1, "container spells")
    end
    Harness.Listeners["LevelGameplayStarted/2"]("WLD_Main_A", 0)
    AssertEq(#Calls.AddSpell, 3, "a second level start adds nothing")
    AssertTrue(string.find(ServerLog(), "Level WLD_Main_A started: Regroup given to 0 character(s).", 1, true), "log")
    DbTeam = { Caster, Friend, Camper }
end)

Test("a character that joins the party gets the spell, a summon does not", function()
    Reset()
    Harness.Listeners["CharacterJoinedParty/1"](Newcomer)
    Harness.Listeners["CharacterJoinedParty/1"](Pet)
    AssertEq(#Calls.AddSpell, 1, "one call")
    AssertEq(Calls.AddSpell[1][1], Newcomer, "the new party member")
    AssertTrue(string.find(ServerLog(), "Regroup given to S_Hireling (joined the party).", 1, true), "log")
end)

Test("a cast moves party members and their summons to separate free spots around the caster", function()
    Reset()
    Cast()
    local moved = MovedCharacters()
    AssertTrue(moved[Friend] ~= nil, "the party member moved")
    AssertTrue(moved[Pet] ~= nil, "the summon of a party member moved")
    AssertEq(moved[Camper], nil, "a camp companion stays in camp")
    AssertEq(moved[Caster], nil, "the caster stays")
    AssertEq(#Calls.TeleportToPosition, 2, "two teleports")
    AssertEq(#Calls.TeleportTo, 0, "no fallback")
    local center = World[Caster].Position
    for character, position in pairs(moved) do
        local distance = Distance(position, center)
        AssertTrue(distance >= 1.0 and distance <= 4.0, character .. " is near the caster: " .. distance)
        AssertEq(position[2], center[2], "same height before the game snaps to the ground")
    end
    AssertTrue(Distance(moved[Friend], moved[Pet]) >= Regroup.MinSpacing, "not inside each other")
    for _, call in ipairs(Calls.TeleportToPosition) do
        local args = call.Args
        AssertEq(table.concat({ args[1], args[2], args[3], args[4], args[5], args[6] }, ","), ",0,0,0,0,1",
            "no linked characters, followers or summons, no combat change, snap to ground")
    end
    AssertEq(#Calls.PlayEffect, 2, "an effect on each teleported character")
    AssertTrue(string.find(ServerLog(), "Regroup by S_Player_Caster: 2 to free spots, 0 to the caster (no free spot).",
        1, true), "log")
end)

Test("other spells do nothing", function()
    Reset()
    Cast("Shout_Dash")
    AssertEq(#Calls.TeleportToPosition + #Calls.TeleportTo, 0, "no teleport")
end)

Test("a party member in combat stays where it is", function()
    Reset()
    World[Friend].Combat = true
    Cast()
    local moved = MovedCharacters()
    AssertEq(moved[Friend], nil, "the fighting member stays")
    AssertTrue(moved[Pet] ~= nil, "the summon still comes")
    AssertTrue(string.find(ServerLog(), "1 to free spots, 0 to the caster (no free spot), stayed (in combat): S_Player_Friend.",
        1, true), "log")
end)

Test("spots that the game moves onto each other are not used twice", function()
    Reset()
    -- Every spot leads to the same valid position, for example in a narrow corridor.
    Harness.ValidPosition = function(_, y, _)
        return 11.5, y, 20
    end
    Cast()
    AssertEq(#Calls.TeleportToPosition, 1, "one character on the only free spot")
    AssertEq(#Calls.TeleportTo, 1, "the other one goes to the caster with the game's teleport")
    AssertEq(Calls.TeleportTo[1].Target, Caster, "target")
    AssertEq(table.concat(Calls.TeleportTo[1].Args, ","), ",0,0,0,0,1", "fallback arguments")
end)

Test("no valid position at all: everyone goes to the caster with the game's teleport", function()
    Reset()
    Harness.ValidPosition = function()
        return nil
    end
    Cast()
    AssertEq(#Calls.TeleportToPosition, 0, "no free spots")
    AssertEq(#Calls.TeleportTo, 2, "game teleport for both")
end)

Test("no caster position: everyone goes to the caster with the game's teleport", function()
    Reset()
    World[Caster].Position = nil
    Cast()
    AssertEq(#Calls.TeleportTo, 2, "game teleport for both")
end)
