local Common = Ext.Require("Shared/Common.lua")
local ServerLog = Ext.Require("Server/ServerLog.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ServerLog.Add("Regroup " .. Common.ModVersion() .. " loaded.")
end)

local Regroup = Ext.Require("Server/Regroup.lua")
Regroup.Init()
