---@diagnostic disable: undefined-global

-- Peripherals
local r = peripheral.find("fissionReactorLogicAdapter")
if not r then error("Kein Fission Reactor Logic Adapter!") end

local mon = peripheral.find("monitor")
if not mon then error("Kein Monitor gefunden!") end

mon.setTextScale(0.5)
mon.clear()

local MAX_TEMP = 1200
local ALARM_SIDE = "right"

-- Button-Definitionen
local buttons = {
  start = {x1=3,  y1=7, x2=14, y2=9,  label="START"},
  stop  = {x1=18, y1=7, x2=29, y2=9,  label="STOP"},
  scram = {x1=3,  y1=11,x2=29, y2=13, label="SCRAM"}
}

local function inBox(x,y,b)
  return x>=b.x1 and x<=b.x2 and y>=b.y1 and y<=b.y2
end

local function drawBox(b)
  for y=b.y1,b.y2 do
    mon.setCursorPos(b.x1,y)
    mon.write(string.rep(" ", b.x2-b.x1+1))
  end
  local cx = math.floor((b.x1+b.x2-#b.label)/2)
  local cy = math.floor((b.y1+b.y2)/2)
  mon.setCursorPos(cx,cy)
  mon.write(b.label)
end

local function draw()
  mon.clear()
  mon.setCursorPos(2,1)
  mon.write("MEKANISM FISSION REACTOR")

  local status = r.getStatus()
  local temp   = r.getTemperature()

  local fuelP  = r.getFuelFilledPercentage()
  local wasteP = r.getWasteFilledPercentage()
  local coolP  = r.getHeatedCoolantFilledPercentage()

  local hot = temp > MAX_TEMP
  redstone.setOutput(ALARM_SIDE, hot)

  mon.setCursorPos(2,3)
  mon.write("Status: "..(status and "ACTIVE" or "OFF"))
  mon.setCursorPos(2,4)
  mon.write("Temp:   "..math.floor(temp).." K")

  mon.setCursorPos(2,15)
  mon.write(string.format("Fuel:   %.1f %%", fuelP))
  mon.setCursorPos(2,16)
  mon.write(string.format("Waste:  %.1f %%", wasteP))
  mon.setCursorPos(2,17)
  mon.write(string.format("Coolant:%.1f %%", coolP))

  drawBox(buttons.start)
  drawBox(buttons.stop)
  drawBox(buttons.scram)
end

-- Main loop
while true do
  draw()

  local event, side, x, y = os.pullEvent("monitor_touch")

  if inBox(x,y,buttons.start) then
    r.setLogicMode("ACTIVATION")
  elseif inBox(x,y,buttons.stop) then
    r.setLogicMode("DISABLED")
  elseif inBox(x,y,buttons.scram) then
    r.scram()
  end
end
