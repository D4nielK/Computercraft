---@diagnostic disable: undefined-global

local function showError(err)
  -- versuche Monitor zu finden, egal wo wir gerade craschen
  local mon = peripheral and peripheral.find and peripheral.find("monitor") or nil
  if mon then
    pcall(function() mon.setTextScale(0.5) end)
    pcall(function() mon.clear() end)
    pcall(function() mon.setCursorPos(1,1) end)
    pcall(function() mon.write("SCRIPT ERROR:") end)
    pcall(function() mon.setCursorPos(1,2) end)
    pcall(function() mon.write(tostring(err)) end)
  end

  -- immer auch im Terminal ausgeben
  print("SCRIPT ERROR:", err)
end

while true do
  local ok, err = pcall(function()
    -- hier kommt dein echter Ablauf rein:
    local data = readAll()
    drawAll(data)
  end)

  if not ok then
    showError(err)
    error(err) -- stoppt das Programm sichtbar
  end

  sleep(CFG.refresh or 0.5)
end
