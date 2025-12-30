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
  TURBINE_NAME = "turbineValve_0",  -- z.B. "turbineValve_0"
  MATRIX_NAME  = "inductionPort_0",  -- z.B. "inductionPort_0"

  ENERGY_J_PER_FE = 2.5,

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

local function J_to_FE(j)
  if type(j) ~= "number" then return nil end
  return j / (CFG.ENERGY_J_PER_FE or 2.5)
end

local function fmtFE(v, perTick)
  if type(v) ~= "number" then return "N/A" end

  -- Suffix ohne führendes Leerzeichen
  local suf = perTick and "FE/t" or "FE"

  local a = math.abs(v)
  local num, prefix

  if a >= 1e12 then num, prefix = v/1e12, "T"
  elseif a >= 1e9 then num, prefix = v/1e9, "G"
  elseif a >= 1e6 then num, prefix = v/1e6, "M"
  elseif a >= 1e3 then num, prefix = v/1e3, "k"
  else
    -- unter 1000 ohne Prefix, damit es sauber bleibt
    return string.format("%.0f%s", v, suf)
  end

  -- ohne Leerzeichen: 1.83MFE/t
  return string.format("%.2f%s%s", num, prefix, suf)
end


local function safeCall(obj, fn, ...)
  if not obj or type(obj[fn]) ~= "function" then return nil end
  local ok, res = pcall(obj[fn], ...)
  if ok then return res end
  return nil
end

local function firstCall(obj, names)
  for _, fn in ipairs(names) do
    local v = safeCall(obj, fn)
    if v ~= nil then return v end
  end
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

  local statsH  = 19
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

  -- Turbine labels (wie gewünscht, mit Leerzeilen)
  local tx = LL.C.x + 2
  local ty = LL.C.y + 3

  write(monL, tx, ty,     "Status:")
  write(monL, tx, ty+2,   "Steam:")
  write(monL, tx, ty+3,   "Water:")
  write(monL, tx, ty+4,   "Energy:")

  write(monL, tx, ty+6,   "Max Prod:")
  write(monL, tx, ty+7,   "Prod:")

  write(monL, tx, ty+8,   "Steam In:")
  write(monL, tx, ty+9,   "Max Flow:")
  write(monL, tx, ty+10,  "Flow:")


  -- Matrix labels
  local mx = LL.E.x + 2
  local my = LL.E.y + 3
  write(monL, mx, my,     "Max Energy")
  write(monL, mx, my+1,   "Stored:")
  write(monL, mx, my+2,   "Stored %:")
  write(monL, mx, my+3,   "Input:")
  write(monL, mx, my+4,   "Output:")
  write(monL, mx, my+5,   "Change")
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

  local valX = x + 12
  local valW = LL.B.w - (valX - LL.B.x) - 2

  writePad(monL, valX+4, y,     (r.getStatus() and "ON" or "OFF"), valW-4)
  writePad(monL, valX+4, y+2,   pct(r.getCoolantFilledPercentage()), valW-4)
  writePad(monL, valX+4, y+3,   pct(r.getFuelFilledPercentage()), valW-4)
  writePad(monL, valX+4, y+4,   pct(r.getHeatedCoolantFilledPercentage()), valW-4)
  writePad(monL, valX+4, y+5,   pct(r.getWasteFilledPercentage()), valW-4)

  local maxBurn = safeCall(r, "getMaxBurnRate")
  writePad(monL, valX+3, y+7,   (maxBurn and string.format("%.1fmB/t", maxBurn) or "N/A"), valW-3)
  writePad(monL, valX+4, y+8,   string.format("%.1fmB/t", (safeCall(r,"getBurnRate") or 0)), valW-4)
  writePad(monL, valX+4, y+9,   string.format("%.0fK", (safeCall(r,"getTemperature") or 0)), valW-4)
  writePad(monL, valX+4, y+10,  pct(safeCall(r,"getDamagePercent")), valW-4)
end

