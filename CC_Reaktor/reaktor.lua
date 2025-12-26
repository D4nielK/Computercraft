---@diagnostic disable: undefined-global

local CFG = {
  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",         -- <- anpassen an deinen scan.lua Output
  monitorScale = 0.5,
  refresh = 0.5,
  startBurnRate = 1.0,
}

local r = peripheral.wrap(CFG.reactor)
assert(r, "Reaktor peripheral nicht gefunden: "..CFG.reactor)

local t = peripheral.wrap(CFG.turbine)
assert(t, "Turbine peripheral nicht gefunden: "..CFG.turbine)

local mon = peripheral.find("monitor")
assert(mon, "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

local function readAll()
  return {
    reactor = {
      status = r.getStatus(),
      temp   = r.getTemperature(),
      fuelP  = r.getFuelFilledPercentage(),
      wasteP = r.getWasteFilledPercentage(),
      coolP  = r.getHeatedCoolantFilledPercentage(),
      heatRate = r.getHeatingRate(),
      maxBurn  = r.getMaxBurnRate(),
      logic    = r.getLogicMode(),
    },
    turbine = {
      active = t.getActive and t.getActive() or (t.getStatus and t.getStatus() or nil),
      rpm    = t.getRotorSpeed and t.getRotorSpeed() or nil,
    }
  }
end

mon.clear()
mon.setCursorPos(1,1)
mon.write("Cherenkov UI loaded!")
sleep(2)

local data = readAll()

mon.clear()
mon.setCursorPos(1,1)
mon.write("Reactor Temp: " .. tostring(data.reactor.temp))
mon.setCursorPos(1,2)
mon.write("Reactor Logic: " .. tostring(data.reactor.logic))
mon.setCursorPos(1,3)
mon.write("Fuel: " .. string.format("%.1f%%", data.reactor.fuelP))

while true do
  local d = readAll()
  mon.clear()
  mon.setCursorPos(1,1); mon.write("Cherenkov")
  mon.setCursorPos(1,3); mon.write("Temp: " .. tostring(d.reactor.temp))
  mon.setCursorPos(1,4); mon.write("Logic: " .. tostring(d.reactor.logic))
  mon.setCursorPos(1,5); mon.write(string.format("Fuel: %.1f%%", d.reactor.fuelP))
  sleep(CFG.refresh)
end
