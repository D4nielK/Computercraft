local r = peripheral.find("fissionReactorLogicAdapter")
if not r then error("Kein fissionReactorLogicAdapter gefunden") end

local name = peripheral.getName(r)
print("Peripheral name: "..name)
local methods = peripheral.getMethods(name)
table.sort(methods)
for _,m in ipairs(methods) do print(m) end
