---@diagnostic disable: undefined-global

-- =========================================================
-- BLOCK 0: SETUP + UTILS (Farben, Rechtecke, Labels)
-- =========================================================

local CFG = {
  title = "Cherenkov",
  monitorScale = 0.5,
  refresh = 0.2,
  reactor = "fissionReactorLogicAdapter_0",
  turbine = "turbineValve_0",
  manualMap = {
  ["2:2"] = "x",
  ["4:2"] = "x",
  ["3:3"] = "x",
  ["2:4"] = "x",
  ["4:4"] = "x",
  ["3:2"] = "o",
  ["2:3"] = "o",
  ["4:3"] = "o",
  ["3:4"] = "o",
},

}


local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

local r = assert(peripheral.wrap(CFG.reactor), "Reaktor nicht gefunden: "..CFG.reactor)
local t = assert(peripheral.wrap(CFG.turbine), "Turbine nicht gefunden: "..CFG.turbine)


local SW, SH = mon.getSize() -- bei dir: 121 x 81

local function bg(c) if mon.setBackgroundColor then mon.setBackgroundColor(c) end end
local function fg(c) if mon.setTextColor then mon.setTextColor(c) end end

local function put(x, y, s)
  mon.setCursorPos(x, y)
  mon.write(s)
end

local function fillRect(x, y, w, h, bgCol)
  bg(bgCol)
  for yy = y, y + h - 1 do
    mon.setCursorPos(x, yy)
    mon.write(string.rep(" ", w))
  end
end

-- "Panel" mit weißer Fläche + optionaler dünner Rand (später verschönern)
local function panel(a, title)
  -- weiße Fläche
  fillRect(a.x, a.y, a.w, a.h, colors.white)

  -- Textfarbe schwarz
  fg(colors.black)

  -- einfacher Rand (optional, kann später weg/anders)
  -- wir zeichnen KEINE "------" Linien als Inhalt, nur einen dünnen Rahmen
  bg(colors.white)
  put(a.x, a.y, string.rep(" ", a.w))
  put(a.x, a.y + a.h - 1, string.rep(" ", a.w))
  for yy = a.y, a.y + a.h - 1 do
    put(a.x, yy, " ")
    put(a.x + a.w - 1, yy, " ")
  end

  -- Titel
  if title and #title > 0 then
    put(a.x + 2, a.y + 1, title)
  end
end

-- dunkler Hintergrund für den Gesamtscreen
local function clearScreen()
  bg(colors.black); fg(colors.white)
  fillRect(1, 1, SW, SH, colors.black)
end

-- =========================================================
-- LAYOUT: Bereiche grob nach deinem Bild (A–G)
-- =========================================================
local L = {
  -- Kopf
  title = { x = 2, y = 1 },

  -- A: Reaktor-Aufbau (Schachbrett / Grid)
  A_grid = { x = 2,  y = 4,  w = 22, h = 16 },

  -- D: Reaktor-Anzeige Balken (C/F/H/W)
  D_bars = { x = 2,  y = 21, w = 22, h = 18 },

  -- F: Knöpfe
  F_buttons = { x = 2, y = 40, w = 22, h = 16 },

  -- B: Reaktor Stats/Settings (großes Panel)
  B_reactor = { x = 26, y = 4, w = 46, h = 52 },

  -- C: Turbine Stats
  C_turbine = { x = 74, y = 4, w = 46, h = 24 },

  -- E: Induction Matrix
  E_matrix  = { x = 74, y = 29, w = 46, h = 27 },

  -- G: Graph unten (unter Reaktor/Turbine)
  G_graph   = { x = 26, y = 58, w = 94, h = 20 },
}

-- =========================================================
-- BLOCK A: Reactor Layout LIVE (Size + manuelle Marker)
-- =========================================================

