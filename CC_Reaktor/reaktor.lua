---@diagnostic disable: undefined-global

-- =========================================================
-- CONFIG
-- =========================================================
local CFG = {
  leftIndex  = 2,    -- <-- anpassen: Nummer vom linken Monitor
  rightIndex = 1,    -- <-- anpassen: Nummer vom rechten Monitor

  scaleLeft  = 1.0,
  scaleRight = 1.0,

  refresh = 0.5,

  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",

  -- Reactor Layout: manuelle Marker
  manualMap = {
    ["2:2"]="x", ["4:2"]="x", ["3:3"]="x", ["2:4"]="x", ["4:4"]="x",
    ["3:2"]="o", ["2:3"]="o", ["4:3"]="o", ["3:4"]="o",
  },
}

-- =========================================================
-- PERIPHERALS
-- =========================================================
local allMons = { peripheral.find("monitor") }
assert(#allMons >= 2, "Need 2 monitors attached to this computer!")

local monL = assert(allMons[CFG.leftIndex],  "Left monitor index invalid")
local monR = assert(allMons[CFG.rightIndex], "Right monitor index invalid")

monL.setTextScale(CFG.scaleLeft)
monR.setTextScale(CFG.scaleRight)

local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)

-- =========================================================
-- UI HELPERS (monitor-agnostic)
-- =========================================================
local function bg(m,c) m.setBackgroundColor(c) end
local function fg(m,c) m.setTextColor(c) end
local function put(m,x,y,s) m.setCursorPos(x,y); m.write(s) end
local function fillRect(m,x,y,w,h,col)
  bg(m,col)
  for yy=y, y+h-1 do
    m.setCursorPos(x,yy)
    m.write(string.rep(" ", w))
  end
end
local function clearScreen(m)
  local w,h = m.getSize()
  bg(m, colors.black); fg(m, colors.white)
  fillRect(m, 1,1, w,h, colors.black)
end
local function panel(m, a, title)
  fillRect(m, a.x, a.y, a.w, a.h, colors.white)
  bg(m, colors.white); fg(m, colors.black)
  if title and #title>0 then put(m, a.x+2, a.y+1, title) end
