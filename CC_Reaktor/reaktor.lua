---@diagnostic disable: undefined-global

-- =========================================================
-- BLOCK 0: SETUP + UTILS (Farben, Rechtecke, Labels)
-- =========================================================

local title = CFG.title 
local tx = math.floor(SW/2) - math.floor("Cherenkov"/2)

local mon = assert(peripheral.find("monitor"), "Kein Monitor gefunden")
mon.setTextScale(CFG.monitorScale)

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
-- BLOCK A: Reaktor-Aufbau (nur visuell Platzhalter)
-- =========================================================
local function drawBlockA()
  panel(L.A_grid, "Reactor Layout")

  -- kleines 5x5 Grid (Platzhalter)
  local gx = L.A_grid.x + 2
  local gy = L.A_grid.y + 3

  fg(colors.black)

  -- Kopfzeile "1 2 3 4 5"
  put(gx + 2, gy, "1 2 3 4 5")
  -- Links A–E
  put(gx, gy + 2, "A")
  put(gx, gy + 3, "B")
  put(gx, gy + 4, "C")
  put(gx, gy + 5, "D")
  put(gx, gy + 6, "E")

  -- Grid-Kästchen (nur visuell)
  for row = 1, 5 do
    for col = 1, 5 do
      put(gx + 2 + (col - 1) * 2, gy + 1 + row, "[]")
    end
  end

  -- ein paar "blaue Punkte" (später echte Daten)
  fg(colors.blue)
  put(gx + 2 + 2*2, gy + 1 + 2, "[]")
  put(gx + 2 + 1*2, gy + 1 + 4, "[]")
  put(gx + 2 + 3*2, gy + 1 + 4, "[]")
  fg(colors.black)
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
