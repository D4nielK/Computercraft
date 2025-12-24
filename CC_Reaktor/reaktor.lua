---@diagnostic disable: undefined-global
local names = peripheral.getNames()

for _, n in ipairs(names) do
  if peripheral.getType(n) == "fissionReactorLogicAdapter" then
    local r = peripheral.wrap(n)
    print("== "..n.." ==")
    print(" status:      ", r.getStatus())
    print(" logicMode:   ", r.getLogicMode())
    print(" redstoneMode:", r.getRedstoneMode())
    print(" forceDisabled:", r.isForceDisabled())
    print("")
  end
end
