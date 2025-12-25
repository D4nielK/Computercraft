---@diagnostic disable: undefined-global
local name = "<PERIPHERAL_NAME>"

local methods = peripheral.getMethods(name)
if not methods then
  print("KEIN CC-PERIPHERAL:", name)
  return
end

table.sort(methods)
for _, m in ipairs(methods) do
  print(m)
end
