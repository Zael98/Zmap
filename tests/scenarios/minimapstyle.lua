-- The minimap's look: each style puts its mask and what is behind it; its size; the zone's name and tracking
-- button hidden; Blizzard's look back; Blizzard setting its look again (the minimap turning) keeps Zmap's.
START()
local MS = ZNS.MinimapStyle
local function Back()
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Frame" and w.disc and w.parent == MinimapCluster.MinimapContainer then return w end
    end
end
local out = {}
for _, key in ipairs(MS.ORDER) do
    ZNS.SetOpt("mmStyle", key)
    local b = Back()
    out[#out + 1] = ("%s: mask %s, back %s, border %s, shape %s"):format(key, tostring(Minimap.mask):match("([%w_%-]+)$"),
        tostring(b and b:IsShown()), tostring(MinimapCompassTexture:IsShown()), GetMinimapShape())
end
OUT(table.concat(out, " | "))
ZNS.SetOpt("mmStyle", "square_dark")
ZNS.SetOpt("mmScale", 1.3)
ZNS.SetOpt("mmZone", false)
ZNS.SetOpt("mmTracking", false)
OUT(("square_dark: scale %.1f, zone %s, tracking %s"):format(Minimap:GetScale(), tostring(MinimapCluster.ZoneTextButton:IsShown()),
    tostring(MinimapCluster.Tracking:IsShown())))
MinimapCluster:UpdateMinimapConfig()   -- (Blizzard setting its look: the minimap turned)
OUT("after Blizzard's update: mask " .. tostring(Minimap.mask):match("([%w_%-]+)$"))
MS.Next()
OUT("next: " .. ZNS.Opt("mmStyle"))
OUT("errors " .. #STATE.errors)
