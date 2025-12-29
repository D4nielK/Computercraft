---@diagnostic disable: undefined-global

-- =========================================================
-- CONFIG
-- =========================================================
local CFG = {
  LEFT_MONITOR  = "left",
  RIGHT_MONITOR = "right",

  TEXT_SCALE_LEFT  = 1.0,
  TEXT_SCALE_RIGHT = 1.0,

  REFRESH = 0.5,

  -- Reactor: lieber auto-find, damit Ab-/Aufbauen nicht alles kaputt macht
  -- Falls du unbedingt fest willst: setz hier den Namen und ersetze peripheral.find unten wieder mit wrap()
  REACTOR_TYPE = "fissionReactorLogicAdapter",

  -- Optional: wenn du Namen kennst, kannst du sie hier fest eintragen.
  TURBINE_NAME = nil,  -- z.B. "turbineValve_0"
  MATRIX_NAME  = nil,  -- z.B. "inductionPort_0"
}

-- =========================================================
-- PERIPHERALS
-- =========================================================
local monL = assert(peripheral.wrap(CFG.LEFT_MONITOR),  "Left monitor not found")
local monR = assert(peripheral.wrap(CFG.RIGHT_MONITOR), "Right monitor not found")

monL.setTextScale(CFG.TEXT_SCALE_LEFT)
monR.setTextScale(CFG.TEXT_SCALE_RIGHT)

local r = peripheral.find(CFG.REACTOR_TYPE)
assert(r, "Reactor not found (no "..CFG.REACTOR_TYPE.." peripheral)")

local t = (CFG.TURBINE_NAME and peripheral.wrap(CFG.TURBINE_NAME)) or peripheral.find("turbineValve")
-- t kann nil sein -> dann zeigen wir N/A

local mtx = (CFG.MATRIX_NAME and peripheral.wrap(CFG.MATRIX_NAME)) or peripheral.find("inductionPort")
-- mtx kann nil sein -> dann zeigen wir N/A

-- =========================================================
-- UI HELPERS
-- =========================================================
local function clear(m)
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()
  m.setCursorPos(1,1)
end

local function write(m,x,y,t)
  m.setCursorPos(x,y)
  m.write(t)
end

local function fill(m, x,y,w,h, bgc)
  m.setBackgroundColor(bgc)
  for yy=y, y+h-1 do
    m.setCursorPos(x,yy)
    m.write(string.rep(" ", w))
  end
end

local function panel(m, x,y,w,h, title)
  fill(m, x,y,w,h, colors.white)
  m.setBackgroundColor(colors.white)
  m.setTextColor(colors.black)
  if title then
    m.setCursorPos(x+2, y+1)
    m.write(title)
  end
end