local function drawCell(x, y, mark)
  -- Hintergrund weiß, Standardtext schwarz
  bg(colors.white)

  -- "["
  fg(colors.black)
  put(x, y, "[")

  -- mark in Farbe
  if mark == "x" then
    fg(colors.green)
    put(x+1, y, "x")
  elseif mark == "o" then
    fg(colors.blue)
    put(x+1, y, "o")
  else
    fg(colors.black)
    put(x+1, y, " ")
  end

  -- "]"
  fg(colors.black)
  put(x+2, y, "]")
end

local function drawBlockA()
  panel(L.A_grid, "Reactor Layout")

  local x0 = L.A_grid.x + 2
  local y0 = L.A_grid.y + 3
  fg(colors.black)

  -- formed check (optional, aber hilfreich)
  local formed = r.isFormed and r.isFormed() or false
  put(x0, y0, "Formed: " .. tostring(formed))
  if not formed then
    put(x0, y0+1, "Reactor not formed!")
    return
  end

  -- Größe
  local rw = r.getWidth()
  local rl = r.getLength()
  local rh = r.getHeight()
  put(x0, y0+1, ("Size: %dx%dx%d"):format(rw, rl, rh))
  put(x0, y0+2, "Legend: x=Fuel, o=Water")

  -- Grid-Bereich (innen)
  local gx = L.A_grid.x + 2
  local gy = L.A_grid.y + 6

  local cellW = 3
  local gw = L.A_grid.w - 4
  local gh = L.A_grid.h - 8

  local maxCols = math.max(1, math.floor(gw / cellW))
  local maxRows = math.max(1, gh)

  -- Downsample, falls Reaktor größer als Panel
  local stepX = math.max(1, math.ceil(rw / maxCols))
  local stepY = math.max(1, math.ceil(rl / maxRows))

  local cols = math.min(maxCols, math.ceil(rw / stepX))
  local rows = math.min(maxRows, math.ceil(rl / stepY))

  -- Hinweis, falls gesampelt wird
  if stepX > 1 or stepY > 1 then
    fg(colors.black)
    put(x0, y0+3, ("Scaled: step %dx%d"):format(stepX, stepY))
  end

  -- Zeichnen
  for sy = 0, rows - 1 do
    for sx = 0, cols - 1 do
      local rx = 1 + sx * stepX
      local rz = 1 + sy * stepY
      local key = rx .. ":" .. rz

      local mark = CFG.manualMap and CFG.manualMap[key] or nil
      drawCell(gx + sx*cellW, gy + sy, mark)
    end
  end
end

-- =========================================================
-- BLOCK B: Reaktor (Stats + Settings) – nur Rahmen & Labels
-- =========================================================
local function drawBlockB()
  panel(L.B_reactor, "Reaktor")

  local x = L.B_reactor.x + 2
  local y = L.B_reactor.y + 3

  fg(colors.black)
  put(x, y,     "Stats:")
  put(x, y+2,   "Status: Aktiv/Deaktiv")
  put(x, y+4,   "Coolant: .../max")
  put(x, y+5,   "Fissile Fuel: .../max")
  put(x, y+6,   "Heated Coolant: .../max")
  put(x, y+7,   "Waste: .../max")
  put(x, y+9,   "Max Burnrate: ... mb/t")
  put(x, y+10,  "Burnrate: ... mb/t")
  put(x, y+11,  "Heating rate: ...")
  put(x, y+12,  "Temperature: ... K")
  put(x, y+13,  "Damage: ... %")

  -- Settings Bereich (unten)
  local sy = L.B_reactor.y + 30
  put(x, sy,     "Settings (Alarm):")
  put(x, sy+2,   "Burnrate set: ... mb/t")
  put(x, sy+3,   "Max Temperature: ... K")
  put(x, sy+4,   "Max Waste: ... %")
  put(x, sy+5,   "Max Heated Coolant: ... %")
  put(x, sy+6,   "Min Coolant: ... %")
  put(x, sy+7,   "Min Fuel: ... %")
end

