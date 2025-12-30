-- ================== KONFIGURATION ==================
local mon = peripheral.find("monitor") or peripheral.wrap("top")
local speaker = peripheral.find("speaker") -- Optional für Sounds
local side = "back" -- Bundled Cable Seite für Lichter
local sideGear = "back" -- Bundled Cable Seite für Gearshifts

-- Farben für Licht
local ORANGE = colors.orange
local WHITE  = colors.white

-- Gearshift-Liste
local gears = {
    {name="GS Grau", color=colors.gray},
    {name="GS Lila", color=colors.purple},
    {name="GS Rot", color=colors.red},
    {name="GS Blau", color=colors.blue},
    {name="GS Gelb", color=colors.yellow},
}

-- ================== ZUSTÄNDE ==================
local lightState = { orange=false, white=false }
local gearState = {}
for i=1,#gears do gearState[i] = false end
local masterGearState = false

-- ================== FUNKTIONEN ==================

-- Zentralisierte Lichtausgabe
local function applyLightSignals()
    local out = 0
    if lightState.orange then out = bit.bor(out, ORANGE) end
    if lightState.white  then out = bit.bor(out, WHITE)  end
    redstone.setBundledOutput(side, out)
end

-- Zentralisierte Gearshift-Ausgabe
local function applyGearSignals()
    local out = 0
    for i,g in ipairs(gears) do
        if gearState[i] then
            out = colors.combine(out, g.color)
        end
    end
    redstone.setBundledOutput(sideGear, out)
end

-- UI Hilfsfunktionen
local function centerX(w, boxW) return math.floor((w - boxW)/2)+1 end
local function drawButton(x, y, w, h, label, active, pressed)
    local bg = active and colors.lime or colors.lightGray
    if pressed then bg = colors.green end
    mon.setBackgroundColor(bg)
    mon.setTextColor(colors.black)
    for r=0,h-1 do
        mon.setCursorPos(x, y+r)
        mon.write(string.rep(" ", w))
    end
    local tx = x + math.floor((w - #label)/2)
    local ty = y + math.floor(h/2)
    mon.setCursorPos(tx, ty)
    mon.write(label)
end
local function clear() mon.setBackgroundColor(colors.black) mon.clear() end

-- UI Zeichnen
local function drawUI()
    clear()
    local w,h = mon.getSize()
    local btnW, btnH = math.max(14, math.floor(w*0.7)), 5
    local spacing, top = 2, 2
    local x = centerX(w, btnW)

    -- Licht Buttons
    drawButton(x, top, btnW, btnH, "Indirekte Beleuchtung", lightState.orange, false)
    drawButton(x, top + btnH + spacing, btnW, btnH, "Hauptlicht", lightState.white, false)
    drawButton(x, top + 2*(btnH+spacing), btnW, btnH, "Alles Licht EIN/AUS", (lightState.orange or lightState.white), false)

    -- Gearshift Buttons
    local gearTop = top + 3*(btnH+spacing) + 1
    for i,g in ipairs(gears) do
        local label = g.name .. (gearState[i] and " [RUNTER]" or " [HOCH  ]")
        drawButton(x, gearTop + (i-1)*(btnH+spacing), btnW, btnH, label, gearState[i], false)
    end
    -- Zentraler Gearshift Button
    drawButton(x, gearTop + #gears*(btnH+spacing), btnW, btnH, masterGearState and "ZENTRAL: ALLE HOCH" or "ZENTRAL: ALLE RUNTER", masterGearState, false)

    -- Return Button-Positionen für Klickprüfung
    local buttons = {
        orange = {x=x, y=top, w=btnW, h=btnH},
        white  = {x=x, y=top+btnH+spacing, w=btnW, h=btnH},
        allLight = {x=x, y=top+2*(btnH+spacing), w=btnW, h=btnH},
        gears = {},
        masterGear = {x=x, y=gearTop + #gears*(btnH+spacing), w=btnW, h=btnH}
    }
    for i=1,#gears do
        buttons.gears[i] = {x=x, y=gearTop + (i-1)*(btnH+spacing), w=btnW, h=btnH}
    end
    return buttons
end

-- Prüft Klick auf Button
local function inButton(btn, cx, cy)
    return cx >= btn.x and cx <= btn.x+btn.w-1 and cy >= btn.y and cy <= btn.y+btn.h-1
end

-- Soundeffekte
local function playButtonSound(type)
    if not speaker then return end
    if type == "orange" then speaker.playSound("minecraft:block.note_block.harp",1,1)
    elseif type=="white" then speaker.playSound("minecraft:block.note_block.bell",1,1)
    elseif type=="all" then speaker.playSound("minecraft:block.note_block.pling",1,1) end
end

-- ================== HAUPTSCHLEIFE ==================
mon.setTextScale(0.5)
applyLightSignals()
applyGearSignals()

while true do
    local buttons = drawUI()
    local e, s, x, y = os.pullEvent("monitor_touch")

    -- Licht Buttons
    if inButton(buttons.orange,x,y) then
        lightState.orange = not lightState.orange
        drawUI()
        applyLightSignals()
        playButtonSound("orange")
    elseif inButton(buttons.white,x,y) then
        lightState.white = not lightState.white
        drawUI()
        applyLightSignals()
        playButtonSound("white")
    elseif inButton(buttons.allLight,x,y) then
        local new = not (lightState.orange or lightState.white)
        lightState.orange, lightState.white = new,new
        drawUI()
        applyLightSignals()
        playButtonSound("all")
    end

    -- Gearshift Buttons
    for i,b in ipairs(buttons.gears) do
        if inButton(b,x,y) then
            gearState[i] = not gearState[i]
            drawUI()
            applyGearSignals()
            break
        end
    end

    -- Zentraler Gearshift Button
    if inButton(buttons.masterGear,x,y) then
        masterGearState = not masterGearState
        for i=1,#gearState do gearState[i] = masterGearState end
        drawUI()
        applyGearSignals()
    end
end
