-- ================== KONFIGURATION ==================
local mon = peripheral.find("monitor") or peripheral.wrap("top")
local speaker = peripheral.find("speaker")
local side = "back"
local sideGear = "back"

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
local function applyLightSignals()
    local out = 0
    if lightState.orange then out = bit.bor(out, ORANGE) end
    if lightState.white  then out = bit.bor(out, WHITE)  end
    redstone.setBundledOutput(side, out)
end

local function applyGearSignals()
    local out = 0
    for i,g in ipairs(gears) do
        if gearState[i] then
            out = colors.combine(out, g.color)
        end
    end
    redstone.setBundledOutput(sideGear, out)
end

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

-- ================== UI ==================
local function drawUI()
    clear()
    local w,h = mon.getSize()
    local spacingX, spacingY = 1, 0
    local btnW = math.floor((w - spacingX*3)/2)
    local btnH = 3
    local top = 2

    local buttons = {lights={}, gears={}, masterGear=nil}

    -- Licht Buttons nebeneinander
    drawButton(spacingX, top, btnW, btnH, "Indirekte Beleuchtung", lightState.orange, false)
    buttons.lights.orange = {x=spacingX, y=top, w=btnW, h=btnH}
    drawButton(spacingX*2 + btnW, top, btnW, btnH, "Hauptlicht", lightState.white, false)
    buttons.lights.white = {x=spacingX*2 + btnW, y=top, w=btnW, h=btnH}

    -- Alles EIN/AUS Button unter Licht
    local yNext = top + btnH + spacingY
    drawButton(spacingX, yNext, btnW*2 + spacingX, btnH, (lightState.orange or lightState.white) and "Alles Licht EIN/AUS" or "Alles Licht AUS", (lightState.orange or lightState.white), false)
    buttons.lights.all = {x=spacingX, y=yNext, w=btnW*2 + spacingX, h=btnH}

    -- Gearshift Buttons nebeneinander
    local yGear = yNext + btnH + spacingY
    for i,g in ipairs(gears) do
        local col = (i-1)%2
        local row = math.floor((i-1)/2)
        local xPos = spacingX + col*(btnW + spacingX)
        local yPos = yGear + row*(btnH + spacingY)
        local label = g.name .. (gearState[i] and " [RUNTER]" or " [HOCH  ]")
        drawButton(xPos, yPos, btnW, btnH, label, gearState[i], false)
        buttons.gears[i] = {x=xPos, y=yPos, w=btnW, h=btnH}
    end

    -- Zentraler Gearshift Button unter allen Gearshift Buttons
    local rows = math.ceil(#gears/2)
    local yMaster = yGear + rows*(btnH + spacingY)
    drawButton(spacingX, yMaster, btnW*2 + spacingX, btnH, masterGearState and "ZENTRAL: ALLE HOCH" or "ZENTRAL: ALLE RUNTER", masterGearState, false)
    buttons.masterGear = {x=spacingX, y=yMaster, w=btnW*2 + spacingX, h=btnH}

    return buttons
end

local function inButton(btn, cx, cy)
    return cx >= btn.x and cx <= btn.x+btn.w-1 and cy >= btn.y and cy <= btn.y+btn.h-1
end

local function playButtonSound(type)
    if not speaker then return end
    if type=="orange" then speaker.playSound("minecraft:block.note_block.harp",1,1)
    elseif type=="white" then speaker.playSound("minecraft:block.note_block.bell",1,1)
    elseif type=="all" then speaker.playSound("minecraft:block.note_block.pling",1,1) end
end

-- ================== HAUPTSCHLEIFE ==================
mon.setTextScale(0.5)
applyLightSignals()
applyGearSignals()

while true do
    local buttons = drawUI()
    local e,s,x,y = os.pullEvent("monitor_touch")

    -- Licht Buttons
    if inButton(buttons.lights.orange,x,y) then
        lightState.orange = not lightState.orange
        drawUI()
        applyLightSignals()
        playButtonSound("orange")
    elseif inButton(buttons.lights.white,x,y) then
        lightState.white = not lightState.white
        drawUI()
        applyLightSignals()
        playButtonSound("white")
    elseif inButton(buttons.lights.all,x,y) then
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
