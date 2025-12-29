-- === Einstellungen ===
local monitorSide   = "right"
local redstoneSide  = "back"

local ORANGE = colors.orange
local WHITE  = colors.white

-- === Setup ===
local mon = peripheral.wrap(monitorSide)
mon.setTextScale(1)
mon.setBackgroundColor(colors.black)
mon.setTextColor(colors.white)
mon.clear()

local state = {
  orange = false,
  white  = false,
}

-- --- Hilfen --- --

local function buildBundled()
  local v = 0
  if state.orange then v = bit.bor(v, ORANGE) end
  if state.white  then v = bit.bor(v, WHITE)  end
  return v
end

local function updateOutput()
  redstone.setBundledOutput(redstoneSide, buildBundled())
end

-- Zeichnet einen Button (Rechteck)
local function drawButton(x, y, w, label, bg, fg)
  mon.setBackgroundColor(bg)
  mon.setTextColor(fg)

  for i = 0, 2 do
    mon.setCursorPos(x, y + i)
    mon.write(string.rep(" ", w))
  end

  -- Text in die Mitte setzen
  local tx = x + math.floor((w - #label) / 2)
  mon.setCursorPos(tx, y + 1)
  mon.write(label)

  mon.setBackgroundColor(colors.black)
end

-- ---- Anzeige ---- --

local function draw()
  mon.clear()

  mon.setCursorPos(2, 1)
  mon.setTextColor(colors.cyan)
  mon.write("Beleuchtungssteuerung")

  -- Indirekte Beleuchtung (Orange)
  if state.orange then
    drawButton(2, 3, 22, "Indirekte Beleuchtung: AN", colors.green, colors.black)
  else
    drawButton(2, 3, 22, "Indirekte Beleuchtung: AUS", colors.red, colors.white)
  end

  -- Hauptlicht (Weiss)
  if state.white then
    drawButton(2, 7, 22, "Hauptlicht: AN", colors.green, colors.black)
  else
    drawButton(2, 7, 22, "Hauptlicht: AUS", colors.red, colors.white)
  end

  -- Zentralbutton
  local allOn = state.orange and state.white

  if allOn then
    drawButton(2, 11, 22, "ALLE AUS", colors.blue, colors.white)
  else
    drawButton(2, 11, 22, "ALLE AN", colors.blue, colors.white)
  end
end

local function setAll(v)
  state.orange = v
  state.white  = v
  updateOutput()
  draw()
end

draw()
updateOutput()

-- --- Touch-Loop --- --
while true do
  local e, side, x, y = os.pullEvent("monitor_touch")

  -- Button-Bereiche prüfen
  -- Indirekte Beleuchtung (2..23 Breite, 3..5 Höhe)
  if x >= 2 and x <= 23 and y >= 3 and y <= 5 then
    state.orange = not state.orange
    updateOutput()
    draw()
  end

  -- Hauptlicht (2..23, 7..9)
  if x >= 2 and x <= 23 and y >= 7 and y <= 9 then
    state.white = not state.white
    updateOutput()
    draw()
  end

  -- Zentral (2..23, 11..13)
  if x >= 2 and x <= 23 and y >= 11 and y <= 13 then
    local allOn = state.orange and state.white
    setAll(not allOn)
  end
end
