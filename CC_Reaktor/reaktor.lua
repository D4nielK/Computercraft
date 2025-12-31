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

  TEST_REDSTONE_SIDE = "back",     -- Seite wo dein Test-Signal raus soll
  TEST_PULSE_SEC     = 2.0,        -- wie lange das Signal an bleiben soll


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

local function safeCall(obj, fn, ...)
  if not obj or type(obj[fn]) ~= "function" then return nil end
  local ok, res = pcall(obj[fn], ...)
  if ok then return res end
  return nil
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

local function fmtFE_split(v, perTick)
  if type(v) ~= "number" then
    return "   N/A", ""
  end

  local unit = perTick and "FE/t" or "FE"
  local a = math.abs(v)
  local num, prefix = v, ""

  if a >= 1e12 then num, prefix = v/1e12, "T"
  elseif a >= 1e9 then num, prefix = v/1e9, "G"
  elseif a >= 1e6 then num, prefix = v/1e6, "M"
  elseif a >= 1e3 then num, prefix = v/1e3, "k"
  end

  -- Zahl immer gleiche Breite, rechtsbündig
  local numStr = string.format("%7.2f", num)

  return numStr, prefix .. unit
end

local function fmtPct_split(v)
  if type(v) ~= "number" then
    return "  N/A", "%"
  end
  return string.format("%6.2f", v), "%"
end

local function fmtMBt_split(v)
  if type(v) ~= "number" then
    return "  N/A", "mB/t"
  end
  return string.format("%7.0f", v), "mB/t"
end

-- =========================================================
-- RIGHT UI STATE
-- =========================================================
local ui = {
  burnTarget = 0.0,     -- Ziel-BurnRate (mB/t)
  burnMax    = nil,     -- wird einmal gelesen (max burn)
  dumpModes  = { "IDLE", "DUMPING", "DUMPING_EXCESS" },
  dumpIndex  = 1,

  testTimerId = nil,    -- Timer-ID fürs Test-Puls-Aus
}

