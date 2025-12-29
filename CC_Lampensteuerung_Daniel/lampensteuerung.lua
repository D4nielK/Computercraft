-- === Einstellungen ===
local monitorSide   = "right"
local redstoneSide  = "back"

local ORANGE = colors.orange
local WHITE  = colors.white

-- === Setup ===
local mon = peripheral.wrap(monitorSide)
mon.setTextScale(1)
mon.setBackgroundColor(colors.black)
mon.clear()

local state = {
  orange = false,
  white  = false,
}

-- ---- Hilfsfunktionen ---- --

local function buildBundled()
  local v = 0
  if state.orange then v = bit.bor(v, ORANGE) end
  if state.white  then v = bit.bor(v, WHITE)  end
  return v
end

local function updateOutput()
  redstone.setBundledOutput(redstoneSide, buildBundled())
end


-- ===== Zeichnen ===== --

-- Label mit 3D-Effekt
local function drawLabel3D(x, y, w, text)
  mon.setBackgroundColor(colors.lightGray)
  mon.setCursorPos(x, y)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(colors.gray)
  mon.setCursorPos(x, y + 1)
  mon.write(string.rep(" ", w))

  local tx = x + math.floor((w - #text) / 2)
  mon.setTextColor(colors.black)
  mon.setCursorPos(tx, y + 1)
  mon.write(text)

  mon.setBackgroundColor(colors.gray)
  mon.setCursorPos(x, y + 2)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(colors.black)
end


-- Normaler 3D-Button
local function drawButton3D(x, y, w, text, faceColor, textColor)
  mon.setBackgroundColor(colors.white)
  mon.setCursorPos(x, y)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(faceColor)
  mon.setCursorPos(x, y + 1)
  mon.write(string.rep(" ", w))
  mon.setCursorPos(x, y + 2)
  mon.write(string.rep(" ", w))

  local tx = x + math.floor((w - #text) / 2)
  mon.setTextColor(textColor)
  mon.setCursorPos(tx, y + 1)
  mon.write(text)

  mon.setBackgroundColor(colors.gray)
  mon.setCursorPos(x, y + 3)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(colors.black)
end


-- „eingedrückter“ Button (invertierter Look)
local function drawButtonPressed(x, y, w, text, faceColor, textColor)
  mon.setBackgroundColor(colors.gray)
  mon.setCursorPos(x, y)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(colors.black)
  mon.setCursorPos(x, y + 1)
  mon.write(string.rep(" ", w))
  mon.setCursorPos(x, y + 2)
  mon.write(string.rep(" ", w))

  local tx = x + math.floor((w - #text) / 2)
  mon.setTextColor(textColor)
  mon.setCursorPos(tx, y + 1)
  mon.write(text)

  mon.setBackgroundColor(colors.lightGray)
  mon.setCursorPos(x, y + 3)
  mon.write(string.rep(" ", w))

  mon.setBackgroundColor(colors.black)
end


-- ===== Bildschirm neu zeichnen ===== --

local function draw()
  mon.clear()

  mon.setCursorPos(2, 1)
  mon.setTextColor(colors.cyan)
  mon.write("Beleuchtungssteuerung")

  -- Indirekte Beleuchtung
  drawLabel3D(2, 3, 26, "Indirekte Beleuchtung")

  if state.orange then
    drawButton3D(2, 7, 26, "AN", colors.green, colors.black)
  else
    drawButton3D(2, 7, 26, "AUS", colors.red, colors.white)
  end

  -- Hauptlicht
  drawLabel3D(2, 12, 26, "Hauptlicht")

  if state.white then
    drawButton3D(2, 16, 26, "AN", colors.green, colors.black)
  else
    drawButton3D(2, 16, 26, "AUS", colors.red, colors.white)
  end

  -- Zentral
  drawLabel3D(2, 21, 26, "Zentrale Steuerung")

  local allOn = state.orange and state.white
  if allOn then
    drawButton3D(2, 25, 26, "ALLE AUS", colors.blue, colors.white)
  else
    drawButton3D(2, 25, 26, "ALLE AN", colors.blue, colors.white)
  end
end


-- ===== Animation + Logik ===== --

local function pressAnimation(x, y, w, text, faceColor, textColor)
  drawButtonPressed(x, y, w, text, faceColor, textColor)
  sleep(0.12)
  draw()
end

local function setAll(v)
  state.orange = v
  state.white  = v
  updateOutput()
  draw()
end


draw()
updateOutput()


-- ===== Touch Loop ===== --

while true do
  local e, side, x, y = os.pullEvent("monitor_touch")

  -- Indirekte Beleuchtung
  if x >= 2 and x <= 28 and y >= 7 and y <= 10 then
    pressAnimation(2, 7, 26, state.orange and "AN" or "AUS",
      state.orange and colors.green or colors.red,
      state.orange and colors.black or colors.white)

    state.orange = not state.orange
    updateOutput()
    draw()
  end

  -- Hauptlicht
  if x >= 2 and x <= 28 and y >= 16 and y <= 19 then
    pressAnimation(2, 16, 26, state.white and "AN" or "AUS",
      state.white and colors.green or colors.red,
      state.white and colors.black or colors.white)

    state.white = not state.white
    updateOutput()
    draw()
  end

  -- Zentrale
  if x >= 2 and x <= 28 and y >= 25 and y <= 28 then
    local allOn = state.orange and state.white

    pressAnimation(2, 25, 26, allOn and "ALLE AUS" or "ALLE AN",
      colors.blue, colors.white)

    setAll(not allOn)
  end
end
