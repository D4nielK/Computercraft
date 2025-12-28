---@diagnostic disable: undefined-global

-- =========================================================
-- CONFIG (HIER ANPASSEN!)
-- =========================================================
local CFG = {
  LEFT_MONITOR  = "left",  -- ← HIER linker Monitor
  RIGHT_MONITOR = "right",  -- ← HIER rechter Monitor

  TEXT_SCALE_LEFT  = 1.0,
  TEXT_SCALE_RIGHT = 1.0,

  REFRESH = 0.5,

  REACTOR = "fissionReactorLogicAdapter_0",

  -- Manuelle Reactor-Map (x = Fuel, o = Water)
  manualMap = {
    ["2:2"]="x", ["4:2"]="x", ["3:3"]="x", ["2:4"]="x", ["4:4"]="x",
    ["3:2"]="o", ["2:3"]="o", ["4:3"]="o", ["3:4"]="o",
  },
}

-- =========================================================
-- PERIPHERALS
-- =========================================================
local monL = assert(peripheral.wrap(CFG.LEFT_MONITOR),  "Left monitor not found")
local monR = assert(peripheral.wrap(CFG.RIGHT_MONITOR), "Right monitor not found")
local r    = assert(peripheral.wrap(CFG.REACTOR), "Reactor not found")

monL.setTextScale(CFG.TEXT_SCALE_LEFT)
monR.setTextScale(CFG.TEXT_SCALE_RIGHT)

-- =========================================================
-- UI HELPERS (GLOBAL, STABIL)
-- =========================================================
function clear(m)
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()
  m.setCursorPos(1,1)
end

function write(m,x,y,t)
  m.setCursorPos(x,y)
  m.write(t)
end

function fill(m, x,y,w,h, bgc)
  m.setBackgroundColor(bgc)
  for yy=y, y+h-1 do
    m.setCursorPos(x,yy)
    m.write(string.rep(" ", w))
  end
end

function panel(m, x,y,w,h, title)
  fill(m, x,y,w,h, colors.white)
  m.setBackgroundColor(colors.white)
  m.setTextColor(colors.black)
  if title then
    m.setCursorPos(x+2, y+1)
    m.write(title)
  end
end

local function pct(v)
  if type(v)~="number" then return "?" end
  if v<=1.001 then v=v*100 end
  return string.format("%3.0f%%", v)
end

-- =========================================================
-- LEFT MONITOR LAYOUT
-- =========================================================
local function leftLayout()
  local W,H = monL.getSize()

  -- links: Layout + Levels links, Stats rechts (wie früher)
  local lxW = math.floor(W * 0.45)
  local rxW = W - lxW - 3

  return {
    W=W, H=H,
    -- linke Spalte
    A = {x=2,       y=4,  w=lxW, h=16},   -- Reactor Layout
    D = {x=2,       y=21, w=lxW, h=18},   -- Levels
    -- rechte Spalte
    B = {x=2+lxW+2, y=4,  w=rxW, h=H-7},  -- Stats groß
  }
end

local LL = leftLayout()

-- =========================================================
-- LEFT: STATIC DRAW
-- =========================================================
local function drawLeftStatic()
  clear(monL)
  local W,H = LL.W, LL.H

  -- Titel
  write(monL, math.floor(W/2)-6, 1, "REACTOR UI")
  write(monL, math.floor(W/2)-6, 2, "==========")

  panel(monL, LL.A.x, LL.A.y, LL.A.w, LL.A.h, "Reactor Layout")
  panel(monL, LL.D.x, LL.D.y, LL.D.w, LL.D.h, "Reactor Levels")
  panel(monL, LL.B.x, LL.B.y, LL.B.w, LL.B.h, "Reactor Stats")

  -- Stats-Labels (statisch)
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.B.x + 2
  local y = LL.B.y + 3
  write(monL, x, y,     "Status:")
  write(monL, x, y+2,   "Temp:")
  write(monL, x, y+3,   "Burn:")
  write(monL, x, y+4,   "Damage:")

  write(monL, x, y+6,   "Coolant:")
  write(monL, x, y+7,   "Fuel:")
  write(monL, x, y+8,   "Heated:")
  write(monL, x, y+9,   "Waste:")
