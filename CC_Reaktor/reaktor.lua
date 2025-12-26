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

-- =========================
-- BLOCK 1: REACTOR GRID (schachbrett)
-- =========================

local function drawReactorGrid(area)
  box(area, "") -- nur Rahmen

  -- Reaktor Maße holen (Width/Length = Bodenfläche)
  local w = r.getWidth and r.getWidth() or 0
  local l = r.getLength and r.getLength() or 0
  local h = r.getHeight and r.getHeight() or 0

  -- Header
  put(area.x+2, area.y+1, "Reactor Size")
  put(area.x+2, area.y+2, ("W x L x H: %dx%dx%d"):format(w, l, h))

  -- Grid-Bereich in der Box (innen)
  local gx0 = area.x + 2
  local gy0 = area.y + 4
  local gw  = area.w - 4
  local gh  = area.h - 5

  -- Wenn Maße fehlen oder 0: placeholder
  if w <= 0 or l <= 0 then
    put(gx0, gy0, "No size data.")
    return
  end

  -- Wir mappen Reaktor-Feld (w×l) auf Bildschirm (gw×gh).
  -- Jeder Cell ist 1 Zeichen: '.' und ':' als Schachbrettmuster.
  -- Falls der Reaktor größer als der Platz ist, wird runtergesampelt.
  local sx = math.max(1, math.floor(w / gw + 0.999)) -- step in reactor coords
  local sy = math.max(1, math.floor(l / gh + 0.999))

  local drawW = math.min(gw, math.ceil(w / sx))
  local drawH = math.min(gh, math.ceil(l / sy))

  for yy = 0, drawH-1 do
    mon.setCursorPos(gx0, gy0 + yy)
    local row = {}
    for xx = 0, drawW-1 do
      -- Schachbrett je nach (xx+yy)
      row[#row+1] = ((xx + yy) % 2 == 0) and "." or ":"
    end
    mon.write(table.concat(row))
  end

  -- kleine Legende
  put(gx0, gy0 + drawH + 1, "Legend: ./: footprint")
end

-- =========================
-- MAIN (nur Testlayout)
-- =========================

while true do
  clear()
  put(L.title.x, L.title.y, CFG.title)

  drawReactorGrid(L.grid)
  -- Die anderen Panels bauen wir als nächste Blöcke:
  box(L.reactor, "Reaktor (Stats/Settings)")
  box(L.turbine, "Turbine")
  box(L.matrix,  "Induction Matrix")
  box(L.graph,   "Temperature Graph")
  box(L.buttons, "Controls")

  sleep(CFG.refresh)
end
