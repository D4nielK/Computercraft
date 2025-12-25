---@diagnostic disable: undefined-global
local name = "<HIER_DEN_PERIPHERAL_NAME>"
local m = peripheral.getMethods(name)
table.sort(m)
for _,v in ipairs(m) do print(v) end