-- =========================================================
-- BLOCK C: Turbine (Stats) – nur Labels
-- =========================================================
local function drawBlockC()
  panel(L.C_turbine, "Turbine")

  local x = L.C_turbine.x + 2
  local y = L.C_turbine.y + 3

  fg(colors.black)
  put(x, y,     "Stats:")
  put(x, y+2,   "Status: Aktiv/Deaktiv")
  put(x, y+4,   "Steam: .../max")
  put(x, y+5,   "Steam In: ... mB/t")
  put(x, y+7,   "Energy Stored: .../max")
  put(x, y+8,   "Production: ... FE/t")
  put(x, y+9,   "Max Production: ... FE/t")
end

-- =========================================================
-- BLOCK D: Visuelle Balkenanzeige (C/F/H/W) – nur Platzhalter
-- =========================================================
local function drawBlockD()
  panel(L.D_bars, "Reactor Levels")

  local x = L.D_bars.x + 2
  local y = L.D_bars.y + 4

  fg(colors.black)
  put(x, y-2, "C   F   H   W")

  -- 4 Balken-Container
  for i = 0, 3 do
    local bx = x + i*5
    local by = y
    -- Rahmen
    bg(colors.lightGray); fg(colors.black)
    for h = 0, 10 do
      put(bx, by + h, "   ")
    end
    -- "Füllung" (Dummy)
    bg(colors.green)
    for h = 7, 10 do
      put(bx, by + h, "   ")
    end
    bg(colors.white); fg(colors.black)
  end
end

-- =========================================================
-- BLOCK E: Induction Matrix – nur Labels
-- =========================================================
local function drawBlockE()
  panel(L.E_matrix, "Induction Matrix")

  local x = L.E_matrix.x + 2
  local y = L.E_matrix.y + 3

  fg(colors.black)
  put(x, y,     "Max Energy: ... FE")
  put(x, y+2,   "Stored Energy: ... FE")
  put(x, y+4,   "Input: ... FE/t")
  put(x, y+5,   "Output: ... FE/t")
  put(x, y+7,   "Change: ... (In - Out)")
end

-- =========================================================
-- BLOCK F: Buttons – nur visuell (noch keine Touch-Logik)
-- =========================================================
local function drawButton(x, y, w, label)
  bg(colors.gray); fg(colors.white)
  put(x, y, string.rep(" ", w))
  put(x, y+1, string.rep(" ", w))
  put(x + 2, y+1, label)
  bg(colors.white); fg(colors.black)
end

local function drawBlockF()
  panel(L.F_buttons, "Controls")

  local x = L.F_buttons.x + 2
  local y = L.F_buttons.y + 4

  drawButton(x,     y,   8, "Start")
  drawButton(x+10,  y,   8, "Stop")
  drawButton(x,     y+4, 8, "AZ5")
  drawButton(x+10,  y+4, 8, "Test")
end

-- =========================================================
-- BLOCK G: Graph – nur Rahmen + Achsen-Label
-- =========================================================
local function drawBlockG()
  panel(L.G_graph, "Temperatur Graph")

  local x = L.G_graph.x + 2
  local y = L.G_graph.y + 4

  fg(colors.black)
  put(x, y,     "T (K)")
  put(x, y+12,  "t (s)")
  -- Platzhalter-Linie
  fg(colors.gray)
  put(x+6, y+8,  ". . . . . . . . . . . . .")
  fg(colors.black)
end

-- =========================================================
-- DRAW ALL: A–G (nur Layout)
-- =========================================================
local function drawAllLayout()
  clearScreen()

  -- Titel mittig (grob)
  fg(colors.white); bg(colors.black)
  put(math.floor(SW/2) - math.floor(#CFG.title/2), 2, CFG.title)

  drawBlockA()
  drawBlockB()
  drawBlockC()
  drawBlockD()
  drawBlockE()
  drawBlockF()
  drawBlockG()
end

-- =========================================================
-- MAIN: nur Layout anzeigen
-- =========================================================
while true do
  drawAllLayout()
  sleep(1) -- Layout muss nicht schnell refreshen
end
