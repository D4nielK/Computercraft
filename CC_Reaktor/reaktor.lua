local mon = peripheral.find("monitor")
mon.setTextScale(0.5)  -- das ist bei dir aktuell
local w,h = mon.getSize()
print("Monitor chars:", w, h)
