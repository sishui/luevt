
local os           = os
local assert       = assert
local type         = type
local getmetatable = getmetatable
local setmetatable = setmetatable
local coroutine    = coroutine
local ipairs       = ipairs
local table        = table
local tostring     = tostring
local error        = error
local pairs        = pairs

local E = {
	__call =  function( self, id, ...) self:dispatch(id, ...) end,
}
E.__index = E

function E.new()
	return setmetatable({ 
			listeners = {},
			index     = 0,
			locked    = false,
			disabled  = {}
			}, E)
end

E.__eq = function (e1, e2)
	if getmetatable(e1) ~= E or getmetatable(e2) ~= E then
		return false
	end

	if #e1.listeners ~= #e2.listeners then return false end

	for _,a1 in ipairs(e1.listeners) do
		local found = false
		for _,a2 in ipairs(e2.listeners) do
			if a1 == a2 then
				found = true
				break
			end
		end
		if found == false then return false end
	end

	return true
end

E.listener = {}
E.listener.__index = E.listener

local function is_listener_callable(callable)
	local _type = type(callable)
	if _type == "table" then
		if type(getmetatable(callable)["__call"]) == "function" then
			return true
		end
	elseif _type == "function" then
		return true
	elseif _type == "thread" then
		return coroutine.status(callable) ~= "dead"
	end

	return false
end

local function new_listener(property)
	return setmetatable({
		callable        = property.listener,
		id              = property.id,
		name            = tostring(property.listener),
		enabled         = true,
		dead            = false,
		priority        = property.priority or 0,
		limit           = property.limit or -1,
		index           = property.index,
		number_of_calls = 0,
		interval        = property.interval or 0,
		last_call_time  = os.time(),
	}, E.listener)
end

E.listener.__eq = function (a1, a2)
	if getmetatable(a1) ~= E.listener or getmetatable(a2) ~= E.listener then
		return false
	end

	return a1.id == a2.id
end

local function find(event, listener)
	local key

	if type(listener) == "string" then
		key = "id"
	elseif is_listener_callable(listener) then
		key = "callable"
	else
		error("Invalid listener parameter: " .. tostring(listener))
	end

	for index,value in ipairs(event.listeners) do
		if value[key] == listener and not value["dead"]  then
			return true, index
		end
	end

	return false, nil
end

local function sort_by_priority(event)
	table.sort(event.listeners,function(a1, a2)
		if a1.priority == a2.priority then
			return a1.index < a2.index
		end
		return a1.priority > a2.priority
	end)
end

local function new_index(event)
	event.index = event.index + 1
	return event.index
end

local function reset_index(event)
	event.index = 0
end

local function lock(event)
	event.locked = true
end

local function unlock(event)
	event.locked = false
end

function E:add_listener(id, listener)
	local property
	if type(id) == "table" then
		property       = id
		property.index = new_index(self)
	else
		property = {
			id       = id,
			listener = listener,
			index    = new_index(self)
		}
	end
	assert(property.id, "id is nil")
	assert(is_listener_callable(property.listener), "listener not function or not coroutine")
	local new = new_listener(property)
	self.listeners[#self.listeners+1] = new
	return listener, new.id, new.name
end

function E:remove_listener(listener)
	while true do
		local exists,index = find(self, listener)
		if exists then
			if self.locked then
				self.listeners[index]["dead"]   = true
				self.disabled[#self.disabled+1] = listener
				--break
			else
				table.remove(self.listeners, index)
			end
		else
			break
		end
	end
end

function E:remove_listeners()
	self.listeners = {}
	reset_index(self)
end

function E:__len()
	return #self.listeners
end

function E:exists(listener)
	local found = find(self, listener)
	return found
end

local function invoke(listener, ...)
	if not listener.enabled then
		return true
	end

	if type(listener.callable) == "thread" then
		coroutine.resume(listener.callable, ...)
		if coroutine.status(listener.callable) == "dead" then
			return false
		end
	else
		listener.callable(...)
	end

	listener.number_of_calls = listener.number_of_calls + 1

	if listener.limit >= 0
	and listener.number_of_calls >= listener.limit then
		listener.enabled = false
	end

	return true
end

local function call(self, listener, ...)
	local keep = invoke(listener, ...)
	if keep == false then
		self:remove_listener(listener.id)
	end
end

function E:dispatch(id, ...)
	assert(id, "event id is nil")
	sort_by_priority(self)
	lock(self)
	for _,listener in ipairs(self.listeners) do
		if listener.id == id and not listener.dead then
			if listener.interval > 0 then
				if os.difftime(os.time(), listener.last_call_time) >= listener.interval then
						call(self, listener, ...)
						listener.last_call_time = os.time()
				end
			else
				-- call(listener, listener.id, ...)
				call(self, listener, ...)
			end
		end
	end
	unlock(self)
	local disabled
	disabled, self.disabled = self.disabled,{}
	for _,v in pairs(disabled or {}) do
		self:remove_listener(v)
	end
end

local function setter(property, value_type, default)
	return function (event, listener, new_value)
		local property_value = new_value or default
		local property_type = type(property_value)
		local exists,index = find(event, listener)
		assert(exists)
		assert(property_type == value_type)

		if property_type == "number" then
			assert(property_value >= 0)
		end

		event.listeners[index][property] = property_value
	end
end

local function getter(property)
	return function (event, listener)
		local exists,index = find(event, listener)
		assert(exists)
		assert(event.listeners[index][property])
		return event.listeners[index][property]
	end
end

E.set_interval    = setter("interval", "number")
E.get_interval    = getter("interval")
E.remove_interval = setter("interval", "number", 0)
E.set_priority    = setter("priority", "number")
E.get_priority    = getter("priority")
E.remove_priority = setter("priority", "number", 0)
E.enable          = setter("enabled", "boolean", true)
E.disable         = setter("enabled", "boolean", false)
-- E.dead = setter("dead", "boolean", false)


function E:enabled(listener)
	local exists,index = find(self, listener)
	assert(exists)
	return self.listeners[index].enabled
end

function E:set_dispatch_limit(listener, limit)
	local exists,index = find(self, listener)
	assert(exists)
	assert(type(limit) == "number" and limit >= 0)
	self.listeners[index].limit = limit
	self.listeners[index].number_of_calls = 0

	if limit == 0 then
		self.listeners[index].enabled = false
	end
end

function E:get_dispatch_limit(listener)
	local exists,index = find(self, listener)
	assert(exists)
	assert(self.listeners[index].limit)
	return self.listeners[index].limit
end

function E:remove_dispatch_limit(listener)
	local exists,index = find(self, listener)
	assert(exists)
	self.listeners[index].limit           = -1
	self.listeners[index].number_of_calls = 0
	self.listeners[index].enabled         = true
end

function E:all_listeners()
	local index = 0
	return function ()
		index          = index + 1
		local listener = self.listeners[index]
		if listener then return listener.id end
	end
end

function E:foreach_listener(f)
	local _type = type(f)
	for listener in self:all_listeners() do
		if "function" == _type then
			f(self, listener)
		end
	end
end

return E

