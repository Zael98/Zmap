-- Boats and zeppelins you can take: the way each sails (from the client's tables, Data/Places.lua) and an
-- icon at each dock. Alliance boats, Horde zeppelins and the neutral Booty Bay boat, by your faction.
local _, ns = ...
local L, Geo = ns.L, ns.Geo

local P = ns.Pins.New("transports", { level = 35, size = 20, option = "transports", minZoom = 1.3 })
local lines = ns.Pins.Lines()

local COLORS = { boat = { 0.35, 0.68, 1 }, zeppelin = { 1, 0.5, 0.2 } }
local ICONS = { boat = "Interface\\Icons\\INV_AllianceShipMount", zeppelin = "Interface\\Icons\\INV_HordeZeppelinMount" }

local function Mine(faction)
    local f = UnitFactionGroup("player")
    return faction == "N" or (faction == "A" and f == "Alliance") or (faction == "H" and f == "Horde")
end

function P:OnCreate(pin)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.border = pin:CreateTexture(nil, "OVERLAY")
    pin.border:SetAtlas("WhiteCircle-RaidBlips")
    pin.border:SetAllPoints()
    pin.border:SetAlpha(0)
end

function P:Refresh()
    self:ReleaseAll()
    lines:Clear()
    for _, t in ipairs(ns.TRANSPORTS) do
        local kind, faction, name, pieces, docks = t[1], t[2], t[3], t[4], t[5]
        if Mine(faction) then
            local c = COLORS[kind]
            local prev
            for _, piece in ipairs(pieces) do
                local pts = {}
                for i = 1, #piece[2] - 1, 2 do
                    local u, v = Geo.FromYards(piece[1], piece[2][i], piece[2][i + 1])
                    pts[#pts + 1], pts[#pts + 2] = u, v
                end
                if prev then   -- open sea between the pieces (another continent, or a jump): faint
                    lines:Add(prev[1], prev[2], pts[1], pts[2], c[1], c[2], c[3], 0.25, 2)
                end
                lines:AddPath(pts, c[1], c[2], c[3], 0.6, 2)
                prev = { pts[#pts - 1], pts[#pts] }
            end
            for _, d in ipairs(docks) do
                local u, v = Geo.FromYards(d[1], d[2], d[3])
                local pin = self:Acquire()
                pin.icon:SetTexture(ICONS[kind])
                pin.route, pin.kind = name, kind
                self:Place(pin, u, v)
            end
        end
    end
end

function P:Tooltip(pin, tip)
    tip:SetText(L["ROUTE_" .. pin.route] or pin.route, 1, 1, 1)
    tip:AddLine(pin.kind == "boat" and L.BOAT or L.ZEPPELIN, 0.7, 0.7, 0.7)
end

function P:OnHidden() lines:Clear() end