end

-- =========================================================
-- LEFT: REACTOR LAYOUT (einmal, kein Flackern)
-- =========================================================
local function drawCell(x,y,mark)
  monL.setBackgroundColor(colors.white)

  monL.setTextColor(colors.black); write(monL,x,y,"[")
  if mark=="x" then
    monL.setTextColor(colors.green); write(monL,x+1,y,"x")
  elseif mark=="o" then
    monL.setTextColor(colors.blue); write(monL,x+1,y,"o")
  else
    monL.setTextColor(colors.black); write(monL,x+1,y," ")
  end
  monL.setTextColor(colors.black); write(monL,x+2,y,"]")
end

local function drawReactorLayoutOnce()
  -- Innenbereich leeren
  fill(monL, LL.A.x+1, LL.A.y+2, LL.A.w-2, LL.A.h-3, colors.white)
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x0 = LL.A.x + 2
  local y0 = LL.A.y + 3

  local formed = (r.isFormed and r.isFormed()) or false
  write(monL, x0, y0, "Formed: "..tostring(formed))
  if not formed then
    write(monL, x0, y0+1, "Not formed!")
    return
  end

  local rw, rl, rh = r.getWidth(), r.getLength(), r.getHeight()
  write(monL, x0, y0+1, ("Size: %dx%dx%d"):format(rw, rl, rh))
  write(monL, x0, y0+2, "x=Fuel")
  write(monL, x0, y0+3, "o=Water")

  local gx = LL.A.x + 2
  local gy = LL.A.y + 6

  local cellW = 3
  local gw = LL.A.w - 4
  local gh = LL.A.h - 8

  local maxCols = math.max(1, math.floor(gw / cellW))
  local maxRows = math.max(1, gh)

  local stepX = math.max(1, math.ceil(rw / maxCols))
  local stepY = math.max(1, math.ceil(rl / maxRows))

  local cols = math.min(maxCols, math.ceil(rw / stepX))
  local rows = math.min(maxRows, math.ceil(rl / stepY))

  for sy=0, rows-1 do
    for sx=0, cols-1 do
      local rx = 1 + sx*stepX
      local rz = 1 + sy*stepY
      local key = rx..":"..rz
      drawCell(gx + sx*cellW, gy + sy, CFG.manualMap[key])
    end
  end
end

-- =========================================================
-- LEFT: LEVELS (live, ohne Panel neu)
-- =========================================================
local function drawBar(x,y,w,h, frac, col, label)
  -- Container
  monL.setBackgroundColor(colors.lightGray)
  monL.setTextColor(colors.black)
  for yy=0,h-1 do
    write(monL, x, y+yy, string.rep(" ", w))
  end

  local fillH = math.floor(frac*h + 0.5)
  if fillH > h then fillH = h end

  monL.setBackgroundColor(col)
  for yy=0, fillH-1 do
    write(monL, x, y+(h-1-yy), string.rep(" ", w))
  end

  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)
  write(monL, x, y-1, label)
end

local function to01(v)
  if type(v)~="number" then return 0 end
  if v > 1.001 then v = v/100 end
  if v < 0 then v=0 end
  if v > 1 then v=1 end
  return v
end

