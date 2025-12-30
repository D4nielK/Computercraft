-- ================= CONFIG =================
local side = "back"              -- Bundled Cable Seite anpassen
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

-- Lampen-Konfiguration (dauerhaft)
local lamps = {
    {name="Indirekte", color=colors.orange, state=false},
    {name="Hauptlicht", color=colors.white, state=false}
}

-- Gearshift-Konfiguration (nur Impuls)
local gearshifts = {
    {name="Grau",  color=colors.gray},
    {name="Lila",  color=colors.purple},
    {name="Rot",   color=colors.red},
    {name="Blau",  color=colors.blue},
    {name="Gelb",  color=colors.yellow}
}

-- Button Layout
local btnSpacing = 1
local btnHeight = 5

-- ================= HELPERS =================
-- Puls für Gearshift
local function pulse(color, duration)
    local current = redstone.getBundledOutput(side) or 0
    redstone.setBundledOutput(side, colors.combine(current, color))
    sleep(duration)
    redstone.setBundledOutput(side, current)
end

-- Lampen-Output setzen
local function applyLamps()
    local out = 0
    for _,l in ipairs(lamps) do
        if l.state then
            out = colors.combine(out, l.color)
        end
    end
    redstone.setBundledOutput(side, out)
end

-- Button-Klick prüfen
local function inButton(btn, x, y)
    return x >= btn.x and x <= btn.x + btn.w - 1 and y >= btn.y and y <= btn.y + btn.h - 1
end

-- Center X
local function centerX(w, boxW)
    return math.floor((w - boxW) / 2) + 1
end

-- Button zeichnen
local function drawButton(x, y, w, h, label, active, pressed)
    local bg = active and colors.lime or colors.lightGray
    if pressed then bg = colors.green end

    mon.setBackgroundColor(bg)
    mon.setTextColor(colors.black)
    for r = 0, h - 1 do
        mon.setCursorPos(x, y + r)
        mon.write(string.rep(" ", w))
    end

    local tx = x + math.floor((w - #label)/2)
    local ty = y + math.floor(h/2)
    mon.setCursorPos(tx, ty)
    mon.write(label)
end

-- Clear Monitor
local function clear()
    mon.setBackgroundColor(colors.black)
    mon.clear()
end

-- ================= DRAW LAYOUT =================
local function drawAll()
    clear()
    local w,h = mon.getSize()
    local btnW = math.max(14, math.floor(w * 0.7))
    local x = centerX(w, btnW)
    local yTop = 2

    local positions = {}

    -- Lampen-Buttons
    for i,l in ipairs(lamps) do
        local y = yTop + (i-1)*(btnHeight + btnSpacing)
        drawButton(x, y, btnW, btnHeight, l.name, l.state, false)
        positions[l.name] = {x=x, y=y, w=btnW, h=btnHeight}
    end

    -- Gearshift-Buttons
    for i,g in ipairs(gearshifts) do
        local y = yTop + (#lamps + i-1)*(btnHeight + btnSpacing)
        drawButton(x, y, btnW, btnHeight, g.name, false, false)
        positions[g.name] = {x=x, y=y, w=btnW, h=btnHeight}
    end

    -- Zentralschalter
    local y = yTop + (#lamps + #gearshifts)*(btnHeight + btnSpacing)
    drawButton(x, y, btnW, btnHeight, "ALLE Gearshifts", false, false)
    positions["all"] = {x=x, y=y, w=btnW, h=btnHeight}

    return positions
end

-- Button Sound
local function playButtonSound(type)
    if not speaker then return end
    if type == "all" then
        speaker.playSound("minecraft:block.note_block.pling", 1, 1)
    else
        speaker.playSound("minecraft:block.note_block.harp", 1, 1)
    end
end

-- ================= MAIN LOOP =================
mon.setTextScale(0.5)
applyLamps() -- Lampen initialisieren

while true do
    local buttons = drawAll()
    local e, sideClick, x, y = os.pullEvent("monitor_touch")

    -- Lampen-Buttons
    for _,l in ipairs(lamps) do
        local btn = buttons[l.name]
        if inButton(btn, x, y) then
            drawButton(btn.x, btn.y, btn.w, btn.h, l.name, l.state, true)
            playButtonSound(l.name)
            sleep(0.1)
            l.state = not l.state
            applyLamps()
        end
    end

    -- Gearshift-Buttons (Impuls)
    for _,g in ipairs(gearshifts) do
        local btn = buttons[g.name]
        if inButton(btn, x, y) then
            drawButton(btn.x, btn.y, btn.w, btn.h, g.name, true, true)
            playButtonSound(g.name)
            pulse(g.color, 0.2)
        end
    end

    -- Zentralschalter (alle Gearshifts)
    local btnAll = buttons["all"]
    if inButton(btnAll, x, y) then
        drawButton(btnAll.x, btnAll.y, btnAll.w, btnAll.h, "ALLE Gearshifts", true, true)
        playButtonSound("all")
        for _,g in ipairs(gearshifts) do
            pulse(g.color, 0.2)
        end
    end
end
