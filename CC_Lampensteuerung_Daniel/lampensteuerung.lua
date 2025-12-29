-- === Einstellungen ===
local mon = peripheral.find("monitor")
local side = "back" -- Seite mit dem bundled cable anpassen!

local ORANGE = colors.orange
local WHITE  = colors.white

local state = {
    orange = false,
    white  = false
}

local function applySignals()
    local out = 0
    if state.orange then out = bit.bor(out, ORANGE) end
    if state.white  then out = bit.bor(out, WHITE)  end
    redstone.setBundledOutput(side, out)
end

-- ======= UI HELPERS =======
local function centerX(w, boxW)
    return math.floor((w - boxW) / 2) + 1
end

local function drawButton(x, y, w, h, label, active, pressed)
    -- Schatten
    mon.setBackgroundColor(colors.gray)
    for i = 0, 1 do
        mon.setCursorPos(x + i, y + h)
        mon.write(string.rep(" ", w))
    end
    for r = 0, 1 do
        mon.setCursorPos(x + w, y + r)
        mon.write(" ")
    end

    -- Button-Hintergrund
    local bg = active and colors.lime or colors.lightGray
    if pressed then bg = colors.green end

    mon.setBackgroundColor(bg)
    mon.setTextColor(colors.black)
    for r = 0, h - 1 do
        mon.setCursorPos(x, y + r)
        mon.write(string.rep(" ", w))
    end

    -- Label mittig
    local tx = x + math.floor((w - #label) / 2)
    local ty = y + math.floor(h / 2)
    mon.setCursorPos(tx, ty)
    mon.write(label)
end

local function drawLabel(text, y, w)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.black)
    local tx = centerX(mon.getSize(), w) + math.floor((w - #text)/2)
    mon.setCursorPos(tx, y)
    mon.write(text)
    mon.setBackgroundColor(colors.black)
end

local function clear()
    mon.setBackgroundColor(colors.black)
    mon.clear()
end

-- ======= LAYOUT =======
local function drawAll()
    clear()
    local w, h = mon.getSize()

    -- Dynamische Button-Größe
    local btnW = math.max(14, math.floor(w * 0.7))
    local btnH = 5
    local spacing = 1
    local top = 2
    local x = centerX(w, btnW)

    -- Labels
    drawLabel("Indirekte Beleuchtung", top, btnW)
    drawLabel("Hauptlicht", top + btnH + spacing + 2, btnW)
    drawLabel("Zentrale Steuerung", top + (btnH + spacing)*2 + 4, btnW)

    -- Einzel-Buttons (kleinere SchriftScale)
    mon.setTextScale(0.5)
    drawButton(x, top + 1, btnW, btnH, state.orange and "AN" or "AUS", state.orange, false)
    drawButton(x, top + btnH + spacing + 3, btnW, btnH, state.white and "AN" or "AUS", state.white, false)

    -- Zentral-Button (größere SchriftScale)
    mon.setTextScale(1)
    local allOn = state.orange and state.white
    drawButton(x, top + (btnH + spacing)*2 + 5, btnW, btnH, allOn and "ALLE AUS" or "ALLE AN", (state.orange or state.white), false)

    return {
        orange = {x = x, y = top + 1, w = btnW, h = btnH},
        white  = {x = x, y = top + btnH + spacing + 3, w = btnW, h = btnH},
        all    = {x = x, y = top + (btnH + spacing)*2 + 5, w = btnW, h = btnH}
    }
end

-- ======= Press Animation =======
local function pressAnimation(btn, label, active)
    drawButton(btn.x, btn.y, btn.w, btn.h, label, active, true)
    sleep(0.12)
end

-- ======= MAIN LOOP =======
applySignals()
while true do
    local buttons = drawAll()
    local e, sideClick, x, y = os.pullEvent("monitor_touch")

    -- Indirekte Beleuchtung
    if x >= buttons.orange.x and x <= buttons.orange.x + buttons.orange.w -1
       and y >= buttons.orange.y and y <= buttons.orange.y + buttons.orange.h -1 then
        pressAnimation(buttons.orange, state.orange and "AN" or "AUS", state.orange)
        state.orange = not state.orange

    -- Hauptlicht
    elseif x >= buttons.white.x and x <= buttons.white.x + buttons.white.w -1
       and y >= buttons.white.y and y <= buttons.white.y + buttons.white.h -1 then
        pressAnimation(buttons.white, state.white and "AN" or "AUS", state.white)
        state.white = not state.white

    -- Zentral
    elseif x >= buttons.all.x and x <= buttons.all.x + buttons.all.w -1
       and y >= buttons.all.y and y <= buttons.all.y + buttons.all.h -1 then
        pressAnimation(buttons.all, (state.orange or state.white) and "ALLE AUS" or "ALLE AN", (state.orange or state.white))
        local new = not (state.orange or state.white)
        state.orange = new
        state.white = new
    end

    applySignals()
end
