---@diagnostic disable: undefined-global
local names = peripheral.getNames()
table.sort(names)

for _, name in ipairs(names) do
  local t = peripheral.getType(name)
  local m = peripheral.getMethods(name)
  print(name, t, m and #m or 0)
end
