-- What the scenarios do as a player would: log in, open the map, move the cursor, click, scroll, wait.

function EVENT(name, ...) ZNS.Fire(name, ...) end

function START()
    EVENT("ADDON_LOADED", "Zmap")
    EVENT("PLAYER_LOGIN")
    EVENT("PLAYER_ENTERING_WORLD")
end

-- one frame: every visible frame's OnUpdate runs, timers come due
function FRAME(dt)
    dt = dt or 0.05
    STATE.layoutPending = false
    ADVANCE(dt)
    for _, w in ipairs(ALL_WIDGETS) do
        local fn = w.scripts.OnUpdate
        if fn and w:IsVisible() then fn(w, dt) end
    end
end

function FRAMES(n, dt) for _ = 1, n do FRAME(dt) end end

function OPEN()
    ZNS.Map.Open()
    FRAMES(3)
end

function VIEWPORT() return ZmapFrame.viewport end

-- the screen point over a map point (u, v)
function SCREEN_OF(u, v)
    local left, top = ZNS.Map.ViewRect()
    local k = ZNS.Map.K()
    local vl, vt = VIEWPORT():Rect()
    return vl + (u * ZNS.Geo.W - left) * k, vt - (v * ZNS.Geo.H - top) * k
end

function CURSOR_AT(u, v)
    STATE.cursor = { SCREEN_OF(u, v) }
    VIEWPORT().mouseOver = true
end

function CLICK_MAP(u, v, button)
    CURSOR_AT(u, v)
    local vp = VIEWPORT()
    if (button or "LeftButton") == "LeftButton" then vp.scripts.OnMouseDown(vp, "LeftButton") end
    vp.scripts.OnMouseUp(vp, button or "LeftButton")
end

function WHEEL(u, v, delta, frames)
    CURSOR_AT(u, v)
    VIEWPORT().scripts.OnMouseWheel(VIEWPORT(), delta)
    FRAMES(frames or 20)
end

function DRAG(fromU, fromV, toU, toV)
    CURSOR_AT(fromU, fromV)
    local vp = VIEWPORT()
    vp.scripts.OnMouseDown(vp, "LeftButton")
    local sx, sy = SCREEN_OF(fromU, fromV)
    local ex, ey = SCREEN_OF(toU, toV)
    for i = 1, 10 do
        STATE.cursor = { sx + (ex - sx) * i / 10, sy + (ey - sy) * i / 10 }
        FRAME()
    end
    vp.scripts.OnMouseUp(vp, "LeftButton")
    FRAMES(3)
end

function PROVIDER(name)
    for _, p in ipairs(ZNS.Pins.providers) do if p.name == name then return p end end
end

-- the pins a provider shows now
function PINS(name)
    local p = PROVIDER(name)
    local out = {}
    if p.frame and p.frame:IsVisible() then
        for _, pin in ipairs(p.active) do if pin.shown then out[#out + 1] = pin end end
    end
    return out
end

function HOVER(pin)
    pin.scripts.OnEnter(pin)
    local text = table.concat(STATE.tooltip, " / ")
    pin.scripts.OnLeave(pin)
    return text
end

function LAST_PRINT() return STATE.printed[#STATE.printed] or "" end

-- the prompt dialog: type and accept
function ANSWER(text)
    local p = ZmapPrompt
    assert(p and p.shown, "no prompt open")
    p.edit.text = text
    p.edit.scripts.OnEnterPressed(p.edit)
end

-- everything the art layers draw, for tools/preview.py: one line per visible texture
local LAYERS = { BACKGROUND = 1, BORDER = 2, ARTWORK = 3, OVERLAY = 4 }
function DUMP_ART()
    local canvas = ZNS.Map.Canvas()
    local lines = {}
    local function Under(w)
        local f, alpha = w.parent, w.alpha
        while f and f ~= canvas do
            if not f.shown then return end
            alpha = alpha * f.alpha
            f = f.parent
        end
        return f == canvas and alpha
    end
    for _, w in ipairs(ALL_WIDGETS) do
        if w.kind == "Texture" and w.shown and w.file and w.file ~= "color" and w.points.TOPLEFT then
            local alpha = Under(w)
            if alpha and alpha > 0.01 then
                local p = w.points.TOPLEFT
                local tc = w.tc or { 0, 1, 0, 1 }
                local c = w.color or { 1, 1, 1, 1 }
                local m = w.masks and w.masks[1]
                local mask = "-"
                if m then
                    local mp = m.points.TOPLEFT
                    mask = ("%s;%f;%f;%f;%f"):format(m.file, mp.x, -mp.y, m.w, m.h)
                end
                lines[#lines + 1] = ("%s|%f|%f|%f|%f|%f|%f|%f|%f|%d|%d|%d|%f|%f|%f|%f|%f|%s|%d"):format(
                    tostring(w.file), p.x, -p.y, w.w, w.h, tc[1], tc[2], tc[3], tc[4], w.parent._level,
                    LAYERS[w.layer] or 3, w.sublevel or 0, alpha, c[1], c[2], c[3], w.desat or 0, mask, w.id)
            end
        end
    end
    local l, t, r, b = ZNS.Map.ViewRect()
    return ("view|%f|%f|%f|%f\n"):format(l, t, r, b) .. table.concat(lines, "\n")
end
