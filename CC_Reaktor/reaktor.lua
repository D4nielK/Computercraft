---@diagnostic disable: undefined-global

local r = peripheral.find("fissionReactorLogicAdapter")
if not r then error("Kein Fission Reactor Logic Adapter gefunden!") end

local MAX_TEMP = 1200
local ALARM_SIDE = "right"

local burnRate = 0

local function cls()
  term.setCursorPos(1,1)
  term.clear()
end

local function pct(x)
  if type(x) ~= "number" then return "?" end
  return string.format("%.1f%%", x)
end

local function draw()
  local status = r.getStatus()
  local temp   = r.getTemperature()

  local fuelP  = r.getFuelFilledPercentage()
  local wasteP = r.getWasteFilledPercentage()
  local coolP  = r.getHeatedCoolantFilledPercentage()

  local hot = (type(temp)=="number") and temp > MAX_TEMP
  redstone.setOutput(ALARM_SIDE, hot)

  cls()
  print("== Mekanism Fission Reactor ==")
  print("")
  print("Status:      "..(status and "ACTIVE" or "OFF"))
  print("Temp:        "..math.floor(temp).." K  (max "..MAX_TEMP..")")
  print("BurnRate:    "..string.format("%.2f", burnRate))
  print("")
  print("Fuel:        "..pct(fuelP))
  print("Waste:       "..pct(wasteP))
  print("Coolant:     "..pct(coolP))
  print("")
  print("Alarm:       "..(hot and "ON" or "off").." ("..ALARM_SIDE..")")
  print("")
  print("[S] Start   [X] Stop   [K] SCRAM")
  print("[+] Burn +0.1   [-] Burn -0.1")
  print("[Q] Quit")
end

-- initial burnRate aus dem Reaktor holen, falls möglich
do
  local ok, max = pcall(r.getMaxBurnRate)
  if ok and type(max) == "number" then burnRate = math.min(1, max) end
end

while true do
  draw()

  local timer = os.startTimer(0.5)
  local pressedKey = nil

  while true do
    local ev, p1 = os.pullEvent()
    if ev == "key" then
      pressedKey = keys.getName(p1)
      break
    elseif ev == "timer" and p1 == timer then
      break
    end
  end

  if pressedKey then
    if pressedKey == "q" then break end

    if pressedKey == "s" then
      r.setLogicMode("ACTIVATION")
    elseif pressedKey == "x" then
      r.setLogicMode("DISABLED")
    elseif pressedKey == "k" then
      r.scram()
    elseif pressedKey == "equals" or pressedKey == "plus" then
      burnRate = burnRate + 0.1
      local max = r.getMaxBurnRate()
      if type(max) == "number" then burnRate = math.min(burnRate, max) end
      r.setBurnRate(burnRate)
    elseif pressedKey == "minus" then
      burnRate = math.max(0, burnRate - 0.1)
      r.setBurnRate(burnRate)
    end
  end
end

cls()
redstone.setOutput(ALARM_SIDE, false)
print("Controller stopped.")
