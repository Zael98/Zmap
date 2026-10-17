-- M (or whatever key opens the world map) opens Zmap instead: an override binding that clicks a button of
-- ours, so Blizzard's map is never touched (its quest log, L, still opens it). Bindings.xml adds a key of
-- Zmap's own to the key bindings, under AddOns.
local _, ns = ...
local L = ns.L

BINDING_HEADER_ZMAP = "Zmap"
BINDING_NAME_ZMAP_TOGGLE = L.BINDING_TOGGLE

function Zmap_Toggle() ns.Map.Toggle() end

local owner = CreateFrame("Frame")
local toggle = CreateFrame("Button", "ZmapToggleButton", UIParent)
toggle:SetScript("OnClick", function() ns.Map.Toggle() end)

local applied = ""   -- the keys we took over, so our own changes (they fire UPDATE_BINDINGS) are not redone
local waiting = false

local function Apply()
    if not ns.db then return end
    if InCombatLockdown() then   -- bindings cannot change in combat
        waiting = true
        return
    end
    local keys = {}
    if ns.Opt("replaceMap") then keys = { GetBindingKey("TOGGLEWORLDMAP") } end
    local want = table.concat(keys, " ")
    if want == applied then return end
    ClearOverrideBindings(owner)
    for _, key in ipairs(keys) do
        SetOverrideBindingClick(owner, false, key, "ZmapToggleButton")
    end
    applied = want
end

ns.On("PLAYER_LOGIN", Apply)
ns.On("UPDATE_BINDINGS", Apply)
ns.On("PLAYER_REGEN_ENABLED", function()
    if waiting then
        waiting = false
        Apply()
    end
end)
ns.On("ZMAP_OPTION", function(key)
    if key == "replaceMap" then
        applied = "?"
        Apply()
    end
end)
