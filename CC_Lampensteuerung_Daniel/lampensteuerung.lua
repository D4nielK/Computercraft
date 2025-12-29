local monitorSide   = "right"     -- Seite, an der dein Monitor hängt
local redstoneSide  = "back"      -- Seite, an der dein bundled cable hängt

-- Farben (ProjectRed/MoreRed: entsprechen den CC colors.*)
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

-- Hilfsfunktion: aktuellen Bundled-Wert berechnen
local function buildBundled()
  local v = 0
  if state.orange then v = bit.bor(v, ORANGE) end
  if state.white  then v = bit.bor(v, WHITE)  end
  return v
end

local function draw()
  mon.clear()

  mon.setCursorPos(2, 1)
  mon.setTextColor(colors.cyan)
  mon.write("Bundled Control")

  -- Orange
  mon.setCursorPos(2, 3)
  mon.setTextColor(colors.orange)
  mon.write("Orange: ")
  if state.orange then
    mon.setTextColor(colors.lime)
    mon.write("AN")
  else
    mon.setTextColor(colors.red)
    mon.write("AUS")
  end

  -- White
  mon.setCursorPos(2, 5)
  mon.setTextColor(colors.lightGray)
  mon.write("Weiss : ")
  if state.white then
    mon.setTextColor(colors.lime)
    mon.write("AN")
  else
    mon.setTextColor(colors.red)
    mon.write("AUS")
  end

  mon.setCursorPos(2, 7)
  mon.setTextColor(colors.gray)
  mon.write("Tippe auf einen Eintrag zum Umschalten")
end

local function updateOutput()
  local value = buildBundled()
  redstone.setBundledOutput(redstoneSide, value)
end

draw()
updateOutput()

-- === Touch-Loop ===
while true do
  local e, side, x, y = os.pullEvent("monitor_touch")

  -- Orange: Zeile 3
  if y == 3 then
    state.orange = not state.orange
    updateOutput()
    draw()
  end

  -- White: Zeile 5
  if y == 5 then
    state.white = not state.white
    updateOutput()
    draw()
  end
end
