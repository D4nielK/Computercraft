local function showError(err)
  mon.setTextScale(CFG.monitorScale)
  mon.clear()
  mon.setCursorPos(1,1)
  mon.write("SCRIPT ERROR:")
  mon.setCursorPos(1,2)
  mon.write(tostring(err))
end

while true do
  local ok, err = pcall(function()
    local data = readAll()
    drawAll(data)
  end)

  if not ok then
    showError(err)
    error(err) -- damit du es auch im Terminal siehst
  end

  sleep(CFG.refresh)
end
