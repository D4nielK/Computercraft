---@diagnostic disable: undefined-global

-- =========================================================
-- BLOCK 0: CONFIG + PERIPHERALS + UTILS
-- =========================================================

local CFG = {
  title = "Cherenkov",

  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",
  -- matrix  = "inductionMatrix_0", -- später, wenn vorhanden

  monitorScale = 0.5,
  refresh = 0.5,

  -- Alarm/Settings (dein "Settings"-Kasten)
  set = {
    burnRate = 1.0,
    maxTempK = 1200,
    maxWastePct = 90,
    minFuelPct = 5,
    minCoolantPct = 10,
  }
}

local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)

local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

local function fmt1(x) return (type(x)=="number") and string.format("%.1f", x) or "?" end
local function fmt0(x) return (type(x)=="number") and string.format("%.0f", x) or "?" end
local function fmtPct(x) return (type(x)=="number") and string.format("%.1f%%", x) or "?" end

local function clear()
  mon.clear()
  mon.setCursorPos(1,1)
end

-- Zeichnet einen einfachen Rahmen
local function box(x, y, w, h, title)
  -- obere/untere Linie
  mon.setCursorPos(x, y);         mon.write("+"..string.rep("-", w-2).."+")
  mon.setCursorPos(x, y+h-1);     mon.write("+"..string.rep("-", w-2).."+")
  -- Seiten
  for yy = y+1, y+h-2 do
    mon.setCursorPos(x, yy);      mon.write("|")
    mon.setCursorPos(x+w-1, yy);  mon.write("|")
  end
  -- Titel
  if title then
    mon.setCursorPos(x+2, y)
    mon.write(title)
  end
end

-- schreibt Text in Box (relativ)
local function put(x, y, s)
  mon.setCursorPos(x, y)
  mon.write(s)
end

-- =========================================================
-- BLOCK A: DATA ACQUISITION (readAll)
-- =========================================================

local function readAll()
  -- Reaktor
  local reactor = {
    status = r.getStatus(),
    logic  = r.getLogicMode(),
    tempK  = r.getTemperature(),
    heatRate = r.getHeatingRate(),
    maxBurn = r.getMaxBurnRate(),
    fuelPct = r.getFuelFilledPercentage(),
    wastePct = r.getWasteFilledPercentage(),
    coolPct = r.getHeatedCoolantFilledPercentage(),
  }

  -- Turbine (Methodennamen können je nach AP-Version leicht variieren!)
  -- Wenn ein Call bei dir anders heißt, passen wir ihn an.
  local turbine = {
    active = (t.getActive and t.getActive()) or (t.getStatus and t.getStatus()) or nil,
    rpm    = (t.getRotorSpeed and t.getRotorSpeed()) or (t.getRPM and t.getRPM()) or nil,
    maxRpm = (t.getMaxRotorSpeed and t.getMaxRotorSpeed()) or nil,
    prod   = (t.getEnergyProduced and t.getEnergyProduced()) or nil,
    maxProd= (t.getMaxEnergyProduced and t.getMaxEnergyProduced()) or nil,
    stored = (t.getEnergyStored and t.getEnergyStored()) or nil,
    cap    = (t.getEnergyCapacity and t.getEnergyCapacity()) or nil,
  }

  return { reactor = reactor, turbine = turbine }
end

-- =========================================================
-- BLOCK 1: REACTOR SIZE / "SCHACHBRETT" VISUAL
-- =========================================================
local function drawReactorGrid(x, y)
  -- Platzhalter: 5x5 Grid wie in deinem Bild
  -- Später: kannst du es dynamisch an r.getWidth()/getLength() koppeln
  local w, h = 7, 7 -- Rahmen um Grid
  box(x, y, w, h, nil)

  -- Koordinaten-Achsen (optional)
  -- kleine 5x5 "Punkte"
  for gy=1,5 do
    for gx=1,5 do
      mon.setCursorPos(x+1+gx, y+1+gy)
      mon.write(".")
    end
  end

  -- Beispiel "blau Punkte" (Dummy)
  local pts = { {3,2},{2,4},{4,4},{3,5} }
  for _,p in ipairs(pts) do
    mon.setCursorPos(x+1+p[1], y+1+p[2])
    mon.write("o")
  end
end

-- =========================================================
-- BLOCK 2: REACTOR STATS + SETTINGS BOX
-- =========================================================
local function drawReactorPanel(x, y, w, h, data)
  box(x, y, w, h, "Reaktor")

  local rr = data.reactor
  put(x+2, y+2, "Stats:")
  put(x+2, y+3, "Status: " .. (rr.status and "Aktiv" or "Aus"))
  put(x+2, y+4, "Logic:  " .. tostring(rr.logic))
  put(x+2, y+5, "Temp:   " .. fmt0(rr.tempK) .. " K")
  put(x+2, y+6, "HeatRt: " .. fmt1(rr.heatRate))
  put(x+2, y+7, "Fuel:   " .. fmtPct(rr.fuelPct))
  put(x+2, y+8, "Waste:  " .. fmtPct(rr.wastePct))
  put(x+2, y+9, "Cool:   " .. fmtPct(rr.coolPct))
  put(x+2, y+10,"MaxBurn:" .. fmt1(rr.maxBurn))

  put(x+2, y+12, "Settings:")
  put(x+2, y+13, "Burn:   " .. fmt1(CFG.set.burnRate))
  put(x+2, y+14, "MaxTemp:" .. fmt0(CFG.set.maxTempK).."K")
  put(x+2, y+15, "MaxWst: " .. fmt0(CFG.set.maxWastePct).."%")
  put(x+2, y+16, "MinFuel:" .. fmt0(CFG.set.minFuelPct).."%")
  -- usw.
end

-- =========================================================
-- BLOCK 3: TURBINE PANEL
-- =========================================================
local function drawTurbinePanel(x, y, w, h, data)
  box(x, y, w, h, "Turbine")
  local tt = data.turbine

  put(x+2, y+2, "Stats:")
  put(x+2, y+3, "Status: " .. tostring(tt.active))
  put(x+2, y+4, "RPM:    " .. fmt1(tt.rpm))
  put(x+2, y+5, "MaxRPM: " .. fmt1(tt.maxRpm))
  put(x+2, y+6, "Prod:   " .. fmt1(tt.prod))
  put(x+2, y+7, "MaxPrd: " .. fmt1(tt.maxProd))
  put(x+2, y+8, "Stored: " .. fmt1(tt.stored))
  put(x+2, y+9, "Cap:    " .. fmt1(tt.cap))
end

-- =========================================================
-- BLOCK X: DRAW ALL (layout mapping)
-- =========================================================
local function drawAll(data)
  clear()
  put(2, 1, CFG.title)

  -- Layout grob nach deinem Bild (müssen wir ggf. an Monitor-Resolution anpassen)
  drawReactorGrid(2, 3)
  drawReactorPanel(10, 3, 22, 16, data)
  drawTurbinePanel(34, 3, 22, 16, data)

  -- Später:
  -- drawMatrixPanel(...)
  -- drawGraph(...)
  -- drawButtons(...)
end

-- =========================================================
-- MAIN LOOP
-- =========================================================
while true do
  local data = readAll()
  drawAll(data)
  sleep(CFG.refresh)
end