-- schreibt und überschreibt Rest der Zeile -> keine "Reste" im UI
local function writePad(m, x, y, s, w)
  m.setCursorPos(x, y)
  local t = tostring(s)
  if #t > w then t = t:sub(1, w) end
  m.write(t .. string.rep(" ", math.max(0, w - #t)))
end

local function pct(v)
  if type(v)~="number" then return "N/A" end
  if v<=1.001 then v=v*100 end
  return string.format("%3.0f%%", v)
end

local function safeCall(obj, fn, ...)
  if not obj or type(obj[fn]) ~= "function" then return nil end
  local ok, res = pcall(obj[fn], ...)
  if ok then return res end
  return nil
end

local function to01(v)
  if type(v)~="number" then return 0 end
  if v > 1.001 then v = v/100 end
  if v < 0 then v=0 end
  if v > 1 then v=1 end
  return v
end

-- =========================================================
-- LEFT MONITOR LAYOUT  (NEU)
-- =========================================================
local function leftLayout()
  local W,H = monL.getSize()

  local leftMargin  = 2
  local topY        = 4
  local gap         = 1
  local rightMargin = 2
  local bottomMargin= 2

  local leftW  = 28 -- <- hier kannst du Breite links steuern
  local rightW = W - leftMargin - leftW - gap - rightMargin

  local statsH  = 16
  local levelsH = 18

  local rightH = H - topY - bottomMargin
  local turbH  = math.floor(rightH * 0.45)
  local matH   = rightH - turbH - gap

  return {
    W=W, H=H,
    -- LINKS
    B = { x=leftMargin, y=topY,             w=leftW,  h=statsH  }, -- Reactor Stats
    D = { x=leftMargin, y=topY+statsH+gap,  w=leftW,  h=levelsH }, -- Reactor Levels
    -- RECHTS
    C = { x=leftMargin+leftW+gap, y=topY,            w=rightW, h=turbH }, -- Turbine
    E = { x=leftMargin+leftW+gap, y=topY+turbH+gap,  w=rightW, h=matH  }, -- Matrix
  }
end

local LL = leftLayout()

-- =========================================================
-- LEFT: STATIC DRAW
-- =========================================================
local function drawLeftStatic()
  local W,_ = monL.getSize()
  clear(monL)

  write(monL, math.floor(W/2)-6, 1, "REACTOR UI")
  write(monL, math.floor(W/2)-6, 2, "==========")

  panel(monL, LL.B.x, LL.B.y, LL.B.w, LL.B.h, "Reactor Stats")
  panel(monL, LL.D.x, LL.D.y, LL.D.w, LL.D.h, "Reactor Levels")
  panel(monL, LL.C.x, LL.C.y, LL.C.w, LL.C.h, "Turbine")
  panel(monL, LL.E.x, LL.E.y, LL.E.w, LL.E.h, "Matrix")

  -- Reactor Stats labels
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.B.x + 2
  local y = LL.B.y + 3

  write(monL, x, y,     "Status:")
  write(monL, x, y+2,   "Coolant:")
  write(monL, x, y+3,   "Fuel:")
  write(monL, x, y+4,   "Heated:")
  write(monL, x, y+5,   "Waste:")
  write(monL, x, y+7,   "Max Burn:")
  write(monL, x, y+8,   "Burn:")
  write(monL, x, y+9,   "Temp:")
  write(monL, x, y+10,  "Damage:")

  -- Turbine labels (kompakt)
  local tx = LL.C.x + 2
  local ty = LL.C.y + 3
  write(monL, tx, ty,     "Active:")
  write(monL, tx, ty+2,   "Steam:")
  write(monL, tx, ty+3,   "Energy:")
  write(monL, tx, ty+4,   "Prod:")

  -- Matrix labels
  local mx = LL.E.x + 2
  local my = LL.E.y + 3
  write(monL, mx, my,     "Stored:")
  write(monL, mx, my+2,   "Input:")
  write(monL, mx, my+3,   "Output:")
end

-- =========================================================
-- LEFT: LEVELS (live)
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

local function drawLevelsLive()
  local x0 = LL.D.x + 1
  local y0 = LL.D.y + 4
  local barH = LL.D.h - 7
  local barW, gap = 4, 2

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
    ("C%3d%% F%3d%% H%3d%% W%3d%%"):format(
      math.floor(c*100+0.5), math.floor(f*100+0.5),
      math.floor(h*100+0.5), math.floor(w*100+0.5)
    )
  )
end

-- =========================================================
-- LEFT: REACTOR STATS (live)
-- =========================================================
local function drawStatsLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.B.x + 2
  local y = LL.B.y + 3

  local valX = x + 14
  local valW = LL.B.w - (valX - LL.B.x) - 2

  writePad(monL, valX, y,     (r.getStatus() and "ON" or "OFF"), valW)
  writePad(monL, valX, y+2,   pct(r.getCoolantFilledPercentage()), valW)
  writePad(monL, valX, y+3,   pct(r.getFuelFilledPercentage()), valW)
  writePad(monL, valX, y+4,   pct(r.getHeatedCoolantFilledPercentage()), valW)
  writePad(monL, valX, y+5,   pct(r.getWasteFilledPercentage()), valW)

  local maxBurn = safeCall(r, "getMaxBurnRate")
  writePad(monL, valX-1, y+7,   (maxBurn and string.format("%.1fmB/t", maxBurn) or "N/A"), valW)
  writePad(monL, valX, y+8,   string.format("%.1fmB/t", (safeCall(r,"getBurnRate") or 0)), valW)
  writePad(monL, valX, y+9,   string.format("%.0fK", (safeCall(r,"getTemperature") or 0)), valW)
  writePad(monL, valX, y+10,  pct(safeCall(r,"getDamagePercent")), valW)
end

-- =========================================================
-- LEFT: TURBINE STATS (live)
-- =========================================================
local function drawTurbineLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.C.x + 2
  local y = LL.C.y + 3
  local valX = x + 10
  local valW = LL.C.w - (valX - LL.C.x) - 2

  if not t then
    writePad(monL, valX, y,   "N/A", valW)
    writePad(monL, valX, y+2, "N/A", valW)
    writePad(monL, valX, y+3, "N/A", valW)
    writePad(monL, valX, y+4, "N/A", valW)
    return
  end

  local active = safeCall(t, "getActive")
  local steamP = safeCall(t, "getSteamFilledPercentage")
  local energy = safeCall(t, "getEnergyStored")
  local prod   = safeCall(t, "getProductionRate")

  writePad(monL, valX, y,   tostring(active), valW)
  writePad(monL, valX, y+2, steamP and pct(steamP) or "N/A", valW)
  writePad(monL, valX, y+3, energy and tostring(energy) or "N/A", valW)
  writePad(monL, valX, y+4, prod and (tostring(prod).." FE/t") or "N/A", valW)
end

-- =========================================================
-- LEFT: MATRIX STATS (live)
-- =========================================================
local function drawMatrixLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.E.x + 2
  local y = LL.E.y + 3
  local valX = x + 10
  local valW = LL.E.w - (valX - LL.E.x) - 2

  if not mtx then
    writePad(monL, valX, y,   "N/A", valW)
    writePad(monL, valX, y+2, "N/A", valW)
    writePad(monL, valX, y+3, "N/A", valW)
    return
  end

  -- Namen können je nach Mod/Bridge variieren -> wir probieren mehrere
  local stored = safeCall(mtx, "getEnergyStored") or safeCall(mtx, "getStored") or safeCall(mtx, "getStoredEnergy")
  local input  = safeCall(mtx, "getLastInput")    or safeCall(mtx, "getInput")  or safeCall(mtx, "getInputRate")
  local output = safeCall(mtx, "getLastOutput")   or safeCall(mtx, "getOutput") or safeCall(mtx, "getOutputRate")

  writePad(monL, valX, y,   stored and tostring(stored) or "N/A", valW)
  writePad(monL, valX, y+2, input  and (tostring(input).." FE/t")  or "N/A", valW)
  writePad(monL, valX, y+3, output and (tostring(output).." FE/t") or "N/A", valW)
end

-- =========================================================
-- RIGHT MONITOR: CONTROLS
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
  local W,_ = monR.getSize()

  write(monR, math.floor(W/2)-6, 1, "CONTROLS")
  write(monR, math.floor(W/2)-6, 2, "==========")

  panel(monR, 2,4, W-2, 18, "Actions")

  buttons = {}
  local x = 4
  local w = W-8
  local y = 7
  local h = 4
  local g = 2

  drawButton("start", x,y,         w,h, "START", colors.green)
  drawButton("stop",  x,y+h+g,     w,h, "STOP",  colors.red)
  drawButton("scram", x,y+2*(h+g), w,h, "AZ-5",  colors.orange)

  -- Platz für Settings später:
  panel(monR, 2, 23, W-2, 20, "Settings (later)")
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

while true do
  drawStatsLive()
  drawLevelsLive()
  drawTurbineLive()
  drawMatrixLive()

  local e,side,x,y = os.pullEventTimeout("monitor_touch", CFG.REFRESH)
  if e=="monitor_touch" and side==CFG.RIGHT_MONITOR then
    local id = hit(x,y)
    if id then action(id) end
  end
end
