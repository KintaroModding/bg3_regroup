local Common = Ext.Require("Shared/Common.lua")
local ClientLog = Ext.Require("Client/ClientLog.lua")

Ext.Events.SessionLoaded:Subscribe(function()
    ClientLog.Add("Regroup " .. Common.ModVersion() .. " loaded.")
end)
