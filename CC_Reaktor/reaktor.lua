---@diagnostic disable: undefined-global

local TURB = "turbineValve_0" -- <- falls bei dir anders, hier ändern

local m = peripheral.getMethods(TURB)
if not m then
  print("Kein Methods-API für:", TURB)
  return
end

table.sort(m)
print("Methods for", TURB, "(count="..#m..")")
for _, name in ipairs(m) do
  print(" - "..name)
end