end
local function writeLine(m, x, y, text, width)
  bg(m, colors.white); fg(m, colors.black)
  m.setCursorPos(x,y)
  local s = tostring(text)
  if width then
    if #s > width then s = s:sub(1,width) end
    m.write(s .. string.rep(" ", math.max(0, width-#s)))
  else
    m.write(s)
  end
end
local function clamp01(x)
  if type(x)~="number" then return 0 end
  if x<0 then return 0 end
  if x>1 then return 1 end
  return x
end
local function to01(p)
  if type(p)~="number" then return 0 end
  if p>1.001 then return clamp01(p/100) end
  return clamp01(p)
end
local function fmt0(n) return (type(n)=="number") and string.format("%.0f",n) or "?" end
local function fmt1(n) return (type(n)=="number") and string.format("%.1f",n) or "?" end
local function fmtPct(n)
  if type(n)~="number" then return "?" end
  if n<=1.001 then n=n*100 end
  return string.format("%.0f%%", n)
end

-- =========================================================
-- LEFT MONITOR LAYOUT (Stats)
-- =========================================================
local function buildLeftLayout(m)
  local W,H = m.getSize()

  -- Linker Monitor: viele kleine Blöcke
  -- Wir machen: Layout oben links, Levels darunter, rechts daneben Stats, unten Turbine+Matrix kompakt.
  local L = {}

  L.title = { x=2, y=1, w=W-2, h=3 }

  L.A = { x=2, y=4,  w=math.floor(W*0.45), h=16 }                 -- Reactor Layout
  L.D = { x=2, y=21, w=math.floor(W*0.45), h=18 }                 -- Reactor Levels

  L.B = { x=L.A.x + L.A.w + 2, y=4, w=W-(L.A.x+L.A.w+2)-1, h=35 }  -- Reactor Stats rechts

  L.C = { x=2, y=40, w=math.floor(W*0.5), h=H-41 }                 -- Turbine unten links
  L.E = { x=L.C.x+L.C.w+2, y=40, w=W-(L.C.x+L.C.w+2)-1, h=H-41 }   -- Matrix unten rechts

  return L
end

local function drawCell(m,x,y,mark)
  bg(m, colors.white)
  fg(m, colors.black); put(m,x,y,"[")
  if mark=="x" then fg(m, colors.green); put(m,x+1,y,"x")
  elseif mark=="o" then fg(m, colors.blue); put(m,x+1,y,"o")
  else fg(m, colors.black); put(m,x+1,y," ")
  end
  fg(m, colors.black); put(m,x+2,y,"]")
end

local function drawBar(m,x,y,w,h,frac01,fillColor,label)
  bg(m, colors.lightGray); fg(m, colors.black)
  for yy=0,h-1 do put(m,x,y+yy,string.rep(" ",w)) end
  local fillH = math.floor(frac01*h + 0.5)
  if fillH>h then fillH=h end
  bg(m, fillColor)
  for yy=0,fillH-1 do put(m,x, y+(h-1-yy), string.rep(" ", w)) end
  bg(m, colors.white); fg(m, colors.black)
  put(m,x, y-1, label)
end

local function drawLeftStatic(L)
  clearScreen(monL)
  local W,_ = monL.getSize()

  -- Titel
  fg(monL, colors.white); bg(monL, colors.black)
  local title = "STATUS"
  put(monL, math.floor(W/2)-math.floor(#title/2), 2, title)
  put(monL, math.floor(W/2)-math.floor(#title/2), 3, string.rep("=", #title))

  panel(monL, L.A, "Reactor Layout")
  panel(monL, L.D, "Reactor Levels")
  panel(monL, L.B, "Reactor Stats")
  panel(monL, L.C, "Turbine")
  panel(monL, L.E, "Matrix")

  -- Block B Labels (statisch)
  local x = L.B.x+2
  local y = L.B.y+3
  bg(monL, colors.white); fg(monL, colors.black)
  put(monL, x, y,     "Status:")
  put(monL, x, y+2,   "Temp:")
  put(monL, x, y+3,   "Burn:")
  put(monL, x, y+4,   "Damage:")
  put(monL, x, y+6,   "Coolant:")
  put(monL, x, y+7,   "Fuel:")
  put(monL, x, y+8,   "Heated:")
  put(monL, x, y+9,   "Waste:")

  -- Turbine labels
  local tx = L.C.x+2
  local ty = L.C.y+3
  put(monL, tx, ty,     "Active:")
  put(monL, tx, ty+2,   "Steam:")
  put(monL, tx, ty+3,   "Energy:")
  put(monL, tx, ty+4,   "Prod:")

  -- Matrix labels
  local mx = L.E.x+2
  local my = L.E.y+3
  put(monL, mx, my,     "Stored:")
  put(monL, mx, my+2,   "Input:")
  put(monL, mx, my+3,   "Output:")
end

local function drawLeftOnce_ReactorLayout(L)
  -- einmalig (damit kein Flackern): Layout+Size+Grid
  fillRect(monL, L.A.x+1, L.A.y+2, L.A.w-2, L.A.h-3, colors.white)
  local x0 = L.A.x+2
  local y0 = L.A.y+3
  bg(monL, colors.white); fg(monL, colors.black)

  local formed = (r.isFormed and r.isFormed()) or false
  put(monL, x0, y0, "Formed: "..tostring(formed))
  if not formed then
    put(monL, x0, y0+1, "Not formed!")
    return
  end

  local rw, rl, rh = r.getWidth(), r.getLength(), r.getHeight()
  put(monL, x0, y0+1, ("Size: %dx%dx%d"):format(rw, rl, rh))
  put(monL, x0, y0+2, "x=Fuel")
  put(monL, x0, y0+3, "o=Water")

  local gx = L.A.x+2
  local gy = L.A.y+6

  local cellW = 3
  local gw = L.A.w - 4
  local gh = L.A.h - 8

  local maxCols = math.max(1, math.floor(gw / cellW))
  local maxRows = math.max(1, gh)

  local stepX = math.max(1, math.ceil(rw / maxCols))
  local stepY = math.max(1, math.ceil(rl / maxRows))

  local cols = math.min(maxCols, math.ceil(rw / stepX))
  local rows = math.min(maxRows, math.ceil(rl / stepY))

  for sy=0, rows-1 do
    for sx=0, cols-1 do
      local rx = 1 + sx*stepX
      local rz = 1 + sy*stepY
      local key = rx..":"..rz
      drawCell(monL, gx + sx*cellW, gy + sy, CFG.manualMap[key])
    end
  end
end

local function drawLeftDynamic(L)
  -- Reactor Levels
  local x0 = L.D.x + 2
  local y0 = L.D.y + 4
  local barH = L.D.h - 7
  local barW, gap = 2, 2

  local c = to01(r.getCoolantFilledPercentage())
  local f = to01(r.getFuelFilledPercentage())
  local h = to01(r.getHeatedCoolantFilledPercentage())
  local w = to01(r.getWasteFilledPercentage())

  drawBar(monL, x0 + 0*(barW+gap), y0, barW, barH, c, colors.blue, "C")
  drawBar(monL, x0 + 1*(barW+gap), y0, barW, barH, f, colors.green,"F")
  drawBar(monL, x0 + 2*(barW+gap), y0, barW, barH, h, colors.gray, "H")
  drawBar(monL, x0 + 3*(barW+gap), y0, barW, barH, w, colors.lime, "W")

  bg(monL, colors.white); fg(monL, colors.black)
  put(monL, L.D.x+1, L.D.y + L.D.h - 2,
    ("C%3d F%3d H%3d W%3d"):format(
      math.floor(c*100+0.5), math.floor(f*100+0.5),
      math.floor(h*100+0.5), math.floor(w*100+0.5)
    )
  )

  -- Reactor Stats values
  local bx = L.B.x+2
  local by = L.B.y+3
  local bw = L.B.w-4

  writeLine(monL, bx+10, by,     (r.getStatus() and "ON" or "OFF"), bw-10)
  writeLine(monL, bx+10, by+2,   fmt0(r.getTemperature()).." K",   bw-10)
  writeLine(monL, bx+10, by+3,   fmt1(r.getBurnRate()).." mB/t",   bw-10)
  writeLine(monL, bx+10, by+4,   fmtPct(r.getDamagePercent()),     bw-10)

  writeLine(monL, bx+10, by+6,   fmtPct(r.getCoolantFilledPercentage()),       bw-10)
  writeLine(monL, bx+10, by+7,   fmtPct(r.getFuelFilledPercentage()),          bw-10)
  writeLine(monL, bx+10, by+8,   fmtPct(r.getHeatedCoolantFilledPercentage()), bw-10)
  writeLine(monL, bx+10, by+9,   fmtPct(r.getWasteFilledPercentage()),         bw-10)

  -- Turbine (kompakt) – erstmal best-effort: wenn Methoden fehlen, zeigt "?"
  local tx = L.C.x+2
  local ty = L.C.y+3
  local function safe(obj, fn)
    if not obj or type(obj[fn])~="function" then return nil end
    local ok,res = pcall(obj[fn], obj)
    if ok then return res end
    return nil
  end

  writeLine(monL, tx+9, ty,   tostring(safe(t,"getActive")), L.C.w-11)
  writeLine(monL, tx+9, ty+2, fmtPct(safe(t,"getSteamFilledPercentage")), L.C.w-11)
  writeLine(monL, tx+9, ty+3, tostring(safe(t,"getEnergyStored")), L.C.w-11)
  writeLine(monL, tx+9, ty+4, tostring(safe(t,"getProductionRate")), L.C.w-11)

  -- Matrix placeholder: (wenn du später matrix-peripheral hast, tragen wir die Methoden ein)
  local mx = L.E.x+2
  local my = L.E.y+3
  writeLine(monL, mx+9, my,   "TODO", L.E.w-11)
  writeLine(monL, mx+9, my+2, "TODO", L.E.w-11)
  writeLine(monL, mx+9, my+3, "TODO", L.E.w-11)
end

-- =========================================================
-- RIGHT MONITOR (Controls)
-- =========================================================
local function buildRightLayout(m)
  local W,H = m.getSize()
  return {
    title = {x=2,y=1,w=W-2,h=3},
    btn   = {x=2,y=4,w=W-2,h=H-4},
  }
end

local function drawButton(m, x,y,w,h,label, fillCol, textCol)
  bg(m, fillCol); fg(m, textCol)
  for yy=0,h-1 do
    put(m, x, y+yy, string.rep(" ", w))
  end
  local lx = x + math.max(1, math.floor((w-#label)/2))
  local ly = y + math.floor(h/2)
  put(m, lx, ly, label)
end

local Buttons = {} -- hitboxes

local function drawRightStatic(RL)
  clearScreen(monR)
  local W,_ = monR.getSize()

  fg(monR, colors.white); bg(monR, colors.black)
  local title = "CONTROLS"
  put(monR, math.floor(W/2)-math.floor(#title/2), 2, title)
  put(monR, math.floor(W/2)-math.floor(#title/2), 3, string.rep("=", #title))

  panel(monR, RL.btn, "Actions")

  -- Buttons groß & gut klickbar
  local x = RL.btn.x+2
  local y = RL.btn.y+3
  local w = RL.btn.w-4
  local bh = 4
  local gap = 2

  Buttons = {
    {id="start", x=x, y=y,           w=w, h=bh},
    {id="stop",  x=x, y=y+bh+gap,    w=w, h=bh},
    {id="az5",   x=x, y=y+2*(bh+gap),w=w, h=bh},
    {id="test",  x=x, y=y+3*(bh+gap),w=w, h=bh},
  }

  drawButton(monR, Buttons[1].x, Buttons[1].y, Buttons[1].w, Buttons[1].h, "START", colors.green, colors.black)
  drawButton(monR, Buttons[2].x, Buttons[2].y, Buttons[2].w, Buttons[2].h, "STOP",  colors.red,   colors.white)
  drawButton(monR, Buttons[3].x, Buttons[3].y, Buttons[3].w, Buttons[3].h, "AZ-5",  colors.orange,colors.black)
  drawButton(monR, Buttons[4].x, Buttons[4].y, Buttons[4].w, Buttons[4].h, "TEST",  colors.gray,  colors.white)
end

local function hitButton(x,y)
  for _,b in ipairs(Buttons) do
    if x>=b.x and x<=(b.x+b.w-1) and y>=b.y and y<=(b.y+b.h-1) then
      return b.id
    end
  end
  return nil
end

local function flashStatus(msg)
  -- kleine Statuszeile oben im Controls monitor
  bg(monR, colors.black); fg(monR, colors.white)
  local W,_ = monR.getSize()
  put(monR, 2, 1, msg .. string.rep(" ", math.max(0, W-2-#msg)))
end

local function doAction(id)
  if id == "start" then
    -- TODO: hier kommt deine echte Start-Logik rein (LogicAdapter / Redstone)
    flashStatus("Start pressed")
  elseif id == "stop" then
    flashStatus("Stop pressed")
  elseif id == "az5" then
    -- SCRAM ist bei dir schon bekannt:
    if r.scram then pcall(r.scram, r) end
    flashStatus("AZ-5 / SCRAM!")
  elseif id == "test" then
    flashStatus("Test pressed")
  end
end

-- =========================================================
-- BOOT
-- =========================================================
local LL = buildLeftLayout(monL)
local RL = buildRightLayout(monR)

drawLeftStatic(LL)
drawRightStatic(RL)
drawLeftOnce_ReactorLayout(LL) -- Layout nur einmal

while true do
  -- Update links (Anzeige)
  drawLeftDynamic(LL)

  -- Touch rechts (Bedienung)
  local ev, side, x, y = os.pullEventTimeout("monitor_touch", CFG.refresh)
  if ev == "monitor_touch" then
    -- Wenn du zwei Monitore hast, kommt side meistens als "monitor_x" rein,
    -- bei wrap-Monitoren ist es manchmal nil. Wir prüfen einfach Hitbox:
    local id = hitButton(x,y)
    if id then doAction(id) end
  end
end
