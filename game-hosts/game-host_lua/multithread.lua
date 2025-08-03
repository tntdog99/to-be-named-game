local llthreads = require("llthreads2")

local code = [[
	print("Child thread started with:", ...)
	return ...
]]

local thread = llthreads.new(code, "Hello from main thread!", 42)
assert(thread:start())
local result = { thread:join() }
print("Main thread received:", unpack(result))
