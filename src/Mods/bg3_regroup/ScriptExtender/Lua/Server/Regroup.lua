-- The Regroup spell. Every party member and camp companion has it. A cast teleports the caster's party members and
-- their summons to free spots around the caster, so that nobody stands inside another character.

local ServerLog = Ext.Require("Server/ServerLog.lua")

local Regroup = {}

Regroup.SpellName = "Regroup_Shout"
-- Effect on each character that is teleported (the effect of the earlier Teleport To You spell).
Regroup.TeleportEffect = "70ebf4d3-46f9-1cd2-7f59-15bd673f5bdb"
-- Spots around the caster, nearest ring first: radius in meters and the number of spots on the ring.
Regroup.Rings = {
    { Radius = 1.5, Spots = 6 },
    { Radius = 2.5, Spots = 10 },
    { Radius = 3.5, Spots = 14 },
}
-- How far FindValidPosition may move a spot to reach free, walkable ground (meters).
Regroup.SearchRadius = 2.0
-- Two characters closer than this (meters) would stand in each other; such a spot is not used.
Regroup.MinSpacing = 0.9

--- The UUID part of an Osiris GUID string ("S_Player_Karlach_2c76687d-...": the last 36 characters).
local function Uuid(guid)
    return string.sub(guid, -36)
end

--- A short name for the log: the GUID string without its UUID, or the UUID when there is no name.
local function Short(guid)
    local name = string.sub(guid, 1, -38)
    return name ~= "" and name or guid
end

local function IsSummon(character)
    return Osi.IsSummon(character) == 1
end

--- Gives the spell to a character that does not have it yet (summons do not get it). Returns true when added.
function Regroup.Give(character)
    if IsSummon(character) or Osi.HasSpell(character, Regroup.SpellName) == 1 then
        return false
    end
    Osi.AddSpell(character, Regroup.SpellName, 0, 1)
    return true
end

--- Gives the spell to the party members (DB_Players) and the camp companions (DB_PartOfTheTeam).
function Regroup.GiveToTeam()
    local added, seen = 0, {}
    for _, db in ipairs({ "DB_Players", "DB_PartOfTheTeam" }) do
        for _, row in ipairs(Osi[db]:Get(nil) or {}) do
            local character = row[1]
            if not seen[Uuid(character)] then
                seen[Uuid(character)] = true
                if Regroup.Give(character) then
                    added = added + 1
                end
            end
        end
    end
    return added
end

--- True when the character belongs to the caster's party: a party member, or a summon of one.
local function InPartyOf(character, caster)
    if Osi.IsInPartyWith(character, caster) == 1 then
        return true
    end
    local owner = Osi.CharacterGetOwner(character)
    return owner ~= nil and (Uuid(owner) == Uuid(caster) or Osi.IsInPartyWith(owner, caster) == 1)
end

--- Returns the characters that a cast moves: party members, then summons, without the caster. Characters in combat
--- stay where they are; they are listed in the second list.
function Regroup.Members(caster)
    local members, inCombat, seen = {}, {}, { [Uuid(caster)] = true }
    for _, db in ipairs({ "DB_Players", "DB_PlayerSummons" }) do
        for _, row in ipairs(Osi[db]:Get(nil) or {}) do
            local character = row[1]
            if not seen[Uuid(character)] and InPartyOf(character, caster) then
                seen[Uuid(character)] = true
                if Osi.IsInCombat(character) == 1 then
                    inCombat[#inCombat + 1] = character
                else
                    members[#members + 1] = character
                end
            end
        end
    end
    return members, inCombat
end

--- The candidate spots on the rings around (x, y, z). Y is the height in the game, so the rings lie in x and z.
local function CandidateSpots(x, y, z)
    local spots = {}
    for _, ring in ipairs(Regroup.Rings) do
        for i = 0, ring.Spots - 1 do
            local angle = 2 * math.pi * i / ring.Spots
            spots[#spots + 1] = { x + ring.Radius * math.cos(angle), y, z + ring.Radius * math.sin(angle) }
        end
    end
    return spots
end

local function FarFromAll(x, y, z, taken)
    for _, position in ipairs(taken) do
        local dx, dy, dz = x - position[1], y - position[2], z - position[3]
        if dx * dx + dy * dy + dz * dz < Regroup.MinSpacing * Regroup.MinSpacing then
            return false
        end
    end
    return true
end

--- Finds a free spot for each member: the next ring spot that FindValidPosition accepts and that is not too close to
--- the caster or to a spot given before. Returns { Character, Position = {x, y, z} or nil } per member, in order.
function Regroup.Place(caster, members)
    local cx, cy, cz = Osi.GetPosition(caster)
    local placements = {}
    if cx == nil then
        for _, member in ipairs(members) do
            placements[#placements + 1] = { Character = member }
        end
        return placements
    end
    local spots = CandidateSpots(cx, cy, cz)
    local taken = { { cx, cy, cz } }
    local nextSpot = 1
    for _, member in ipairs(members) do
        local found = nil
        while found == nil and nextSpot <= #spots do
            local spot = spots[nextSpot]
            nextSpot = nextSpot + 1
            local x, y, z = Osi.FindValidPosition(spot[1], spot[2], spot[3], Regroup.SearchRadius, member, 1)
            if x ~= nil and FarFromAll(x, y, z, taken) then
                found = { x, y, z }
                taken[#taken + 1] = found
            end
        end
        placements[#placements + 1] = { Character = member, Position = found }
    end
    return placements
end

--- Runs the spell for a cast: teleports every member to its spot. A member without a free spot goes to the caster
--- with the game's own teleport. Returns the number of characters on free spots and on the caster.
function Regroup.Cast(caster)
    local members, inCombat = Regroup.Members(caster)
    local onSpot, onCaster = 0, 0
    for _, placement in ipairs(Regroup.Place(caster, members)) do
        local character, position = placement.Character, placement.Position
        Osi.PlayEffect(character, Regroup.TeleportEffect, "", 1.0)
        if position ~= nil then
            Osi.TeleportToPosition(character, position[1], position[2], position[3], "", 0, 0, 0, 0, 1)
            onSpot = onSpot + 1
        else
            Osi.TeleportTo(character, caster, "", 0, 0, 0, 0, 1)
            onCaster = onCaster + 1
        end
    end
    local message = string.format("Regroup by %s: %d to free spots, %d to the caster (no free spot)", Short(caster),
        onSpot, onCaster)
    if #inCombat > 0 then
        local names = {}
        for _, character in ipairs(inCombat) do
            names[#names + 1] = Short(character)
        end
        message = message .. ", stayed (in combat): " .. table.concat(names, ", ")
    end
    ServerLog.Add(message .. ".")
    return onSpot, onCaster
end

function Regroup.Init()
    Ext.Osiris.RegisterListener("LevelGameplayStarted", 2, "after", function(level, _)
        local added = Regroup.GiveToTeam()
        ServerLog.Add(string.format("Level %s started: Regroup given to %d character(s).", tostring(level), added))
    end)

    Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", function(character)
        if Regroup.Give(character) then
            ServerLog.Add("Regroup given to " .. Short(character) .. " (joined the party).")
        end
    end)

    -- CastedSpell fires once, when the cast is done (UsingSpell can come before or after it).
    Ext.Osiris.RegisterListener("CastedSpell", 5, "after", function(caster, spell, _, _, _)
        if spell == Regroup.SpellName then
            Regroup.Cast(caster)
        end
    end)
end

return Regroup
