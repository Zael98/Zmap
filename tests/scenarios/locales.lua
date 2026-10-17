-- Every text the code uses exists in every language, with the same %s / %d (in the same order) as in English.
local used = {}
for _, file in ipairs(FILES) do
    if not file:find("^Data/") and not file:find("^Locales") then   -- (the data's names are not texts of ours)
        for key in SOURCES[file]:gmatch("L%.([%w_]+)") do used[key] = true end
    end
end
-- the texts the code builds the key of
for _, key in ipairs({ "COLOR_1", "COLOR_2", "COLOR_3", "COLOR_4", "COLOR_5", "COLOR_6", "UNEXPLORED_show",
    "UNEXPLORED_dim", "UNEXPLORED_hide", "FOLK_vendor", "FOLK_repair", "FOLK_trainer", "FOLK_profession",
    "FOLK_innkeeper", "FOLK_banker", "FOLK_auctioneer", "FOLK_stable", "FOLK_spirit", "FOLK_mailbox",
    "FOLK_anvil", "FOLK_forge", "FOLK_stone",
    "SERVICE_innkeeper", "SERVICE_vendor", "SERVICE_repair", "SERVICE_trainer", "SERVICE_flight", "SERVICE_banker",
    "SERVICE_auctioneer", "SERVICE_stable", "SERVICE_spirit", "SERVICE_battlemaster", "SERVICE_guildbank",
    "SERVICE_mailbox" }) do used[key] = true end
for _, t in ipairs(ZNS.FolkTypes()) do used["FOLK_TYPE_" .. t[1]] = true end
for key in SOURCES["Options.lua"]:gmatch('"(OPT_[%w_]+)"') do used[key] = true end
for key in SOURCES["Options.lua"]:gmatch('"(LAYER_GROUP_[%w_]+)"') do used[key] = true end

local EN = ZNS.LOCALES.EN
local function Formats(text)
    local out = {}
    for f in text:gmatch("%%[sd]") do out[#out + 1] = f end
    return table.concat(out)
end
local names = {}
for name in pairs(ZNS.LOCALES) do names[#names + 1] = name end
table.sort(names)
OUT("languages: " .. table.concat(names, " "))
for _, name in ipairs(names) do
    local T = ZNS.LOCALES[name]
    local missing, mismatch = {}, {}
    for key in pairs(used) do
        if not T[key] then missing[#missing + 1] = key end
    end
    for key, text in pairs(EN) do
        if T[key] and Formats(T[key]) ~= Formats(text) then mismatch[#mismatch + 1] = key end
        if not T[key] and not used[key] then missing[#missing + 1] = key end
    end
    table.sort(missing); table.sort(mismatch)
    OUT(("%s: missing %s; format mismatch %s"):format(name, #missing > 0 and table.concat(missing, ", ") or "none",
        #mismatch > 0 and table.concat(mismatch, ", ") or "none"))
end
