local Guard = require("../src/shared/MovementGuard")
local g = Guard.new(0, 0, 0)
for i = 1, 20 do assert(g:sample(i*4, 0, i*0.25, 16)) end
assert(not g:sample(180, 0, 5.1, 16))
assert(not g:sample(180, 0, 5.5, 16))
assert(g:sample(180, 0, 8.2, 16))
g:reset(0, 0, 9)
assert(not g:sample(0, 0, 9.1, 16))
assert(g:sample(0, 0, 9.6, 16))
assert(not g:sample(0/0, 0, 10, 16))
local fast = Guard.new(0, 0, 0)
local blocked = false
for i = 1, 20 do if not fast:sample(i*8, 0, i*0.25, 16) then blocked = true end end
assert(blocked)
print("PASS: movement budget, sustained speed, teleport, recovery, authorized reset, invalid coordinates")
