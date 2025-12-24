---@diagnostic disable: undefined-global

local r = peripheral.find("fissionReactorLogicAdapter")
if not r then error("Kein Fission Reactor Logic Adapter gefunden!") end

local MAX_TEMP = 1200
local ALARM_SIDE = "right"

local function cls()
  term.setCursorPos(1,1)
  term.clear()
end

local function pct(x)
  if type(x) ~= "number" then return "?" end
  return string.format("%.1f%%", x)
end

while true do
  local status = r.getStatus()
  local temp   = r.getTemperature()
  local burn   = r.getMaxBurnRate() > 0 and r.getMaxBurnRate() or "?"

  local fuelP  = r.getFuelFilledPercentage()
  local wasteP = r.getWasteFilledPercentage()
  local coolP  = r.getHeatedCoolantFilledPercentage()

  local hot = temp > MAX_TEMP
  redstone.setOutput(ALARM_SIDE, hot)

  cls()
  print("== Mekanism Fission Reactor ==")
  print("")
  print("Status:      "..(status and "ACTIVE" or "OFF"))
  print("Temp:        "..math.floor(temp).." K")
  print("Burn Max:    "..burn)
  print("")
  print("Fuel:        "..pct(fuelP))
  print("Waste:       "..pct(wasteP))
  print("Coolant:     "..pct(coolP))
  print("")
  print("Alarm:       "..(hot and "ON" or "off"))
  print("")
  print("[S] Start   [X] Stop   [K] SCRAM")
  print("[+] Burn +0.1   [-] Burn -0.1")
  print("[Q] Quit")

  local e, key = os.pullEventTimeout("key", 0.5)
  if e == "key" then
    local k = keys.getName(key)

    if k == "q" then break end

    if k == "s" then
      r.setLogicMode("ACTIVATION")
    elseif k == "x" then
      r.setLogicMode("DISABLED")
    elseif k == "k" then
      r.scram()
    elseif k == "equals" or k == "plus" then
      local new = math.min(r.getMaxBurnRate(), (r.getMaxBurnRate() or 0) + 0.1)
      r.setBurnRate(new)
    elseif k == "minus" then
      local new = math.max(0, (r.getMaxBurnRate() or 0) - 0.1)
      r.setBurnRate(new)
    end
  end
end

cls()
redstone.setOutput(ALARM_SIDE, false)
print("Controller stopped.")
