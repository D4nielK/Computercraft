---@diagnostic disable: undefined-global

-- =========================
-- BLOCK 0: CONFIG + LAYOUT + UTILS
-- =========================

local CFG = {
  title = "Cherenkov",
  monitorScale = 0.5,
  refresh = 0.25,

  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",
}

local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)

local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

local W, H = mon.getSize() -- bei dir: 121, 81

-- Layout (an dein Bild angelehnt, jederzeit anpassbar)
local L = {
  title = {x=2,  y=1},

  -- links oben: Grid
  grid  = {x=2,  y=3,  w=22, h=14},

  -- daneben: Reaktor Panel
  reactor = {x=25, y=3,  w=46, h=32},

  -- rechts oben: Turbine Panel
  turbine = {x=72, y=3,  w=48, h=24},

  -- rechts mitte: Matrix Panel (später)
  matrix  = {x=72, y=28, w=48, h=16},

  -- unten: Graph
  graph   = {x=25, y=36, w=95, h=20},

  -- links unten: Buttons / Mini-Panel
  buttons = {x=2,  y=18, w=22, h=38},
}

local function clear()
  mon.setCursorPos(1,1)
  mon.clear()
end

local function put(x, y, s)
  mon.setCursorPos(x, y)
  mon.write(s)
end

local function hline(x, y, w, ch)
  put(x, y, string.rep(ch, w))
end

local function box(a, title)
  -- Rahmen
  put(a.x, a.y, "+" .. string.rep("-", a.w-2) .. "+")
  for yy = a.y+1, a.y+a.h-2 do
    put(a.x, yy, "|")
    put(a.x+a.w-1, yy, "|")
  end
  put(a.x, a.y+a.h-1, "+" .. string.rep("-", a.w-2) .. "+")

  -- Titel im Rahmen
  if title and #title > 0 then
    put(a.x+2, a.y, title)
  end
end