local function drawLevelsLive()
  -- wir löschen NICHT das ganze Panel, nur malen Balken neu
  local x0 = LL.D.x + 2
  local y0 = LL.D.y + 4
  local barH = LL.D.h - 7
  local barW, gap = 2, 2

  local c = to01(r.getCoolantFilledPercentage())
  local f = to01(r.getFuelFilledPercentage())
  local h = to01(r.getHeatedCoolantFilledPercentage())
  local w = to01(r.getWasteFilledPercentage())

  drawBar(x0 + 0*(barW+gap), y0, barW, barH, c, colors.blue, "C")
  drawBar(x0 + 1*(barW+gap), y0, barW, barH, f, colors.green, "F")
  drawBar(x0 + 2*(barW+gap), y0, barW, barH, h, colors.gray, "H")
  drawBar(x0 + 3*(barW+gap), y0, barW, barH, w, colors.lime, "W")

  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)
  write(monL, LL.D.x+1, LL.D.y + LL.D.h - 2,
    ("C%3d F%3d H%3d W%3d"):format(
      math.floor(c*100+0.5), math.floor(f*100+0.5),
      math.floor(h*100+0.5), math.floor(w*100+0.5)
    )
  )
end

-- =========================================================
-- LEFT: STATS (live)
-- =========================================================
local function drawStatsLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.B.x + 2
  local y = LL.B.y + 3

  -- Werte schreiben (rechte Spalte in diesem Panel)
  write(monL, x+10, y,     (r.getStatus() and "ON " or "OFF"))
  write(monL, x+10, y+2,   string.format("%4.0f K", r.getTemperature()))
  write(monL, x+10, y+3,   string.format("%4.1f mB/t", r.getBurnRate()))
  write(monL, x+10, y+4,   pct(r.getDamagePercent()))

  write(monL, x+10, y+6,   pct(r.getCoolantFilledPercentage()))
  write(monL, x+10, y+7,   pct(r.getFuelFilledPercentage()))
  write(monL, x+10, y+8,   pct(r.getHeatedCoolantFilledPercentage()))
  write(monL, x+10, y+9,   pct(r.getWasteFilledPercentage()))
end

-- =========================================================
-- RIGHT MONITOR: CONTROLS (wie vorher)
-- =========================================================
local buttons = {}

local function drawButton(id, x,y,w,h, label, bgc)
  monR.setBackgroundColor(bgc)
  monR.setTextColor(colors.black)
  for yy=y,y+h-1 do
    monR.setCursorPos(x,yy)
    monR.write(string.rep(" ", w))
  end
  monR.setCursorPos(x + math.floor((w-#label)/2), y + math.floor(h/2))
  monR.write(label)
  buttons[#buttons+1] = {id=id, x=x,y=y,w=w,h=h}
end

local function drawRightStatic()
  clear(monR)
  local W,H = monR.getSize()

  write(monR, math.floor(W/2)-6, 1, "CONTROLS")
  write(monR, math.floor(W/2)-6, 2, "==========")

  panel(monR, 2,4, W-2, H-5, "Actions")

  buttons = {}
  local x = 4
  local w = W-8
  local y = 7
  local h = 4
  local g = 2

  drawButton("start", x,y,         w,h, "START", colors.green)
  drawButton("stop",  x,y+h+g,     w,h, "STOP",  colors.red)
  drawButton("scram", x,y+2*(h+g), w,h, "AZ-5",  colors.orange)
end

local function hit(x,y)
  for _,b in ipairs(buttons) do
    if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
      return b.id
    end
  end
end

local function action(id)
  if id=="start" then
    if r.activate then r.activate() end
  elseif id=="stop" then
    if r.deactivate then r.deactivate() end
  elseif id=="scram" then
    if r.scram then r.scram() end
  end
end

-- =========================================================
-- BOOT
-- =========================================================
drawLeftStatic()
drawRightStatic()
drawReactorLayoutOnce() -- Layout einmal (kein Flackern)

while true do
  drawLevelsLive()
  drawStatsLive()

  local e,side,x,y = os.pullEventTimeout("monitor_touch", CFG.REFRESH)
  if e=="monitor_touch" and side==CFG.RIGHT_MONITOR then
    local id = hit(x,y)
    if id then action(id) end
  end
end