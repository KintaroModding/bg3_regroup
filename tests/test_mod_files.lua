-- The data files of the mod fit together: spell name, texts, icon name, icon sheet and icon files.

local SRC = MOD_LUA_ROOT .. "/../../../.."

local function Read(path)
    local text = READ_FILE(SRC .. "/" .. path)
    AssertTrue(text ~= nil, "missing file: src/" .. path)
    return text
end

local Regroup = Ext.Require("Server/Regroup.lua")
local stats = Read("Public/bg3_regroup/Stats/Generated/Data/Spell_Regroup.txt")

local function Field(name)
    return string.match(stats, 'data "' .. name .. '" "([^"]*)"')
end

Test("the spell entry has the name that the script uses", function()
    AssertEq(string.match(stats, 'new entry "([^"]+)"'), Regroup.SpellName, "entry name")
    AssertEq(Field("SpellType"), "Shout", "spell type")
    AssertEq(Field("Requirements"), "!Combat", "not in combat")
    AssertEq(Field("UseCosts"), nil, "free: no UseCosts")
end)

Test("the name and the description have texts", function()
    local loca = Read("Localization/English/bg3_regroup.loca.xml")
    for _, name in ipairs({ "DisplayName", "Description" }) do
        local handle, version = string.match(Field(name) or "", "^(h[%w]+);(%d+)$")
        AssertTrue(handle ~= nil, name .. " is a handle with a version")
        local text = string.match(loca, 'contentuid="' .. handle .. '" version="' .. version .. '">([^<]+)<')
        AssertTrue(text ~= nil and text ~= "", name .. " has a text in bg3_regroup.loca.xml")
    end
end)

Test("the icon name, the icon sheet and the texture bank fit together", function()
    local icon = Field("Icon")
    local atlas = Read("Public/bg3_regroup/GUI/Icons_Skills.lsx")
    local bank = Read("Public/bg3_regroup/Content/UI/[PAK]_UI/_merged.lsf.lsx")
    AssertTrue(string.find(atlas, 'id="MapKey" type="FixedString" value="' .. icon .. '"', 1, true), "MapKey = Icon")
    local sheet = string.match(atlas, 'id="Path" type="string" value="([^"]+)"')
    AssertTrue(sheet ~= nil, "the sheet path has the type string, as in the game's Icons_Skills.lsx")
    local atlasId = string.match(atlas, 'id="UUID" type="FixedString" value="([^"]+)"')
    AssertTrue(string.find(bank, 'value="' .. atlasId .. '"', 1, true), "texture bank ID = sheet UUID")
    AssertTrue(string.find(bank, 'value="Public/bg3_regroup/' .. sheet .. '"', 1, true), "texture bank file = sheet path")
    local name = string.match(bank, 'id="Name" type="LSString" value="([^"]+)"')
    AssertTrue(string.find(bank, 'id="Template" type="FixedString" value="' .. name .. '"', 1, true),
        "Template = Name, as in the game's texture bank")
    for _, size in ipairs({ "Height", "Width" }) do
        AssertTrue(string.find(atlas, 'id="' .. size .. '" type="int32"', 1, true), size .. " has the type int32")
    end
    AssertTrue(not string.find(atlas, "int64", 1, true), "no int64 sizes")
end)

Test("the icon files exist", function()
    local icon = Field("Icon")
    local atlas = Read("Public/bg3_regroup/GUI/Icons_Skills.lsx")
    local sheet = string.match(atlas, 'id="Path" type="string" value="([^"]+)"')
    for _, path in ipairs({
        "Public/bg3_regroup/" .. sheet,
        "Public/Game/GUI/Assets/Tooltips/Icons/" .. icon .. ".DDS",
        "Public/Game/GUI/Assets/ControllerUIIcons/skills_png/" .. icon .. ".DDS",
    }) do
        AssertTrue(FILE_EXISTS(SRC .. "/" .. path), "missing icon file: src/" .. path)
    end
end)
