-- === Einstellungen ===
local mon = peripheral.find("monitor")
local side = "back" -- Bundled-Kabelseite anpassen

local ORANGE = colors.orange
local WHITE  = colors.white

local state = {
    orange = false,
    white  = false
}

-- === Signal senden ===
local function applySignals()
    local out = 0
    if state.orange then out = bit.bor(out, ORANGE) end
    if state.white  then out = bit.bor(out, WHITE) end
    redstone.setBundledOutput(side, out)
end

-- === Monitor helpers ===
local function clear()
    mon.setBackgroundColor(colors.black)
    mon.clear()
end

local function drawButton(x, y, w, h, label, bg, textColor, pressed)
    -- Simulierter 3D Effekt
    if pressed then
        mon.setBackgroundColor(colors.gray)
    else
        mon.setBackgroundColor(bg)
    end

    for i = 0, h-1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", w))
    end

    -- Label zentriert
    local tx = x + math.floor((w - #label)/2)
    local ty = y + math.floor(h/2)
    mon.setTextColor(textColor)
    mon.setCursorPos(tx, ty)
    mon.write(label)
end

local function drawLabel(x, y, w, text)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.black)
    local tx = x + math.floor((w - #text)/2)
    mon.setCursorPos(tx, y)
    mon.write(text)
end

-- === Layout berechnen ===
local function drawAll()
    clear()
    local w, h = mon.getSize()
    local btnW = math.max(14, math.floor(w*0.7))
    local btnH = 3
    local spacing = 1
    local top = 2
    local x = math.floor((w - btnW)/2) +1

    -- Labels
    drawLabel(x, top, btnW, "Indirekte Beleuchtung")
    drawLabel(x, top + btnH + spacing + 1, btnW, "Hauptlicht")
    drawLabel(x, top + (btnH+spacing)*2 +2, btnW, "Zentrale Steuerung")

    -- Buttons
    drawButton(x, top +1, btnW, btnH, state.orange and "AN" or "AUS", state.orange and colors.lime or colors.red, state.orange and colors.black or colors.white, false)
    drawButton(x, top + btnH + spacing +2, btnW, btnH, state.white and "AN" or "AUS", state.white and colors.lime or colors.red, state.white and colors.black or colors.white, false)

    -- Zentral-Button etwas größer
    drawButton(x, top + (btnH+spacing)*2 +3, btnW, btnH+1, (state.orange or state.white) and "ALLE AUS" or "ALLE AN", colors.blue, colors.white, false)

    return {
        orange = {x=x, y=top+1, w=btnW, h=btnH},
        white  = {x=x, y=top+btnH+spacing+2, w=btnW, h=btnH},
        all    = {x=x, y=top+(btnH+spacing)*2 +3, w=btnW, h=btnH+1}
    }
end

-- === Pressanimation ===
local function press(btn, label, bg, fg)
    drawButton(btn.x, btn.y, btn.w, btn.h, label, bg, fg, true)
    sleep(0.12)
    drawAll()
end

-- === Main Loop ===
applySignals()
while true do
    local buttons = drawAll()
    local e, sideClick, x, y = os.pullEvent("monitor_touch")

    -- Indirekte Beleuchtung
    if x >= buttons.orange.x and x <= buttons.orange.x+buttons.orange.w-1
       and y >= buttons.orange.y and y <= buttons.orange.y+buttons.orange.h-1 then
        press(buttons.orange, state.orange and "AN" or "AUS", state.orange and colors.lime or colors.red, state.orange and colors.black or colors.white)
        state.orange = not state.orange

    -- Hauptlicht
    elseif x >= buttons.white.x and x <= buttons.white.x+buttons.white.w-1
       and y >= buttons.white.y and y <= buttons.white.y+buttons.white.h-1 then
        press(buttons.white, state.white and "AN" or "AUS", state.white and colors.lime or colors.red, state.white and colors.black or colors.white)
        state.white = not state.white

    -- Zentral-Button
    elseif x >= buttons.all.x and x <= buttons.all.x+buttons.all.w-1
       and y >= buttons.all.y and y <= buttons.all.y+buttons.all.h-1 then
        press(buttons.all, (state.orange or state.white) and "ALLE AUS" or "ALLE AN", colors.blue, colors.white)
        local new = not (state.orange or state.white)
        state.orange = new
        state.white = new
    end

    applySignals()
end
