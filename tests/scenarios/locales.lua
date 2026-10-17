-- Every text the code uses exists in English and Spanish, with the same %s / %d in both.
local used = {}
for _, file in ipairs(FILES) do
    for key in SOURCES[file]:gmatch("L%.([%w_]+)") do used[key] = true end
end
for _, prefix in ipairs({ "COLOR_1", "COLOR_2", "COLOR_3", "COLOR_4", "COLOR_5", "COLOR_6", "UNEXPLORED_show",
    "UNEXPLORED_dim", "UNEXPLORED_hide", "FOLK_vendor", "FOLK_repair", "FOLK_trainer", "FOLK_profession",
    "FOLK_innkeeper", "FOLK_banker", "FOLK_auctioneer", "FOLK_stable", "FOLK_spirit", "FOLK_mailbox",
    "OPT_LABELS", "OPT_LEVELS", "OPT_FLIGHTS", "OPT_DUNGEONS", "OPT_TRANSPORTS", "OPT_QUESTS", "OPT_GROUP",
    "OPT_GUILD", "OPT_PINS", "OPT_HERBS", "OPT_ORE", "OPT_TOWNSFOLK", "OPT_MINIMAP", "OPT_RARES",
    "SERVICE_innkeeper", "SERVICE_vendor", "SERVICE_repair", "SERVICE_trainer", "SERVICE_flight", "SERVICE_banker",
    "SERVICE_auctioneer", "SERVICE_stable", "SERVICE_spirit", "SERVICE_battlemaster", "SERVICE_guildbank",
    "SERVICE_mailbox" }) do used[prefix] = true end
for _, t in ipairs(ZNS.TRANSPORTS) do used["ROUTE_" .. t[3]] = true end
local EN, ES = ZNS.LOCALES.EN, ZNS.LOCALES.ES
local missEN, missES, mismatch = {}, {}, {}
for key in pairs(used) do
    if not EN[key] then missEN[#missEN + 1] = key end
    if not ES[key] then missES[#missES + 1] = key end
end
for key, en in pairs(EN) do
    local es = ES[key]
    if es then
        local a, b = {}, {}
        for f in en:gmatch("%%[sd]") do a[#a + 1] = f end
        for f in es:gmatch("%%[sd]") do b[#b + 1] = f end
        if table.concat(a) ~= table.concat(b) then mismatch[#mismatch + 1] = key end
    else
        missES[#missES + 1] = key
    end
end
table.sort(missEN); table.sort(missES); table.sort(mismatch)
OUT("missing en: " .. (#missEN > 0 and table.concat(missEN, ", ") or "none"))
OUT("missing es: " .. (#missES > 0 and table.concat(missES, ", ") or "none"))
OUT("format mismatch: " .. (#mismatch > 0 and table.concat(mismatch, ", ") or "none"))
