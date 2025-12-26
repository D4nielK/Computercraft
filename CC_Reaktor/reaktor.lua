---@diagnostic disable: undefined-global

local CFG = {
  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0", -- ggf. anpassen!
  monitorScale = 0.5,
  refresh = 0.5,
}

local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)
local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")

mon.setTextScale(CFG.monitorScale)

local function readAll()
  return {
    reactor = {
      temp = r.getTemperature(),
      logic = r.getLogicMode(),
      fuelP = r.getFuelFilledPercentage(),
    }
  }
end

while true do
  local d = readAll()
  mon.clear()
  mon.setCursorPos(1,1); mon.write("Cherenkov (TEST)")
  mon.setCursorPos(1,3); mon.write("Temp: " .. tostring(d.reactor.temp))
  mon.setCursorPos(1,4); mon.write("Logic: " .. tostring(d.reactor.logic))
  mon.setCursorPos(1,5); mon.write(string.format("Fuel: %.1f%%", d.reactor.fuelP))
  sleep(CFG.refresh)
end
