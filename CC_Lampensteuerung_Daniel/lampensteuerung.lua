-- Monitor + Bundled-Setup
local mon = peripheral.find("monitor")
local side = "back" -- Seite mit dem bundled cable anpassen!
local speaker = peripheral.find("speaker") -- Speaker für Sound

-- Farben (ProjectRed / Bundled)
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
    for i = 0, 1 do
      mon.setCursorPos(x + w, y + r)
      mon.write(" ")
    end
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
  local spacing = 2

  local top = 2
  local x = centerX(w, btnW)

  -- Einzel-Buttons
  drawButton(x, top, btnW, btnH, "Indirekte Beleuchtung", state.orange, false)
  drawButton(x, top + btnH + spacing, btnW, btnH, "Hauptlicht", state.white, false)

  -- Zentral-Button
  drawButton(
    x,
    top + (btnH + spacing) * 2,
    btnW,
    btnH,
    "Alles EIN/AUS",
    (state.orange or state.white),
    false
  )

  return {
    orange = {x = x, y = top, w = btnW, h = btnH},
    white  = {x = x, y = top + btnH + spacing, w = btnW, h = btnH},
    all    = {x = x, y = top + (btnH + spacing) * 2, w = btnW, h = btnH},
  }
end

-- Prüfen ob Klick in Button
local function inButton(btn, cx, cy)
  return cx >= btn.x and cx <= btn.x + btn.w - 1
     and cy >= btn.y and cy <= btn.y + btn.h - 1
end

-- Button-Sound abspielen
local function playButtonSound()
  if speaker then
    speaker.playSound("minecraft:block.note_block.harp", 1, 1) -- Lautstärke=1, Tonhöhe=1
  end
end

-- ======= MAIN LOOP =======
mon.setTextScale(0.5)
applySignals()

while true do
  local buttons = drawAll()
  local e, sideClick, x, y = os.pullEvent("monitor_touch")

  local pressed
  if inButton(buttons.orange, x, y) then
    pressed = buttons.orange
    drawButton(pressed.x, pressed.y, pressed.w, pressed.h,
      "Indirekte Beleuchtung", state.orange, true)
    playButtonSound()
    sleep(0.1)
    state.orange = not state.orange

  elseif inButton(buttons.white, x, y) then
    pressed = buttons.white
    drawButton(pressed.x, pressed.y, pressed.w, pressed.h,
      "Hauptlicht", state.white, true)
    playButtonSound()
    sleep(0.1)
    state.white = not state.white

  elseif inButton(buttons.all, x, y) then
    pressed = buttons.all
    drawButton(pressed.x, pressed.y, pressed.w, pressed.h,
      "Alles EIN/AUS", (state.orange or state.white), true)
    playButtonSound()
    sleep(0.1)
    local new = not (state.orange or state.white)
    state.orange = new
    state.white  = new
  end

  applySignals()
end
