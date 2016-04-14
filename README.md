# luevt

modify form [Luvent]( https://github.com/ejmr/Luvent.git)

**Example:**

```lua
local E = require "luevt"
local dispatcher1 = E.new()
dispatcher1:add_listener("TEST_DISPATCH_FUNC", function(args)
	print("listener is fucntion, args =", args)
end)

dispatcher1:add_listener("TEST_DISPATH_CO", coroutine.create(function(args)
	while true do
		print("listener is coroutine, args =", args)
		coroutine.yield()
	end
end))

dispatcher1:add_listener({
	id = "TEST_DISPATH_TABLE",
	listener = function (args)
		print("listener is table, args =", args)
	end,
	priority = 10,
	limit    = 2,
	interval = 0
})

dispatcher1:dispatch("TEST_DISPATCH_FUNC", "dispatcher1")
for i=1, 3 do
	dispatcher1:dispatch("TEST_DISPATH_CO", "dispatcher1")
end

for i=1, 3 do
	dispatcher1:dispatch("TEST_DISPATH_TABLE", "dispatcher1")
end

print("--------------------------------")

print("TEST_DISPATCH_FUNC, exists:", dispatcher1:exists("TEST_DISPATCH_FUNC"))
print("TEST_DISPATCH_FUNC, exists:", dispatcher1:exists("TEST_DISPATH_CO"))
print("--------------------------------")

local listeners = dispatcher1:all_listeners()
for i=1, #dispatcher1 do
	print(listeners())
end
print("--------------------------------")

local dispatcher2 = E.new()

local priority_default = function()
	print("listener is priority_default")
end


local priority_1 = function()
	print("listener is priority_1")
end

local priority_10 = function()
	print("listener is priority_10")
end

dispatcher2:add_listener("TEST_DISPATCH_PRIORITY", priority_default)
dispatcher2:add_listener("TEST_DISPATCH_PRIORITY", priority_10)
dispatcher2:add_listener("TEST_DISPATCH_PRIORITY", priority_1)
dispatcher2:dispatch("TEST_DISPATCH_PRIORITY")
print("--------------------------------")

dispatcher2:set_priority(priority_1, 1)
dispatcher2:set_priority(priority_10, 10)
dispatcher2:dispatch("TEST_DISPATCH_PRIORITY")
print("--------------------------------")

local dispatcher3 = E.new()

local limit_default = function(times)
	print("listener is limit_default, times =", times)
end

local limit_2 = function(times)
	print("listener is limit_2, times =", times)
end
dispatcher3:add_listener("TEST_DISPATCH_LIMIT", limit_default)
dispatcher3:add_listener("TEST_DISPATCH_LIMIT", limit_2)
dispatcher3:set_dispatch_limit(limit_2, 2)
for i=1, 5 do
	dispatcher3:dispatch("TEST_DISPATCH_LIMIT", i)
end

print("--------------------------------")
print("dispatcher1 listener count =", #dispatcher1, "\ndispatcher2 listener count =", #dispatcher2, "\ndispatcher3 listener count =", #dispatcher3)
print("--------------------------------")
dispatcher1:remove_listener("TEST_DISPATH_CO")
dispatcher2:remove_listeners()
dispatcher3:remove_listener(limit_default)
print("dispatcher1 listener count =", #dispatcher1, "\ndispatcher2 listener count =", #dispatcher2, "\ndispatcher3 listener count =", #dispatcher3)
print("--------------------------------")

local dispatcher4 = E.new()
local listener3
local function listener1(...)
	print("dispatcher4 listener1: no remove",...)
end

local function listener2(...)
	local exists = dispatcher4:exists(listener1)
	print("dispatcher4 exist: listener1", exists)
	if exists then
		print("dispatcher4 listener2, remove listener1:", ...)
		dispatcher4:remove_listener(listener1)
	end
end

listener3 = function(...)
	print("dispatcher4 listener3, remove listener3:", ...)
	dispatcher4:remove_listener(listener3)
end

local listener4 =coroutine.create(function(...)
	while true do
		print("dispatcher4 listener4, no remove:", ...)
		coroutine.yield()
	end
end)

dispatcher4:add_listener( "TEST_REMOVE_IN_DISPATCH", listener1 )
dispatcher4:add_listener( "TEST_REMOVE_IN_DISPATCH", listener2 )
dispatcher4:add_listener( "TEST_REMOVE_IN_DISPATCH", listener3 )
dispatcher4:add_listener( "TEST_REMOVE_IN_DISPATCH", listener4 )

dispatcher4:dispatch( "TEST_REMOVE_IN_DISPATCH")
print("--------------------------------")
dispatcher4:remove_dispatch_limit(listener2)
dispatcher4:dispatch( "TEST_REMOVE_IN_DISPATCH")
print("---------------test end-----------------")
```