-- =========================================================
-- LEFT: TURBINE STATS (live)
-- =========================================================
local function drawTurbineLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.C.x + 2
  local y = LL.C.y + 3
  local valX = x + 12
  local valW = LL.C.w - (valX - LL.C.x) - 2

  if not t then
    writePad(monL, valX, y,     "N/A", valW)
    writePad(monL, valX, y+2,   "N/A", valW)
    writePad(monL, valX, y+3,   "N/A", valW)
    writePad(monL, valX, y+4,   "N/A", valW)
    writePad(monL, valX, y+6,   "N/A", valW)
    writePad(monL, valX, y+7,   "N/A", valW)
    writePad(monL, valX, y+8,   "N/A", valW)
    writePad(monL, valX, y+9,   "N/A", valW)
    writePad(monL, valX, y+10,  "N/A", valW)
    return
  end

  -- Werte (genau aus deiner Method-Liste)
  local formed      = safeCall(t, "isFormed")
  local prodJ        = safeCall(t, "getProductionRate")          -- FE/t
  local maxProdJ     = safeCall(t, "getMaxProduction")           -- FE/t
  local prod        = J_to_FE(prodJ)
  local maxProd     = J_to_FE(maxProdJ)
  local steamPct    = safeCall(t, "getSteamFilledPercentage")   -- 0..1 oder 0..100
  local energyPct   = safeCall(t, "getEnergyFilledPercentage")  -- 0..1 oder 0..100
  local steamIn     = safeCall(t, "getLastSteamInputRate")      -- mB/t
  local flow        = safeCall(t, "getFlowRate")                -- (Einheit modabhängig, meist mB/t)
  local maxFlow     = safeCall(t, "getMaxFlowRate")
  local dumpMode    = safeCall(t, "getDumpingMode")             -- string/enum
  local energy      = safeCall(t, "getEnergy")                  -- FE
  local maxEnergy   = safeCall(t, "getMaxEnergy")               -- FE
  local maxWaterOut = safeCall(t, "getMaxWaterOutput")          -- meist mB/t (max)

  -- Status ableiten: formed + produziert?
  local status = "N/A"
  if formed == false then
    status = "Not formed"
  elseif type(prod) == "number" then
    status = (prod > 0) and "Active" or "Idle"
  else
    status = "Formed"
  end

  -- Anzeigen
  writePad(monL, valX, y,     status, valW)

  -- Steam / Heated Coolant % (bei Turbine ist es Steam)
  writePad(monL, valX+4, y+2,   steamPct and pct(steamPct) or "N/A", valW-4)

  -- Water %: nicht per turbineValve API vorhanden -> zeigen wir N/A
  writePad(monL, valX+4, y+3,   "N/A", valW-4)

  -- Energy %
  writePad(monL, valX+4, y+4,   energyPct and pct(energyPct) or "N/A", valW-4)

  -- Max Production / Production
 writePad(monL, valX+3,   y+6, maxProd and fmtFE(maxProd, true) or "N/A", valW-3)
 writePad(monL, valX+6, y+7, prod    and fmtFE(prod, true)    or "N/A", valW-6)


  -- Steam input
 writePad(monL, valX+6, y+8, steamIn and (string.format("%.0fmB/t", steamIn)) or "N/A", valW-6)

 -- Max Flow
 writePad(monL, valX, y+9, maxFlow and (string.format("%.0fmB/t", maxFlow)) or "N/A", valW)

 -- Current Flow
 writePad(monL, valX+6, y+10, flow and (string.format("%.0fmB/t", flow)) or "N/A", valW-6)

end


-- =========================================================
-- LEFT: MATRIX STATS (live)
-- =========================================================
local function drawMatrixLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.E.x + 2
  local y = LL.E.y + 3

  local valX = x + 10      -- Werte-Spalte (wenn du es mehr rechts willst: 11/12)
  local valW = LL.E.w - (valX - LL.E.x) - 2

  local capJ    = mtx.getMaxEnergy()
  local storedJ = mtx.getEnergy()
  local inputJ  = mtx.getLastInput()
  local outputJ = mtx.getLastOutput()

  local cap    = J_to_FE(capJ)
  local stored = J_to_FE(storedJ)
  local input  = J_to_FE(inputJ)
  local output = J_to_FE(outputJ)
  local change = (type(input)=="number" and type(output)=="number") and (input - output) or nil

  local storedPct = (type(stored)=="number" and type(cap)=="number" and cap>0)
  and (stored / cap * 100) or nil

  writePad(monL, valX+4, y,     fmtFE(cap, false),    valW-4)
  writePad(monL, valX+5, y+1,   fmtFE(stored, false), valW-5)
  writePad(monL, valX+5, y+2,   (storedPct and string.format("%6.2f%%, storedPct")))
  writePad(monL, valX+5, y+2,   fmtFE(input, true),   valW-5)
  writePad(monL, valX+5, y+3,   fmtFE(output, true),  valW-5)
  writePad(monL, valX+5, y+4,   fmtFE(change, true),  valW-5)
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

-- Timer starten (ersetzt pullEventTimeout)
local timer = os.startTimer(CFG.REFRESH)

local e, p1, p2, p3 = os.pullEvent()
 while e ~= "monitor_touch" and not (e == "timer" and p1 == timer) do
  e, p1, p2, p3 = os.pullEvent()
 end

 -- Anzeige IMMER aktualisieren
 drawStatsLive()
 drawLevelsLive()
 drawTurbineLive()
 drawMatrixLive()

 -- Nur bei Touch reagieren
 if e == "monitor_touch" then
   local side, x, y = p1, p2, p3
   if side == CFG.RIGHT_MONITOR then
    local id = hit(x, y)
    if id then action(id) end
   end
 end

end