local function clamp(x, a, b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function round1(x)
  return math.floor(x * 10 + 0.5) / 10
end

local function setBurnrateTarget(newVal)
  local maxB = ui.burnMax or tonumber(safeCall(r, "getMaxBurnRate")) or 9999
  ui.burnMax = maxB
  ui.burnTarget = round1(clamp(newVal, 0, maxB))

  -- Versuche zu setzen (Mekanism: meist setBurnRate)
  if r and r.setBurnRate then
    pcall(r.setBurnRate, ui.burnTarget)
  end
end

local function cycleDumpMode()
  -- read current (optional)
  ui.dumpIndex = ui.dumpIndex % #ui.dumpModes + 1
  local mode = ui.dumpModes[ui.dumpIndex]

  -- Mekanism Turbine: meist setDumpingMode(string)
  if t and t.setDumpingMode then
    pcall(t.setDumpingMode, mode)
  end
end

local function startTestPulse()
  if not CFG.TEST_REDSTONE_SIDE then return end
  redstone.setOutput(CFG.TEST_REDSTONE_SIDE, true)
  if ui.testTimerId then
    -- alten Timer ignorieren, wir machen einfach neuen Puls
    ui.testTimerId = nil
  end
  ui.testTimerId = os.startTimer(CFG.TEST_PULSE_SEC or 2.0)
end

local function stopTestPulse()
  if not CFG.TEST_REDSTONE_SIDE then return end
  redstone.setOutput(CFG.TEST_REDSTONE_SIDE, false)
  ui.testTimerId = nil
end


-- =========================================================
-- FIXED-COLUMN VALUE WRITERS (no shifting units)
-- =========================================================

-- schreibt "Zahl" + "Einheit" in 2 festen Spalten
-- numW/unitW kannst du global fein-tunen
local COL = {
  numW  = 8,   -- Zahl-Breite (rechts)
  unitW = 7,   -- Einheit-Breite (links) -> 6 reicht für "GFE/t"
  gap   = 1,
}

local function writeValUnit(m, x, y, numStr, unitStr, totalW)
  numStr  = tostring(numStr or "N/A")
  unitStr = tostring(unitStr or "")

  -- Mindestbreiten (Einheit niemals abschneiden!)
  local wantUnitW = math.max(COL.unitW, #unitStr)
  local wantNumW  = COL.numW

  -- Wenn nicht genug Platz: NUR Zahlbreite reduzieren
  local minNumW = 3
  local need = wantNumW + COL.gap + wantUnitW
  if need > totalW then
    wantNumW = math.max(minNumW, totalW - (COL.gap + wantUnitW))
  end

  -- Falls immer noch zu eng: dann harte Notlösung (alles in eine Zeile)
  if wantNumW + COL.gap + wantUnitW > totalW then
    writePad(m, x, y, numStr .. " " .. unitStr, totalW)
    return
  end

  local n = string.format("%" .. wantNumW .. "s", numStr)
  local u = string.format("%-" .. wantUnitW .. "s", unitStr)
  writePad(m, x, y, n .. string.rep(" ", COL.gap) .. u, totalW)
end


-- mB/t fixer: Zahl ohne Einheitformatierung
local function fmtMBt_split(v)
  if type(v) ~= "number" then return "N/A", "mB/t" end
  return string.format("%7.1f", v), "mB/t"  -- 0.1 Auflösung (kannst du auf %.0f ändern)
end

-- mB/t → B/t (fixe Breite, sauberes Alignment)
local function fmtBt_split(mB)
  if type(mB) ~= "number" then
    return "   N/A", "B/t"
  end

  local B = mB / 1000
  return string.format("%7.2f", B), "  B/t"
end


-- Kelvin fixer
local function fmtK_split(v)
  if type(v) ~= "number" then return "N/A", "K" end
  return string.format("%7.0f", v), "K"
end

-- Prozent fixer (nimmt 0..1 oder 0..100)
local function fmtPct_split(v)
  if type(v) ~= "number" then return "N/A", "%" end
  local p = v
  if p <= 1.001 then p = p * 100 end
  return string.format("%7.2f", p), "%"
end

-- FE / FE/t fixer (Zahl + Prefix getrennt, Einheit bleibt stabil)
local function fmtFE_split(v, perTick)
  local unit = perTick and "FE/t" or "FE"
  if type(v) ~= "number" then
    return "   N/A", " " .. unit   -- auch hier ein Leerzeichen fürs Align
  end

  local a = math.abs(v)
  local num, prefix = v, ""

  if a >= 1e12 then num, prefix = v/1e12, "T"
  elseif a >= 1e9 then num, prefix = v/1e9, "G"
  elseif a >= 1e6 then num, prefix = v/1e6, "M"
  elseif a >= 1e3 then num, prefix = v/1e3, "k"
  end

  local p = (prefix ~= "" and prefix or " ")
  return string.format("%7.2f", num), p .. unit
end

-- =========================================================
-- RUNTIME / INTEGRATION
-- =========================================================
local lastEpoch = os.epoch("utc")  -- ms
local wasOn = false
local uptimeMs = 0

local TICKS_PER_SEC = 20

local runTime_s = 0
local fuelUsed_mB = 0            -- integrierter Fuel-Verbrauch (mB)
local energyGen_FE = 0           -- integrierte Energie (FE)

local lastMs = os.epoch("utc")
local lastShownSec = -1

local function updateCounters()
  local now = os.epoch("utc")
  local dt = (now - lastMs) / 1000
  lastMs = now
  if dt < 0 then dt = 0 end

  local on = safeCall(r, "getStatus") == true

  -- Laufzeit: zählt nur wenn Reaktor "ON"
  if on then
    runTime_s = runTime_s + dt
  end

  -- Fuel: nur zählen wenn wirklich verbrannt wird
  local actual = safeCall(r, "getActualBurnRate") -- mB/t
  if type(actual) == "number" and actual > 0 then
    -- optional extra check: Fuel wirklich vorhanden
    local fuel = safeCall(r, "getFuel") -- mB im Tank (bei dir vorhanden)
    if type(fuel) == "number" and fuel > 0 then
      fuelUsed_mB = fuelUsed_mB + actual * TICKS_PER_SEC * dt
    end
  end
end


local function fmtTimeSeconds(sec)
  sec = math.floor(sec + 0.5)
  local h = math.floor(sec/3600)
  local m = math.floor((sec%3600)/60)
  local s = sec%60
  return string.format("%02d:%02d:%02d", h, m, s)
end


local function fmtMB(mb)
  if type(mb) ~= "number" then return "N/A" end
  if mb >= 1000 then
    return string.format("%7.2f  B", mb/1000)  -- Buckets
  end
  return string.format("%7.0f  mB", mb)
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
  local levelsH = 16

  local rightH = H - topY - bottomMargin
  local turbH  = math.floor(rightH * 0.45)+4
  local matH   = rightH - turbH - gap+2

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
  write(monL, x, y+12,  "Uptime:")
  write(monL, x, y+13,  "Fuel used:")
  write(monL, x, y+14,  "Energy gen:")


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
  write(monL, mx, my+5,   "Change:")
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

  -- Status (Text, keine Einheit)
  writePad(monL, valX+5, y, (r.getStatus() and "ON" or "OFF"), valW-5)

  -- % Werte
  do local n,u = fmtPct_split(r.getCoolantFilledPercentage());        writeValUnit(monL, valX, y+2, n, u, valW) end
  do local n,u = fmtPct_split(r.getFuelFilledPercentage());           writeValUnit(monL, valX, y+3, n, u, valW) end
  do local n,u = fmtPct_split(r.getHeatedCoolantFilledPercentage());   writeValUnit(monL, valX, y+4, n, u, valW) end
  do local n,u = fmtPct_split(r.getWasteFilledPercentage());          writeValUnit(monL, valX, y+5, n, u, valW) end

  -- Max Burn / Burn (mB/t)
  local maxBurn = safeCall(r, "getMaxBurnRate")
  do local n,u = fmtMBt_split(maxBurn);                               writeValUnit(monL, valX, y+7, n, u, valW) end
  do local n,u = fmtMBt_split(safeCall(r,"getBurnRate") or 0);        writeValUnit(monL, valX, y+8, n, u, valW) end

  -- Temp (K)
  do local n,u = fmtK_split(safeCall(r,"getTemperature") or 0);       writeValUnit(monL, valX, y+9, n, u, valW) end

  -- Damage (%)
  do local n,u = fmtPct_split(safeCall(r,"getDamagePercent"));        writeValUnit(monL, valX, y+10, n, u, valW) end

  -- Zusatzwerte: Uptime ist Text
  writePad(monL, valX-1,   y+12, fmtTimeSeconds(runTime_s), valW)

  -- Fuel used: (wir lassen fmtMB so, weil "mB" oder "B" variieren kann)
  -- aber auch hier fix: Zahl + Einheit getrennt
  do
    local mb = fuelUsed_mB
    local num, unit = "N/A", ""
    if type(mb) == "number" then
      if mb >= 1000 then
        num, unit = string.format("%7.2f", mb/1000), "B"
      else
        num, unit = string.format("%7.0f", mb), "mB"
      end
    end
    writeValUnit(monL, valX, y+13, num, unit, valW)
  end

  -- Energy gen: FE (fix)
  do local n,u = fmtFE_split(energyGen_FE, false);                    writeValUnit(monL, valX, y+14, n, u, valW) end
end

-- =========================================================
-- LEFT: TURBINE STATS (live)
-- =========================================================
local function drawTurbineLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.C.x + 2
  local y = LL.C.y + 3
  local valX = x + 11
  local valW = LL.C.w - (valX - LL.C.x) - 2

  if not t then
    writePad(monL, valX, y, "N/A", valW)
    return
  end

  local formed    = safeCall(t, "isFormed")
  local prodJ     = safeCall(t, "getProductionRate")
  local maxProdJ  = safeCall(t, "getMaxProduction")
  local prod      = J_to_FE(prodJ)
  local maxProd   = J_to_FE(maxProdJ)

  local steamPct  = safeCall(t, "getSteamFilledPercentage")
  local energyPct = safeCall(t, "getEnergyFilledPercentage")

  local steamIn   = safeCall(t, "getLastSteamInputRate")
  local flow      = safeCall(t, "getFlowRate")
  local maxFlow   = safeCall(t, "getMaxFlowRate")

  local status = "N/A"
  if formed == false then status = "Not formed"
  elseif type(prod) == "number" then status = (prod > 0) and "Active" or "Idle"
  else status = "Formed" end

  -- Status (Text)
  writePad(monL, valX, y, status, valW)

  -- Steam % / Water / Energy %
  do local n,u = fmtPct_split(steamPct);        writeValUnit(monL, valX, y+2, n, u, valW) end
  do local n,u = fmtPct_split(energyPct);       writeValUnit(monL, valX, y+4, n, u, valW) end
  do local n,u = fmtFE_split(maxProd, true);    writeValUnit(monL, valX, y+6, n, u, valW) end
  do local n,u = fmtFE_split(prod, true);       writeValUnit(monL, valX, y+7, n, u, valW) end
  do local n,u = fmtBt_split(steamIn);         writeValUnit(monL, valX, y+8, n, u, valW) end
  do local n,u = fmtBt_split(maxFlow);         writeValUnit(monL, valX, y+9, n, u, valW) end
  do local n,u = fmtBt_split(flow);            writeValUnit(monL, valX, y+10,n, u, valW) end

end


-- =========================================================
-- LEFT: MATRIX STATS (live)
-- =========================================================
local function drawMatrixLive()
  monL.setBackgroundColor(colors.white)
  monL.setTextColor(colors.black)

  local x = LL.E.x + 2
  local y = LL.E.y + 3

  local valX = x + 11
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

  local storedPct = (type(stored)=="number" and type(cap)=="number" and cap>0) and (stored / cap * 100) or nil

  do local n,u = fmtFE_split(cap, false);    writeValUnit(monL, valX, y,   n, u, valW) end
  do local n,u = fmtFE_split(stored,false);  writeValUnit(monL, valX, y+1, n, u, valW) end
  do local n,u = fmtPct_split(storedPct);    writeValUnit(monL, valX, y+2, n, u, valW) end
  do local n,u = fmtFE_split(input, true);   writeValUnit(monL, valX, y+3, n, u, valW) end
  do local n,u = fmtFE_split(output,true);   writeValUnit(monL, valX, y+4, n, u, valW) end
  do local n,u = fmtFE_split(change,true);   writeValUnit(monL, valX, y+5, n, u, valW) end

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

local function drawButtonSmall(id, x,y,w,h, label, bgc)
  monR.setBackgroundColor(bgc)
  monR.setTextColor(colors.black)
  for yy=y,y+h-1 do
    monR.setCursorPos(x,yy)
    monR.write(string.rep(" ", w))
  end
  -- label linksbündiger, damit es bei schmalen Buttons nicer aussieht
  monR.setCursorPos(x + 1, y + math.floor(h/2))
  monR.write(label:sub(1, w-2))
  buttons[#buttons+1] = {id=id, x=x,y=y,w=w,h=h}
end


local function drawRightStatic()
  clear(monR)
  local W,H = monR.getSize()

  write(monR, math.floor(W/2)-6, 1, "CONTROLS")
  write(monR, math.floor(W/2)-6, 2, "==========")

  buttons = {}

  local margin = 2
  local gap = 1

  -- Wir nutzen unten ca. 12 Zeilen für UI (Buttons+Settings)
  local uiH = 12
  local topY = H - uiH + 1   -- <-- ANKER UNTEN

  local leftColW  = 16       -- etwas breiter, besser zu klicken
  local rightColW = W - margin*2 - leftColW - gap

  local leftX  = margin
  local rightX = margin + leftColW + gap

  panel(monR, leftX,  topY, leftColW,  uiH, "Actions")
  panel(monR, rightX, topY, rightColW, uiH, "Settings")

  -- -------------------------------------------------------
  -- LINKS: Action Buttons (größer, easier)
  -- -------------------------------------------------------
  local bx = leftX + 1
  local bw = leftColW - 2
  local bh = 3
  local by = topY + 2
  local bg = 1

  drawButton("start", bx, by + 0*(bh+bg), bw, bh, "START", colors.green)
  drawButton("stop",  bx, by + 1*(bh+bg), bw, bh, "STOP",  colors.red)
  drawButton("scram", bx, by + 2*(bh+bg), bw, bh, "AZ-5",  colors.orange)
  drawButton("test",  bx, by + 3*(bh+bg), bw, bh, "TEST",  colors.lightBlue)

  -- -------------------------------------------------------
  -- RECHTS: Settings unten, mit Platz
  -- -------------------------------------------------------
  monR.setBackgroundColor(colors.white)
  monR.setTextColor(colors.black)

  local sx = rightX + 2
  local sy = topY + 2

  -- BurnRate immer aus Reactor lesen (Fix für 00.0 Bug)
  do
    local cur = tonumber(safeCall(r, "getBurnRate"))
    if cur ~= nil then
      ui.burnTarget = math.floor(cur * 10 + 0.5) / 10
    end
  end

  monR.setCursorPos(sx, sy)
  monR.write("BurnRate")

  local brStr = string.format("%04.1f", ui.burnTarget)  -- "00.0"
  local brX = sx
  local brY = sy + 2
  monR.setCursorPos(brX, brY)
  monR.write(brStr .. " mB/t")

  -- Größere Pfeile: 3 breit, 2 hoch
  local upY = brY - 1
  local dnY = brY + 1

  -- Positionen in "00.0": 1 2 . 4
  local d0 = brX + 0
  local d1 = brX + 1
  local d01 = brX + 3

  drawButton("br_up_10",  d0, upY, 3, 1, " ^ ", colors.lightGray)
  drawButton("br_dn_10",  d0, dnY, 3, 1, " v ", colors.lightGray)

  drawButton("br_up_1",   d1, upY, 3, 1, " ^ ", colors.lightGray)
  drawButton("br_dn_1",   d1, dnY, 3, 1, " v ", colors.lightGray)

  drawButton("br_up_0.1", d01, upY, 3, 1, " ^ ", colors.lightGray)
  drawButton("br_dn_0.1", d01, dnY, 3, 1, " v ", colors.lightGray)

  -- Turbine Mode
  local modeY = sy + 6
  monR.setCursorPos(sx, modeY)
  monR.write("Turbine Mode")

  local curMode = (t and safeCall(t, "getDumpingMode")) or ui.dumpModes[ui.dumpIndex]
  drawButton("dump_cycle", sx, modeY+1, rightColW-4, 3, tostring(curMode), colors.gray)
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
    if r.activate then pcall(r.activate) end

  elseif id=="stop" then
    -- Manche Adapter nennen es deactivate / scram / setStatus(false)
    if r.deactivate then
      pcall(r.deactivate)
    elseif r.setStatus then
      pcall(r.setStatus, false)
    elseif r.scram then
      pcall(r.scram)
    end

  elseif id=="scram" then
    if r.scram then pcall(r.scram) end

  elseif id=="test" then
    startTestPulse()

  elseif id=="dump_cycle" then
    cycleDumpMode()
    drawRightStatic()

  elseif id=="br_up_10" then
    setBurnrateTarget(ui.burnTarget + 10.0); drawRightStatic()
  elseif id=="br_dn_10" then
    setBurnrateTarget(ui.burnTarget - 10.0); drawRightStatic()

  elseif id=="br_up_1" then
    setBurnrateTarget(ui.burnTarget + 1.0); drawRightStatic()
  elseif id=="br_dn_1" then
    setBurnrateTarget(ui.burnTarget - 1.0); drawRightStatic()

  elseif id=="br_up_0.1" then
    setBurnrateTarget(ui.burnTarget + 0.1); drawRightStatic()
  elseif id=="br_dn_0.1" then
    setBurnrateTarget(ui.burnTarget - 0.1); drawRightStatic()
  end
end



-- =========================================================
-- BOOT
-- =========================================================
drawLeftStatic()
drawRightStatic()

while true do
  updateCounters()

  drawStatsLive()
  drawLevelsLive()
  drawTurbineLive()
  drawMatrixLive()

  -- Timer-Event (dein Ersatz für pullEventTimeout)
  local timer = os.startTimer(CFG.REFRESH)
  local e, p1, p2, p3 = os.pullEvent()
  while e ~= "monitor_touch" and not (e == "timer" and p1 == timer) do
    e, p1, p2, p3 = os.pullEvent()
  end

  if e == "timer" then
  if ui.testTimerId and p1 == ui.testTimerId then
    stopTestPulse()
  end

  elseif e == "monitor_touch" then
   local side, x, y = p1, p2, p3
   if side == CFG.RIGHT_MONITOR then
    local id = hit(x, y)
    if id then action(id) end
   end
  end

end
