-- Konfiguration
local side = "back"           -- Bundled Cable Seite
local mon = peripheral.wrap("top")
mon.setTextScale(1.5)

-- Gearshift-Liste: Name und Farbe
local gears = {
    {name="GS Grau", color=colors.gray},
    {name="GS Lila", color=colors.purple},
    {name="GS Rot", color=colors.red},
    {name="GS Blau", color=colors.blue},
    {name="GS Gelb", color=colors.yellow},
}

-- Zustand jeder Gearshift
local states = {}
for i=1,#gears do states[i] = false end

-- Zentralschalter: false = alle hoch, true = alle runter
local masterState = false

-- Zeichnet das Monitor-Interface
local function draw()
    mon.clear()
    mon.setCursorPos(1,1)
    mon.write("Sequenced Gearshifts")

    for i,g in ipairs(gears) do
        local y = 2 + i
        mon.setCursorPos(1,y)
        mon.write(g.name .. ": ")
        if states[i] then
            mon.write("[RUNTER]")
        else
            mon.write("[HOCH  ]")
        end
    end

    -- Zentralschalter
    mon.setCursorPos(1, 8)
    if masterState then
        mon.write("ZENTRAL: [ALLE HOCH]")
    else
        mon.write("ZENTRAL: [ALLE RUNTER]")
    end
end

-- Setzt das Bundled Cable aus allen Gearshift-Zuständen
local function updateOutputs()
    local out = 0
    for i,g in ipairs(gears) do
        if states[i] then
            out = colors.combine(out, g.color)
        end
    end
    redstone.setBundledOutput(side, out)
end

-- Initial
draw()
updateOutputs()

-- Event-Schleife
while true do
    local event, sideEvent, x, y = os.pullEvent("monitor_touch")

    -- einzelne Gearshifts
    for i,g in ipairs(gears) do
        local row = 2 + i
        if y == row then
            states[i] = not states[i]
            draw()
            updateOutputs()
        end
    end

    -- Zentralschalter (Row 8)
    if y == 8 then
        masterState = not masterState
        for i=1,#states do
            states[i] = masterState
        end
        draw()
        updateOutputs()
    end
end
