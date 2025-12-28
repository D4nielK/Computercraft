---@diagnostic disable: undefined-global

-- =========================================================
-- CONFIG (HIER ANPASSEN!)
-- =========================================================
local CFG = {
  LEFT_MONITOR  = "monitor_left",  -- ← HIER linker Monitor
  RIGHT_MONITOR = "monitor_right",  -- ← HIER rechter Monitor

  TEXT_SCALE_LEFT  = 1.0,
  TEXT_SCALE_RIGHT = 1.0,

  REFRESH = 0.5,

  REACTOR = "fissionReactorLogicAdapter_0",
}

-- =========================================================
-- PERIPHERALS
-- =========================================================
local monL = assert(peripheral.wrap(CFG.LEFT_MONITOR),  "Left monitor not found")
local monR = assert(peripheral.wrap(CFG.RIGHT_MONITOR), "Right monitor not found")
local r    = assert(peripheral.wrap(CFG.REACTOR), "Reactor not found")

monL.setTextScale(CFG.TEXT_SCALE_LEFT)
monR.setTextScale(CFG.TEXT_SCALE_RIGHT)

-- =========================================================
-- UI HELPERS (GLOBAL, STABIL)
-- =========================================================
function clear(m)
  local w,h = m.getSize()
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()
  m.setCursorPos(1,1)
end

function panel(m, x,y,w,h, title)
  m.setBackgroundColor(colors.white)
  m.setTextColor(colors.black)
  for yy=y, y+h-1 do
    m.setCursorPos(x,yy)
    m.write(string.rep(" ", w))
  end
  if title then
    m.setCursorPos(x+2, y+1)
    m.write(title)
  end
end

function write(m,x,y,t)
  m.setCursorPos(x,y)
  m.write(t)
end

-- =========================================================
-- LEFT MONITOR: STATS
-- =========================================================
function drawLeftStatic()
  clear(monL)
  local W,H = monL.getSize()

  write(monL, math.floor(W/2)-5, 1, "REACTOR")
  write(monL, math.floor(W/2)-5, 2, "========")

  panel(monL, 2,4, W-2, H-5, "Stats")

  write(monL, 4, 7,  "Status:")
  write(monL, 4, 9,  "Temp:")
  write(monL, 4, 11, "Burn:")
  write(monL, 4, 13, "Damage:")

  write(monL, 4, 16, "Coolant:")
  write(monL, 4, 17, "Fuel:")
  write(monL, 4, 18, "Heated:")
  write(monL, 4, 19, "Waste:")
end

function drawLeftDynamic()
  local function pct(v)
    if type(v)~="number" then return "?" end
    if v<=1.001 then v=v*100 end
    return string.format("%3.0f%%", v)
  end

  write(monL, 14, 7,  r.getStatus() and "ON " or "OFF")
  write(monL, 14, 9,  string.format("%4.0f K", r.getTemperature()))
  write(monL, 14, 11, string.format("%4.1f mB/t", r.getBurnRate()))
  write(monL, 14, 13, pct(r.getDamagePercent()))

  write(monL, 14, 16, pct(r.getCoolantFilledPercentage()))
  write(monL, 14, 17, pct(r.getFuelFilledPercentage()))
  write(monL, 14, 18, pct(r.getHeatedCoolantFilledPercentage()))
  write(monL, 14, 19, pct(r.getWasteFilledPercentage()))
end

-- =========================================================
-- RIGHT MONITOR: CONTROLS
-- =========================================================
local buttons = {}

function drawButton(id, x,y,w,h, label, bg)
  monR.setBackgroundColor(bg)
  monR.setTextColor(colors.black)
  for yy=y,y+h-1 do
    monR.setCursorPos(x,yy)
    monR.write(string.rep(" ", w))
  end
  monR.setCursorPos(x + math.floor((w-#label)/2), y + math.floor(h/2))
  monR.write(label)
  buttons[#buttons+1] = {id=id, x=x,y=y,w=w,h=h}
end

function drawRightStatic()
  clear(monR)
  local W,H = monR.getSize()

  write(monR, math.floor(W/2)-6, 1, "CONTROLS")
  write(monR, math.floor(W/2)-6, 2, "==========")

  panel(monR, 2,4, W-2, H-5, "Actions")

  buttons = {}
  local x = 4
  local w = W-8
  local y = 7
  local h = 4
  local g = 2

  drawButton("start", x,y,         w,h, "START", colors.green)
  drawButton("stop",  x,y+h+g,     w,h, "STOP",  colors.red)
  drawButton("scram", x,y+2*(h+g), w,h, "AZ-5",  colors.orange)
end

function hit(x,y)
  for _,b in ipairs(buttons) do
    if x>=b.x and x<b.x+b.w and y>=b.y and y<b.y+b.h then
      return b.id
    end
  end
end

function action(id)
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
  drawLeftDynamic()

  local e,side,x,y = os.pullEventTimeout("monitor_touch", CFG.REFRESH)
  if e=="monitor_touch" and side==CFG.RIGHT_MONITOR then
    local id = hit(x,y)
    if id then action(id) end
  end
end
