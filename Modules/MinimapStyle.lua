-- The minimap's look, to choose: Blizzard's own, round with a gold ring or bare, square in Zmap's style, square in
-- a dark frame or bare; its size; the zone's name above it and the tracking button, shown or not. The minimap is
-- Blizzard's (its mask and border are swapped, never the frame itself), so it goes back to its own look in one
-- click; Blizzard sets its look again when the minimap turns or stops turning, and Zmap's comes back after it.
local _, ns = ...
local MS = {}
ns.MinimapStyle = MS

local ROUND, SQUARE = "Interface\\CharacterFrame\\TempPortraitAlphaMask", "Interface\\Buttons\\WHITE8X8"
local GOLD, EDGE = { 1, 0.82, 0.25 }, { 0.62, 0.55, 0.38 }
-- mask; ring (a disc behind it, round); frame (a fill behind it and an edge round it, square); pad: how far out
local STYLES = {
    blizzard = {},
    round = { mask = ROUND, ring = GOLD, pad = 3 },
    round_clean = { mask = ROUND },
    square = { mask = SQUARE, edge = EDGE, pad = 1 },
    square_dark = { mask = SQUARE, fill = { 0.04, 0.04, 0.05, 0.95 }, edge = EDGE, pad = 6 },
    square_clean = { mask = SQUARE },
}
MS.ORDER = { "blizzard", "round", "round_clean", "square", "square_dark", "square_clean" }

local back      -- behind the minimap: the ring or the frame
local applying

function MS.Square()
    return (STYLES[ns.Opt("mmStyle")] or {}).mask == SQUARE
end

local function Back()
    if back then return back end
    back = CreateFrame("Frame", nil, MinimapCluster.MinimapContainer or Minimap:GetParent(), "BackdropTemplate")
    back:SetFrameLevel(math.max(0, Minimap:GetFrameLevel() - 1))
    back.disc = back:CreateTexture(nil, "BACKGROUND")
    back.disc:SetAllPoints()
    back.disc:SetTexture(ROUND)
    return back
end

local function Apply()
    if applying or not (Minimap and MinimapCluster) then return end
    applying = true
    local s = STYLES[ns.Opt("mmStyle")] or STYLES.blizzard
    if s.mask then
        Minimap:SetMaskTexture(s.mask)
        if MinimapCompassTexture then MinimapCompassTexture:Hide() end
        if MinimapCompassTextureUnderlay then MinimapCompassTextureUnderlay:Hide() end
    else
        if MinimapCompassTexture then MinimapCompassTexture:Show() end
        if MinimapCluster.UpdateMinimapConfig then MinimapCluster:UpdateMinimapConfig() end   -- (Blizzard's own look)
    end
    local b = Back()
    b:ClearAllPoints()
    local pad = s.pad or 0
    b:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -pad, pad)
    b:SetPoint("BOTTOMRIGHT", Minimap, "BOTTOMRIGHT", pad, -pad)
    if s.edge or s.fill then
        b:SetBackdrop({ bgFile = SQUARE, edgeFile = SQUARE, edgeSize = 1 })
        local f = s.fill or { 0, 0, 0, 0 }
        b:SetBackdropColor(f[1], f[2], f[3], f[4])
        b:SetBackdropBorderColor(s.edge[1], s.edge[2], s.edge[3], 1)
    else
        b:SetBackdrop(nil)
    end
    b.disc:SetShown(s.ring ~= nil)
    if s.ring then b.disc:SetVertexColor(s.ring[1], s.ring[2], s.ring[3], 1) end
    b:SetShown(s.ring ~= nil or s.edge ~= nil)
    Minimap:SetScale(ns.Opt("mmScale"))
    if MinimapCluster.ZoneTextButton then MinimapCluster.ZoneTextButton:SetShown(ns.Opt("mmZone")) end
    if MinimapCluster.BorderTop then MinimapCluster.BorderTop:SetShown(ns.Opt("mmZone")) end
    if MinimapCluster.Tracking then MinimapCluster.Tracking:SetShown(ns.Opt("mmTracking")) end
    -- the map drawn again through its new mask (a zoom step and back)
    local zoom = Minimap:GetZoom() or 0
    Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
    Minimap:SetZoom(zoom)
    applying = false
    ns.Fire("ZMAP_MINIMAP_STYLE")
end
MS.Apply = Apply

-- the next look (the layers panel's row)
function MS.Next()
    local now, nextStyle = ns.Opt("mmStyle"), MS.ORDER[1]
    for i, key in ipairs(MS.ORDER) do
        if key == now then nextStyle = MS.ORDER[i % #MS.ORDER + 1] end
    end
    ns.SetOpt("mmStyle", nextStyle)
end

ns.On("PLAYER_LOGIN", function()
    if not (Minimap and MinimapCluster) then return end
    -- addons that put buttons round the minimap ask its shape; nobody else has answered: Zmap does
    if not GetMinimapShape then
        function GetMinimapShape() return MS.Square() and "SQUARE" or "ROUND" end
    end
    if MinimapCluster.UpdateMinimapConfig then
        hooksecurefunc(MinimapCluster, "UpdateMinimapConfig", function()
            if not applying and (STYLES[ns.Opt("mmStyle")] or {}).mask then Apply() end
        end)
    end
    Apply()
end)
ns.On("PLAYER_ENTERING_WORLD", function() if Minimap and MinimapCluster then Apply() end end)
ns.On("ZMAP_OPTION", function(key)
    if key == "mmStyle" or key == "mmScale" or key == "mmZone" or key == "mmTracking" then Apply() end
end)
