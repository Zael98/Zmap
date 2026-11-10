-- M (or whatever key opens the world map) opens Zmap instead, and L (the quest log's key) opens Zmap with its
-- quest log: override bindings that click buttons of ours, so Blizzard's map is never touched (each can be
-- given back in the options). Bindings.xml adds keys of Zmap's own to the key bindings, under AddOns.
local _, ns = ...
local L = ns.L

BINDING_HEADER_ZMAP = "Zmap"
BINDING_NAME_ZMAP_TOGGLE = L.BINDING_TOGGLE
BINDING_NAME_ZMAP_QUESTS = L.BINDING_QUESTS

function Zmap_Toggle() ns.Map.Toggle() end
function Zmap_ToggleQuests() ns.Map.ToggleQuests() end

local owner = CreateFrame("Frame")
local toggle = CreateFrame("Button", "ZmapToggleButton", UIParent)
toggle:SetScript("OnClick", function() ns.Map.Toggle() end)
local quests = CreateFrame("Button", "ZmapQuestsButton", UIParent)
quests:SetScript("OnClick", function() ns.Map.ToggleQuests() end)

local applied = ""   -- the keys we took over, so our own changes (they fire UPDATE_BINDINGS) are not redone
local waiting = false

local function Apply()
    if not ns.db then return end
    if InCombatLockdown() then   -- bindings cannot change in combat
        waiting = true
        return
    end
    local mapKeys = ns.Opt("replaceMap") and { GetBindingKey("TOGGLEWORLDMAP") } or {}
    local logKeys = ns.Opt("replaceQuestLog") and { GetBindingKey("TOGGLEQUESTLOG") } or {}
    local want = table.concat(mapKeys, " ") .. "|" .. table.concat(logKeys, " ")
    if want == applied then return end
    ClearOverrideBindings(owner)
    for _, key in ipairs(mapKeys) do SetOverrideBindingClick(owner, false, key, "ZmapToggleButton") end
    for _, key in ipairs(logKeys) do SetOverrideBindingClick(owner, false, key, "ZmapQuestsButton") end
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
    if key == "replaceMap" or key == "replaceQuestLog" then
        applied = "?"
        Apply()
    end
end)
