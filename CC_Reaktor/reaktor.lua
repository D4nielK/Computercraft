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
