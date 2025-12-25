---@diagnostic disable: undefined-global
for _, n in ipairs(peripheral.getNames()) do
  print(n, peripheral.getType(n))
end
