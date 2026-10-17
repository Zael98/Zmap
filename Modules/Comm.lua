-- Messages between Zmap users (addon messages, prefix "Zmap"): fields separated by tabs, the first saying
-- what it is. Positions (P, Q), shared pins (W) and finds (N, T); each module registers what it reads.
local _, ns = ...
local Comm = {}
ns.Comm = Comm

local PREFIX = "Zmap"
local handlers = {}

if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

function Comm.On(kind, fn) handlers[kind] = fn end

local function Clean(v)
    return (tostring(v or ""):gsub("[\t|\n]", " "))
end

-- channel: "GUILD", "PARTY", "RAID" or "WHISPER" (with target). False when it cannot go now.
function Comm.Send(kind, channel, target, ...)
    if not (C_ChatInfo and C_ChatInfo.SendAddonMessage) then return false end
    if channel == "GUILD" and not IsInGuild() then return false end
    if (channel == "PARTY" or channel == "RAID") and not IsInGroup() then return false end
    local parts = { kind }
    for i = 1, select("#", ...) do parts[#parts + 1] = Clean((select(i, ...))) end
    local msg = table.concat(parts, "\t")
    if #msg > 250 then msg = msg:sub(1, 250) end
    local ok = pcall(C_ChatInfo.SendAddonMessage, PREFIX, msg, channel, target)
    return ok
end

local function Split(text)
    local out = {}
    for field in (text .. "\t"):gmatch("([^\t]*)\t") do out[#out + 1] = field end
    return out
end

ns.On("CHAT_MSG_ADDON", function(prefix, text, channel, sender)
    if prefix ~= PREFIX or not text or not sender then return end
    if issecretvalue and (issecretvalue(text) or issecretvalue(sender)) then return end
    if Ambiguate(sender, "none") == UnitName("player") then return end
    local fields = Split(text)
    local fn = handlers[fields[1]]
    if fn then fn(sender, channel, unpack(fields, 2)) end
end)
