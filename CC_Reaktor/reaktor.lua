---@diagnostic disable: undefined-global

-- ===== CFG =====
local CFG = {
  title = "Cherenkov",
  monitorScale = 0.5,
  refresh = 0.5,
  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0", -- anpassen, falls anders
}

-- ===== Error display (monitor-safe) =====
local function showError(err)
  local mon = peripheral and peripheral.find and peripheral.find("monitor") or nil
  if mon then
    pcall(function() mon.setTextScale(0.5) end)
    pcall(function() mon.clear() end)
    pcall(function() mon.setCursorPos(1,1) end)
    pcall(function() mon.write("SCRIPT ERROR:") end)
    pcall(function() mon.setCursorPos(1,2) end)
    pcall(function() mon.write(tostring(err)) end)
  end
  print("SCRIPT ERROR:", err)
end

-- ===== Peripherals =====
local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)

local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

-- ===== Utils =====
local function clear()
  mon.clear()
  mon.setCursorPos(1,1)
end

local function put(x,y,s)
  mon.setCursorPos(x,y)
  mon.write(s)
end

local function fmt0(x) return (type(x)=="number") and string.format("%.0f", x) or "?" end
local function fmtPct(x) return (type(x)=="number") and string.format("%.1f%%", x) or "?" end

local function safeCall(obj, fn, ...)
  local f = obj[fn]
  if type(f) ~= "function" then return nil end
  local ok, res = pcall(f, obj, ...)
  if ok then return res end
  return nil
end

-- =================================================
-- BLOCK A: readAll()  (MUSS vor main existieren!)
-- =================================================
local function readAll()
  return {
    reactor = {
      status = r.getStatus(),
      logic  = r.getLogicMode(),
      tempK  = r.getTemperature(),
      fuelP  = r.getFuelFilledPercentage(),
    },
    turbine = {
      active = safeCall(t, "getActive") or safeCall(t, "getStatus"),
      rpm    = safeCall(t, "getRotorSpeed") or safeCall(t, "getRPM"),
    }
  }
end

-- =================================================
-- BLOCK B: drawAll(data)
-- =================================================
local function drawAll(d)
  clear()
  put(2,1, CFG.title)
  put(2,3, "Reactor Temp: "..fmt0(d.reactor.tempK).." K")
  put(2,4, "Reactor Logic: "..tostring(d.reactor.logic))
  put(2,5, "Fuel: "..fmtPct(d.reactor.fuelP))
  put(2,7, "Turbine Active: "..tostring(d.turbine.active))
  put(2,8, "Turbine RPM: "..fmt0(d.turbine.rpm))
end

-- =================================================
-- MAIN LOOP
-- =================================================
while true do
  local ok, err = pcall(function()
    local d = readAll()
    drawAll(d)
  end)

  if not ok then
    showError(err)
    error(err)
  end

  sleep(CFG.refresh)
end
